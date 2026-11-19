import Foundation

/// A device discovered on the local network.
struct Device: Identifiable, Codable, Equatable, Hashable {
    enum AccessStatus: String, Codable {
        case allowed
        case restricted
        case unknown
    }

    /// Stable identity. We key on MAC when we have it (survives IP changes),
    /// otherwise on IP.
    var id: String { mac ?? ip }

    var ip: String
    var mac: String?
    /// Reverse-DNS or Bonjour hostname, if resolvable.
    var hostname: String?
    /// Friendly name the user assigned, overrides hostname for display.
    var customName: String?
    /// Vendor resolved from the MAC OUI prefix.
    var vendor: String?
    /// Bonjour service types seen advertised (hints at device kind).
    var services: [String] = []

    var isOnline: Bool = true
    var firstSeen: Date = Date()
    var lastSeen: Date = Date()
    var accessStatus: AccessStatus = .unknown

    /// True for the iPhone running the app (never offer to restrict yourself).
    var isThisDevice: Bool = false
    /// True for the gateway/router.
    var isGateway: Bool = false

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        if let hostname, !hostname.isEmpty { return hostname }
        if let vendor, !vendor.isEmpty { return vendor }
        return "Unknown device"
    }

    /// A rough category used only to pick an SF Symbol.
    var iconName: String {
        if isGateway { return "wifi.router" }
        if isThisDevice { return "iphone" }
        let haystack = ((vendor ?? "") + " " + (hostname ?? "") + " " + services.joined()).lowercased()
        if haystack.contains("apple") || haystack.contains("iphone") { return "iphone" }
        if haystack.contains("ipad") { return "ipad" }
        if haystack.contains("mac") { return "laptopcomputer" }
        if haystack.contains("airplay") || haystack.contains("raop") || haystack.contains("tv") || haystack.contains("roku") || haystack.contains("googlecast") { return "appletv" }
        if haystack.contains("printer") || haystack.contains("ipp") { return "printer" }
        if haystack.contains("cam") || haystack.contains("ring") || haystack.contains("nest") { return "web.camera" }
        if haystack.contains("echo") || haystack.contains("sonos") || haystack.contains("speaker") { return "hifispeaker" }
        if haystack.contains("playstation") || haystack.contains("xbox") || haystack.contains("nintendo") { return "gamecontroller" }
        return "desktopcomputer"
    }
}
