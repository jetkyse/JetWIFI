import Foundation

/// A log entry for anything the user or the app did that is worth remembering.
struct HistoryEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case deviceDiscovered
        case deviceJoined
        case deviceLeft
        case restrictApplied
        case restrictRemoved
        case restrictFailed
        case routerConnected
        case routerError
    }

    var id: UUID = UUID()
    var date: Date = Date()
    var kind: Kind
    var title: String
    var detail: String?
    /// Device id this event refers to, when applicable.
    var deviceID: String?

    var iconName: String {
        switch kind {
        case .deviceDiscovered: return "sparkle.magnifyingglass"
        case .deviceJoined: return "arrow.right.circle"
        case .deviceLeft: return "arrow.left.circle"
        case .restrictApplied: return "hand.raised.fill"
        case .restrictRemoved: return "checkmark.shield.fill"
        case .restrictFailed: return "exclamationmark.triangle.fill"
        case .routerConnected: return "wifi.router.fill"
        case .routerError: return "xmark.octagon.fill"
        }
    }
}
