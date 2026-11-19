import Foundation

/// Used for Xfinity gateways and any unknown router. These expose no documented
/// local API for per-device blocking, so the adapter is transparent about it:
/// discovery and tracking still work everywhere, access management does not.
struct UnsupportedRouterAdapter: RouterAdapter {
    let kind: RouterKind

    init(kind: RouterKind) { self.kind = kind }

    func connect(config: RouterConfig, password: String) async throws {
        // Nothing to authenticate against; connection is a no-op "ok".
    }

    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported(reason)
    }

    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported(reason)
    }

    private var reason: String {
        switch kind {
        case .xfinity:
            return "Xfinity gateways are cloud-managed and expose no local API for blocking devices. Use the Xfinity app (Devices → Pause). JetWIFI still discovers and tracks everything on your network."
        default:
            return "No access-management integration exists for this router. JetWIFI can discover and track devices, but can't change their access. You can still block devices from your router's own admin page."
        }
    }
}
