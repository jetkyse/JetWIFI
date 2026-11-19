import Foundation

/// Supported router brands. Each maps to a concrete adapter.
enum RouterKind: String, Codable, CaseIterable, Identifiable {
    case asus
    case netgear
    case tplink
    case eero
    case xfinity
    case generic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asus: return "ASUS"
        case .netgear: return "NETGEAR"
        case .tplink: return "TP-Link"
        case .eero: return "Eero"
        case .xfinity: return "Xfinity"
        case .generic: return "Other / Unsupported"
        }
    }

    /// Honest, user-facing summary of what this integration can actually do.
    var supportSummary: String {
        switch self {
        case .asus:
            return "Local admin API. Device blocking via the router's parental-controls / access-control list is supported on most AsusWRT firmware."
        case .netgear:
            return "Local SOAP API (DeviceConfig). Block / allow a device by MAC is supported on routers exposing the AllowBlockDevice action."
        case .tplink:
            return "Local admin login varies widely by model and firmware. Access control is attempted but may not be available on cloud-managed (Tether-only) models."
        case .eero:
            return "Cloud-only (no local admin). Blocking requires signing in to your eero account; there is no documented local API. Support is limited and best-effort."
        case .xfinity:
            return "Cloud-managed gateways expose no documented local API. Device blocking is not available from an on-device app; use the Xfinity app."
        case .generic:
            return "No integration. JetWIFI can still discover and track devices, but cannot change access on this router."
        }
    }

    /// Whether the adapter can attempt access changes at all.
    var canAttemptRestrictions: Bool {
        switch self {
        case .asus, .netgear, .tplink, .eero: return true
        case .xfinity, .generic: return false
        }
    }
}

/// Non-secret router connection settings. The password lives in the Keychain, not here.
struct RouterConfig: Codable, Equatable {
    var kind: RouterKind = .generic
    /// Router admin host, usually the gateway IP (e.g. 192.168.1.1).
    var host: String = ""
    var username: String = "admin"
    var useHTTPS: Bool = false
    /// For cloud adapters (eero), the account email.
    var accountEmail: String = ""
    var isConfigured: Bool = false
}

/// Result of an access-management attempt. We only report success on confirmation.
struct RouterActionResult {
    var success: Bool
    var message: String
}

/// Errors an adapter can surface. `.unsupported` is first-class, not a failure to hide.
enum RouterError: LocalizedError {
    case unsupported(String)
    case notConfigured
    case authFailed
    case unreachable
    case deviceHasNoMAC
    case api(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let why): return why
        case .notConfigured: return "No router is configured. Add your router in Settings first."
        case .authFailed: return "The router rejected the credentials. Check the admin username and password."
        case .unreachable: return "Could not reach the router. Make sure you're on the same Wi-Fi network."
        case .deviceHasNoMAC: return "This device has no known MAC address, which is required to manage its access."
        case .api(let msg): return msg
        }
    }
}
