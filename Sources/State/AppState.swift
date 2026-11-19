import Foundation
import SwiftUI

/// The single source of truth the whole UI observes. Owns the device list, history,
/// router config, and drives scans + access actions.
@MainActor
final class AppState: ObservableObject {
    @Published var devices: [Device] = []
    @Published var history: [HistoryEvent] = []
    @Published var config: RouterConfig = RouterConfig()

    @Published var isScanning = false
    @Published var scanPhase: String = ""
    @Published var scanProgress: Double = 0
    @Published var lastScan: Date?

    /// Transient banner shown after an action (success or honest failure).
    @Published var banner: Banner?

    struct Banner: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var isError: Bool
    }

    private let discovery = DeviceDiscoveryService()

    // MARK: - Lifecycle
    func bootstrap() {
        devices = Store.shared.loadDevices()
        history = Store.shared.loadHistory()
        config = Store.shared.loadConfig()
    }

    // MARK: - Derived
    var restrictedDevices: [Device] { devices.filter { $0.accessStatus == .restricted } }
    var onlineCount: Int { devices.filter { $0.isOnline }.count }
    var gateway: Device? { devices.first { $0.isGateway } }

    // MARK: - Scanning
    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanPhase = "Starting…"

        let previous = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })

        let found = await discovery.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanPhase = progress.phase
                self?.scanProgress = progress.fraction
            }
        }

        merge(found: found, previous: previous)
        lastScan = Date()
        isScanning = false
        persist()
    }

    private func merge(found: [Device], previous: [String: Device]) {
        var merged: [Device] = []
        let foundIDs = Set(found.map { $0.id })

        for var d in found {
            if let old = previous[d.id] {
                d.firstSeen = old.firstSeen
                d.customName = d.customName ?? old.customName
                d.accessStatus = old.accessStatus
                if d.hostname == nil { d.hostname = old.hostname }
                if d.vendor == nil { d.vendor = old.vendor }
                if !old.isOnline {
                    log(.deviceJoined, "\(d.displayName) joined the network", deviceID: d.id)
                }
            } else {
                d.accessStatus = (config.isConfigured && d.mac != nil) ? .allowed : .unknown
                log(.deviceDiscovered, "New device: \(d.displayName)", detail: d.ip, deviceID: d.id)
            }
            d.isOnline = true
            d.lastSeen = Date()
            merged.append(d)
        }

        // Keep known-but-absent devices, marked offline.
        for (id, var old) in previous where !foundIDs.contains(id) {
            if old.isOnline { log(.deviceLeft, "\(old.displayName) left the network", deviceID: id) }
            old.isOnline = false
            merged.append(old)
        }

        devices = merged.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline { return lhs.isOnline && !rhs.isOnline }
            let l = NetworkInterface.ipv4ToUInt32(lhs.ip) ?? 0
            let r = NetworkInterface.ipv4ToUInt32(rhs.ip) ?? 0
            return l < r
        }
    }

    // MARK: - Access management
    func setRestricted(_ device: Device, restricted: Bool) async {
        guard config.isConfigured else {
            showBanner("Add your router in Settings first.", isError: true)
            return
        }
        guard let password = KeychainService.loadPassword() ?? (config.kind.canAttemptRestrictions ? nil : "") else {
            showBanner("No router password saved. Re-add your router in Settings.", isError: true)
            return
        }

        do {
            let result: RouterActionResult
            if restricted {
                result = try await RouterManager.restrict(device, config: config, password: password)
            } else {
                result = try await RouterManager.restore(device, config: config, password: password)
            }
            // Only reflect the change after the router confirmed it.
            updateDevice(device.id) { $0.accessStatus = restricted ? .restricted : .allowed }
            log(restricted ? .restrictApplied : .restrictRemoved, result.message, deviceID: device.id)
            showBanner(result.message, isError: false)
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            log(.restrictFailed, "Couldn't change access for \(device.displayName)", detail: msg, deviceID: device.id)
            showBanner(msg, isError: true)
        }
        persist()
    }

    // MARK: - Router config
    func saveRouter(_ newConfig: RouterConfig, password: String) async -> Bool {
        var cfg = newConfig
        do {
            if cfg.kind.canAttemptRestrictions {
                try await RouterManager.connect(config: cfg, password: password)
            }
            if !password.isEmpty { KeychainService.savePassword(password) }
            cfg.isConfigured = true
            config = cfg
            Store.shared.saveConfig(cfg)
            log(.routerConnected, "Connected to \(cfg.kind.displayName) router", detail: cfg.host)
            showBanner("Router saved.", isError: false)
            return true
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            log(.routerError, "Router setup problem", detail: msg)
            showBanner(msg, isError: true)
            // Still persist non-secret config so the user doesn't retype everything.
            config = cfg
            Store.shared.saveConfig(cfg)
            return false
        }
    }

    func renameDevice(_ id: String, to name: String) {
        updateDevice(id) { $0.customName = name.isEmpty ? nil : name }
        persist()
    }

    func clearHistory() {
        history = []
        persist()
    }

    // MARK: - Helpers
    private func updateDevice(_ id: String, _ mutate: (inout Device) -> Void) {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        mutate(&devices[idx])
    }

    private func log(_ kind: HistoryEvent.Kind, _ title: String, detail: String? = nil, deviceID: String? = nil) {
        history.insert(HistoryEvent(kind: kind, title: title, detail: detail, deviceID: deviceID), at: 0)
        if history.count > 500 { history = Array(history.prefix(500)) }
    }

    func showBanner(_ text: String, isError: Bool) {
        banner = Banner(text: text, isError: isError)
    }

    private func persist() {
        Store.shared.saveDevices(devices)
        Store.shared.saveHistory(history)
    }
}
