import Foundation

/// What every router integration must provide. Adapters are deliberately small and
/// honest: if a model can't do something, they throw `.unsupported`, never fake it.
protocol RouterAdapter {
    var kind: RouterKind { get }

    /// Verify we can reach and authenticate to the router. Throws on failure.
    func connect(config: RouterConfig, password: String) async throws

    /// Block a device's internet/network access by MAC. Returns only on confirmation.
    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult

    /// Restore a previously blocked device.
    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult

    /// Optional: list MACs the router currently reports as blocked, so we can reconcile.
    func listRestricted(config: RouterConfig, password: String) async throws -> [String]
}

extension RouterAdapter {
    func listRestricted(config: RouterConfig, password: String) async throws -> [String] { [] }

    /// Helper: build a URLSession that tolerates the self-signed certs home routers use.
    func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg, delegate: InsecureTLSDelegate(), delegateQueue: nil)
    }

    func baseURL(_ config: RouterConfig) -> URL? {
        let scheme = config.useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(config.host)")
    }
}

/// Accepts the self-signed / IP-only TLS certificates typical of local router admin pages.
/// Scope is limited to the user's own gateway on the LAN.
final class InsecureTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
