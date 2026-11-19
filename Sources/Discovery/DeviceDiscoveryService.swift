import Foundation

/// Orchestrates a full discovery pass:
///   1. Find our IP + subnet.
///   2. Touch every host to populate the ARP cache.
///   3. Read the ARP cache (IP → MAC).
///   4. Browse Bonjour for names / service hints.
///   5. Reverse-DNS the rest and resolve vendors.
///
/// Emits incremental progress so the UI can animate, and returns the merged set.
actor DeviceDiscoveryService {

    struct Progress {
        var phase: String
        var fraction: Double
    }

    private let toucher = HostToucher()
    private let bonjour = BonjourBrowser()

    /// Runs one scan. `onProgress` is called on an arbitrary task; marshal to main in the VM.
    func scan(onProgress: @Sendable @escaping (Progress) -> Void) async -> [Device] {
        guard let net = NetworkInterface.current() else {
            onProgress(Progress(phase: "No Wi-Fi connection", fraction: 1))
            return []
        }

        onProgress(Progress(phase: "Probing \(net.hostAddresses.count) addresses…", fraction: 0.1))
        await toucher.touchAll(net.hostAddresses)

        onProgress(Progress(phase: "Reading ARP table…", fraction: 0.5))
        let arp = ARPTable.read()

        onProgress(Progress(phase: "Browsing Bonjour services…", fraction: 0.65))
        let bonjourFound = await bonjour.browse(duration: 4.0)

        onProgress(Progress(phase: "Resolving names…", fraction: 0.85))

        // Build devices keyed by IP from the ARP cache.
        var byIP: [String: Device] = [:]
        for entry in arp {
            var d = Device(ip: entry.ip, mac: entry.mac)
            d.vendor = OUILookup.vendor(for: entry.mac)
            d.isGateway = (entry.ip == net.gatewayGuess)
            byIP[entry.ip] = d
        }

        // Make sure the gateway shows even if the cache missed it.
        if byIP[net.gatewayGuess] == nil {
            var gw = Device(ip: net.gatewayGuess)
            gw.isGateway = true
            byIP[net.gatewayGuess] = gw
        }

        // Add ourselves explicitly.
        var me = Device(ip: net.localIP)
        me.isThisDevice = true
        me.customName = "This iPhone"
        byIP[net.localIP] = me

        // Fold in Bonjour names / services.
        for found in bonjourFound {
            guard let ip = found.ipv4 else { continue }
            if var d = byIP[ip] {
                if d.hostname == nil { d.hostname = cleanName(found.name) }
                if !d.services.contains(found.serviceType) { d.services.append(found.serviceType) }
                byIP[ip] = d
            } else {
                var d = Device(ip: ip)
                d.hostname = cleanName(found.name)
                d.services = [found.serviceType]
                byIP[ip] = d
            }
        }

        // Reverse DNS for anything still unnamed (bounded concurrency).
        await withTaskGroup(of: (String, String?).self) { group in
            for (ip, d) in byIP where d.hostname == nil && !d.isThisDevice {
                group.addTask { (ip, ReverseDNS.hostname(for: ip)) }
            }
            for await (ip, name) in group {
                if let name, var d = byIP[ip] { d.hostname = name; byIP[ip] = d }
            }
        }

        onProgress(Progress(phase: "Done", fraction: 1))
        return byIP.values.sorted { lhs, rhs in
            let l = NetworkInterface.ipv4ToUInt32(lhs.ip) ?? 0
            let r = NetworkInterface.ipv4ToUInt32(rhs.ip) ?? 0
            return l < r
        }
    }

    private func cleanName(_ raw: String) -> String {
        // Bonjour names arrive percent-escaped and often with a trailing suffix.
        raw.removingPercentEncoding ?? raw
    }
}
