import Foundation

/// Simple, robust JSON persistence in Application Support. No external deps, and it
/// keeps JetWIFI compatible with iOS 16 (no SwiftData requirement) for SideStore.
final class Store {
    static let shared = Store()

    private let dir: URL
    private let devicesURL: URL
    private let historyURL: URL
    private let configURL: URL

    private init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("JetWIFI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        devicesURL = dir.appendingPathComponent("devices.json")
        historyURL = dir.appendingPathComponent("history.json")
        configURL = dir.appendingPathComponent("router.json")
    }

    // MARK: - Devices
    func loadDevices() -> [Device] { load([Device].self, from: devicesURL) ?? [] }
    func saveDevices(_ devices: [Device]) { save(devices, to: devicesURL) }

    // MARK: - History
    func loadHistory() -> [HistoryEvent] { load([HistoryEvent].self, from: historyURL) ?? [] }
    func saveHistory(_ events: [HistoryEvent]) { save(events, to: historyURL) }

    // MARK: - Router config (non-secret; password is in Keychain)
    func loadConfig() -> RouterConfig { load(RouterConfig.self, from: configURL) ?? RouterConfig() }
    func saveConfig(_ config: RouterConfig) { save(config, to: configURL) }

    // MARK: - Codable helpers
    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
