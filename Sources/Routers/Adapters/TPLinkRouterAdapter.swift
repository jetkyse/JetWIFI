import Foundation

/// TP-Link integration.
///
/// TP-Link local admin is the least consistent of the major brands: Archer models
/// use an RSA-encrypted `/cgi-bin/luci` login that changes across firmware, Deco
/// and newer cloud models have no usable local admin API at all (they require the
/// Tether app + TP-Link cloud). Rather than pretend a single flow works everywhere,
/// this adapter probes for a classic local admin page and, when it finds the modern
/// encrypted login it can't safely automate, reports the limitation honestly.
struct TPLinkRouterAdapter: RouterAdapter {
    let kind: RouterKind = .tplink

    func connect(config: RouterConfig, password: String) async throws {
        guard let base = baseURL(config) else { throw RouterError.unreachable }
        var req = URLRequest(url: base)
        req.httpMethod = "GET"
        do {
            let (data, response) = try await makeSession().data(for: req)
            guard (response as? HTTPURLResponse) != nil else { throw RouterError.unreachable }
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("RSA") || text.contains("encrypt") || text.lowercased().contains("tether") {
                throw RouterError.unsupported("This TP-Link model uses an encrypted or cloud-only (Tether) login that JetWIFI can't drive from the device. Blocking must be done in the TP-Link Tether app. JetWIFI can still discover and track devices on this network.")
            }
            // Reached a classic admin page — connection is viable, but blocking still
            // depends on the specific access-control form, which we don't assume.
        } catch let e as RouterError {
            throw e
        } catch {
            throw RouterError.unreachable
        }
    }

    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported("Per-device blocking isn't available for TP-Link from JetWIFI. TP-Link's local access-control form differs by model and firmware, and newer models are cloud-only. Use the TP-Link Tether app's 'Block' / 'Blocklist' feature.")
    }

    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        throw RouterError.unsupported("Restoring access isn't available for TP-Link from JetWIFI. Use the TP-Link Tether app.")
    }
}
