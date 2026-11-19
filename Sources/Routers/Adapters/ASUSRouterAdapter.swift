import Foundation

/// ASUS (AsusWRT) integration. Authenticates with the standard `login.cgi`
/// (base64 `user:pass`) to obtain an `asus_token`, then manages the Parental
/// Controls block list (the `MULTIFILTER_*` nvram variables) via `applyapp.cgi`.
///
/// This mirrors how AsusWRT's own "Block Internet Access" toggle works under the
/// hood. nvram variable names vary across firmware generations, so a write that
/// the firmware ignores is reported as `.unsupported`, not as success.
struct ASUSRouterAdapter: RouterAdapter {
    let kind: RouterKind = .asus

    func connect(config: RouterConfig, password: String) async throws {
        _ = try await login(config: config, password: password)
    }

    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await update(device: device, config: config, password: password, block: true)
    }

    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await update(device: device, config: config, password: password, block: false)
    }

    func listRestricted(config: RouterConfig, password: String) async throws -> [String] {
        let token = try await login(config: config, password: password)
        let state = try await readFilterState(config: config, token: token)
        return state.macs.map { $0.uppercased() }
    }

    // MARK: - Block list management

    private struct FilterState {
        var macs: [String]
        var names: [String]
        var enables: [String]
        var all: String
    }

    private func update(device: Device, config: RouterConfig, password: String, block: Bool) async throws -> RouterActionResult {
        guard let mac = device.mac?.uppercased() else { throw RouterError.deviceHasNoMAC }
        let token = try await login(config: config, password: password)
        var state = try await readFilterState(config: config, token: token)

        if block {
            if !state.macs.contains(mac) {
                state.macs.append(mac)
                state.names.append(device.displayName)
                state.enables.append("1")
            }
            state.all = "1"
        } else {
            if let idx = state.macs.firstIndex(of: mac) {
                state.macs.remove(at: idx)
                if idx < state.names.count { state.names.remove(at: idx) }
                if idx < state.enables.count { state.enables.remove(at: idx) }
            }
        }

        let ok = try await writeFilterState(state, config: config, token: token)
        guard ok else {
            throw RouterError.unsupported("This AsusWRT firmware did not accept the Parental Controls update. Your model may use different settings for per-device blocking.")
        }
        return RouterActionResult(success: true,
            message: block ? "\(device.displayName) blocked via ASUS Parental Controls." : "\(device.displayName) restored.")
    }

    private func readFilterState(config: RouterConfig, token: String) async throws -> FilterState {
        let hooks = "nvram_get(MULTIFILTER_MAC);nvram_get(MULTIFILTER_DEVICENAME);nvram_get(MULTIFILTER_ENABLE);nvram_get(MULTIFILTER_ALL)"
        guard let base = baseURL(config),
              let url = URL(string: "/appGet.cgi?hook=\(hooks)", relativeTo: base) else { throw RouterError.unreachable }
        var req = URLRequest(url: url)
        req.setValue("asus_token=\(token)", forHTTPHeaderField: "Cookie")
        let (data, _) = try await makeSession().data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        func list(_ key: String) -> [String] {
            let raw = (json[key] as? String ?? "")
            return raw.split(separator: ">").map(String.init).filter { !$0.isEmpty }
        }
        return FilterState(
            macs: list("MULTIFILTER_MAC"),
            names: list("MULTIFILTER_DEVICENAME"),
            enables: list("MULTIFILTER_ENABLE"),
            all: (json["MULTIFILTER_ALL"] as? String) ?? "0"
        )
    }

    private func writeFilterState(_ state: FilterState, config: RouterConfig, token: String) async throws -> Bool {
        guard let base = baseURL(config),
              let url = URL(string: "/applyapp.cgi", relativeTo: base) else { throw RouterError.unreachable }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "action_mode", value: "apply"),
            URLQueryItem(name: "rc_service", value: "restart_firewall"),
            URLQueryItem(name: "MULTIFILTER_ALL", value: state.all),
            URLQueryItem(name: "MULTIFILTER_MAC", value: state.macs.joined(separator: ">")),
            URLQueryItem(name: "MULTIFILTER_DEVICENAME", value: state.names.joined(separator: ">")),
            URLQueryItem(name: "MULTIFILTER_ENABLE", value: state.enables.joined(separator: ">"))
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("asus_token=\(token)", forHTTPHeaderField: "Cookie")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await makeSession().data(for: req)
        let text = String(data: data, encoding: .utf8) ?? ""
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        // AsusWRT returns 200 and no explicit error on success.
        return code == 200 && !text.lowercased().contains("error_status")
    }

    // MARK: - Auth

    private func login(config: RouterConfig, password: String) async throws -> String {
        guard let base = baseURL(config),
              let url = URL(string: "/login.cgi", relativeTo: base) else { throw RouterError.unreachable }
        let cred = "\(config.username):\(password)"
        guard let auth = cred.data(using: .utf8)?.base64EncodedString() else { throw RouterError.authFailed }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(base.absoluteString, forHTTPHeaderField: "Referer")
        req.httpBody = "login_authorization=\(auth)".data(using: .utf8)

        do {
            let (data, response) = try await makeSession().data(for: req)
            let text = String(data: data, encoding: .utf8) ?? ""
            guard let http = response as? HTTPURLResponse else { throw RouterError.unreachable }

            // Token may arrive in a cookie or in the JSON body depending on firmware.
            if let cookie = http.value(forHTTPHeaderField: "Set-Cookie"),
               let token = extractToken(from: cookie) {
                return token
            }
            if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let token = json["asus_token"] as? String {
                return token
            }
            if text.contains("error_status") { throw RouterError.authFailed }
            throw RouterError.authFailed
        } catch let e as RouterError {
            throw e
        } catch {
            throw RouterError.unreachable
        }
    }

    private func extractToken(from cookie: String) -> String? {
        guard let range = cookie.range(of: "asus_token=") else { return nil }
        let rest = cookie[range.upperBound...]
        return rest.split(separator: ";").first.map(String.init)
    }
}
