import Foundation
import Network

/// "Touches" each host in the subnet so the OS resolves it at the link layer and
/// populates the ARP cache. We fire a tiny UDP datagram and a short TCP connect;
/// we don't care whether either succeeds — the point is to force neighbour
/// resolution, which is all a sandboxed app can do without raw sockets.
actor HostToucher {

    /// Ports worth a quick TCP probe (common on home devices).
    private let tcpProbePorts: [UInt16] = [80, 443, 22, 139, 445, 62078]

    func touchAll(_ hosts: [String], perHostTimeout: TimeInterval = 0.6) async {
        await withTaskGroup(of: Void.self) { group in
            // Bound concurrency so we don't exhaust descriptors on large subnets.
            let maxConcurrent = 40
            var index = 0
            var active = 0

            func launch(_ host: String) {
                group.addTask { await self.touch(host, timeout: perHostTimeout) }
            }

            while index < hosts.count {
                while active < maxConcurrent && index < hosts.count {
                    launch(hosts[index])
                    index += 1
                    active += 1
                }
                await group.next()
                active -= 1
            }
            await group.waitForAll()
        }
    }

    private func touch(_ host: String, timeout: TimeInterval) async {
        // UDP poke — cheapest way to trigger ARP for silent hosts.
        await udpPoke(host)
        // TCP connect to the first responsive-ish port; also triggers ARP.
        await tcpPoke(host, timeout: timeout)
    }

    private func udpPoke(_ host: String) async {
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: 9) // discard port
        let conn = NWConnection(to: endpoint, using: .udp)
        conn.start(queue: .global(qos: .utility))
        conn.send(content: Data([0]), completion: .contentProcessed { _ in })
        try? await Task.sleep(nanoseconds: 120_000_000)
        conn.cancel()
    }

    private func tcpPoke(_ host: String, timeout: TimeInterval) async {
        for port in tcpProbePorts {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let conn = NWConnection(host: .init(host), port: nwPort, using: .tcp)
            let done = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                var resumed = false
                func finish(_ reachable: Bool) {
                    guard !resumed else { return }
                    resumed = true
                    conn.cancel()
                    cont.resume(returning: reachable)
                }
                conn.stateUpdateHandler = { state in
                    switch state {
                    case .ready: finish(true)
                    case .failed, .cancelled: finish(false)
                    default: break
                    }
                }
                conn.start(queue: .global(qos: .utility))
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
            }
            // A single successful connect is enough to know the host is alive & resolved.
            if done { return }
        }
    }
}
