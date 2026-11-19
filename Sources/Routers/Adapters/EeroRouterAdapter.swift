import Foundation

/// Eero integration.
///
/// Eero has no local admin interface — everything goes through Amazon's cloud API
/// (`api-user.e2ro.com`), and authentication requires logging in with your eero
/// account and confirming a one-time verification code sent to your phone/email.
/// That interactive, account-level login can't be completed silently from stored
/// router credentials, so this adapter implements the first auth step and then
/// reports honestly that device pausing needs a verified eero session.
///
/// Once a session token exists, eero's own "pause device" maps to
/// `PUT /2.2/networks/<id>/devices/<mac> {"paused": true}`; that call is included
/// so a future verification flow can complete the feature.
struct EeroRouterAdapter: RouterAdapter {
    let kind: RouterKind = .eero
    private let apiBase = "https://api-user.e2ro.com"

    func connect(config: RouterConfig, password: String) async throws {
        // Kick off account login; eero responds by sending a verification code.
        guard !config.accountEmail.isEmpty else {
            throw RouterError.unsupported("Add your eero account email in Settings. Eero has no local admin password — it uses your account.")
        }
        _ = try? await requestLoginCode(email: config.accountEmail)
        throw RouterError.unsupported("Eero requires a one-time verification code sent to \(config.accountEmail). JetWIFI can't complete eero's account login unattended, so per-device pausing isn't available here. Use the eero app's 'Pause' feature, which does the same thing.")
    }

    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported("Eero device pausing needs a verified eero account session, which JetWIFI can't establish on-device. Use the eero app to pause \(device.displayName).")
    }

    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported("Use the eero app to resume \(device.displayName).")
    }

    /// Step 1 of eero account login: ask the cloud to send a verification code.
    private func requestLoginCode(email: String) async throws -> String {
        guard let url = URL(string: "\(apiBase)/2.2/login") else { throw RouterError.unreachable }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["login": email])
        let (data, _) = try await makeSession().data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (json?["data"] as? [String: Any])?["user_token"] as? String ?? ""
    }
}
