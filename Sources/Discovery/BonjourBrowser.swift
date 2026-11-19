import Foundation
import Network

/// Browses common Bonjour/mDNS service types and resolves them to IP + name.
/// This fills in friendly hostnames and service hints the ARP scan can't provide.
final class BonjourBrowser {

    struct Found {
        let name: String
        let serviceType: String
        var ipv4: String?
    }

    private let serviceTypes = [
        "_http._tcp", "_https._tcp", "_airplay._tcp", "_raop._tcp",
        "_companion-link._tcp", "_googlecast._tcp", "_ipp._tcp",
        "_ipps._tcp", "_ssh._tcp", "_smb._tcp", "_afpovertcp._tcp",
        "_homekit._tcp", "_spotify-connect._tcp"
    ]

    /// Runs browsers for `duration` seconds, then returns everything resolved.
    func browse(duration: TimeInterval = 4.0) async -> [Found] {
        await withTaskGroup(of: [Found].self) { group in
            for type in serviceTypes {
                group.addTask { await self.browseOne(type: type, duration: duration) }
            }
            var all: [Found] = []
            for await chunk in group { all.append(contentsOf: chunk) }
            return all
        }
    }

    private func browseOne(type: String, duration: TimeInterval) async -> [Found] {
        await withCheckedContinuation { continuation in
            var results: [Found] = []
            let lock = NSLock()
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: params)

            browser.browseResultsChangedHandler = { resultSet, _ in
                for result in resultSet {
                    if case let .service(name, _, _, _) = result.endpoint {
                        self.resolve(name: name, type: type) { found in
                            lock.lock(); results.append(found); lock.unlock()
                        }
                    }
                }
            }
            browser.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + duration) {
                browser.cancel()
                lock.lock(); let snapshot = results; lock.unlock()
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func resolve(name: String, type: String, completion: @escaping (Found) -> Void) {
        let conn = NWConnection(to: .service(name: name, type: type, domain: "local.", interface: nil), using: .tcp)
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                var ipv4: String?
                if let path = conn.currentPath, let remote = path.remoteEndpoint,
                   case let .hostPort(host, _) = remote {
                    if case let .ipv4(addr) = host {
                        ipv4 = "\(addr)".components(separatedBy: "%").first
                    }
                }
                completion(Found(name: name, serviceType: type, ipv4: ipv4))
                conn.cancel()
            } else if case .failed = state {
                completion(Found(name: name, serviceType: type, ipv4: nil))
                conn.cancel()
            }
        }
        conn.start(queue: .global(qos: .utility))
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { conn.cancel() }
    }
}
