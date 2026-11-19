import Foundation

/// Picks the right adapter for a configured router and runs access actions through it.
struct RouterManager {

    static func adapter(for kind: RouterKind) -> RouterAdapter {
        switch kind {
        case .asus: return ASUSRouterAdapter()
        case .netgear: return NetgearRouterAdapter()
        case .tplink: return TPLinkRouterAdapter()
        case .eero: return EeroRouterAdapter()
        case .xfinity: return UnsupportedRouterAdapter(kind: .xfinity)
        case .generic: return UnsupportedRouterAdapter(kind: .generic)
        }
    }

    static func connect(config: RouterConfig, password: String) async throws {
        try await adapter(for: config.kind).connect(config: config, password: password)
    }

    static func restrict(_ device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await adapter(for: config.kind).restrict(device: device, config: config, password: password)
    }

    static func restore(_ device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await adapter(for: config.kind).restore(device: device, config: config, password: password)
    }

    static func listRestricted(config: RouterConfig, password: String) async throws -> [String] {
        try await adapter(for: config.kind).listRestricted(config: config, password: password)
    }
}
