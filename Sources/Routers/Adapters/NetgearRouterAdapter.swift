import Foundation

/// NETGEAR integration over the local SOAP service (port 5000) exposed by most
/// Nighthawk / Orbi / genie firmware. The envelope flow mirrors the well-known
/// `pynetgear` sequence: SOAPLogin → ConfigurationStarted → SetBlockDeviceByMAC →
/// ConfigurationFinished. Older or locked-down firmware may not expose
/// `SetBlockDeviceByMAC`; in that case we surface `.unsupported` rather than lie.
struct NetgearRouterAdapter: RouterAdapter {
    let kind: RouterKind = .netgear

    private let sessionID = "A7D88AE69687E58D9A00"
    private let service = "DeviceConfig"

    private var soapPort: Int { 5000 }

    private func endpoint(_ config: RouterConfig) -> URL? {
        URL(string: "http://\(config.host):\(soapPort)/soap/server_sa/")
    }

    func connect(config: RouterConfig, password: String) async throws {
        _ = try await login(config: config, password: password)
    }

    func restrict(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await setBlock(device: device, config: config, password: password, block: true)
    }

    func restore(device: Device, config: RouterConfig, password: String) async throws -> RouterActionResult {
        try await setBlock(device: device, config: config, password: password, block: false)
    }

    // MARK: - Flow

    private func setBlock(device: Device, config: RouterConfig, password: String, block: Bool) async throws -> RouterActionResult {
        guard let mac = device.mac else { throw RouterError.deviceHasNoMAC }
        let session = try await login(config: config, password: password)

        try await call(method: "ConfigurationStarted", service: service, config: config,
                       cookie: session, bodyParams: "<NewSessionID>\(sessionID)</NewSessionID>")

        let action = block ? "Block" : "Allow"
        let params = "<NewAllowOrBlock>\(action)</NewAllowOrBlock><NewMACAddress>\(mac.uppercased())</NewMACAddress>"
        let (ok, raw) = try await call(method: "SetBlockDeviceByMAC", service: service, config: config,
                                       cookie: session, bodyParams: params)

        try? await call(method: "ConfigurationFinished", service: service, config: config,
                        cookie: session, bodyParams: "<NewStatus>ChangesApplied</NewStatus>")

        guard ok else {
            if raw.contains("401") || raw.lowercased().contains("unauthor") { throw RouterError.authFailed }
            throw RouterError.unsupported("This NETGEAR firmware did not accept the block/allow command (SetBlockDeviceByMAC). Your model may not support per-device access control over the local API.")
        }
        return RouterActionResult(success: true,
            message: block ? "\(device.displayName) blocked by the router." : "\(device.displayName) restored.")
    }

    @discardableResult
    private func login(config: RouterConfig, password: String) async throws -> String {
        let body = "<Username>\(xml(config.username))</Username><Password>\(xml(password))</Password>"
        let (ok, raw, setCookie) = try await rawCall(method: "SOAPLogin", service: service,
                                                     config: config, cookie: nil, bodyParams: body)
        guard ok else {
            if raw.contains("401") { throw RouterError.authFailed }
            throw RouterError.authFailed
        }
        return setCookie ?? ""
    }

    @discardableResult
    private func call(method: String, service: String, config: RouterConfig, cookie: String, bodyParams: String) async throws -> (Bool, String) {
        let (ok, raw, _) = try await rawCall(method: method, service: service, config: config, cookie: cookie, bodyParams: bodyParams)
        return (ok, raw)
    }

    private func rawCall(method: String, service: String, config: RouterConfig, cookie: String?, bodyParams: String) async throws -> (Bool, String, String?) {
        guard let url = endpoint(config) else { throw RouterError.unreachable }
        let soapAction = "urn:NETGEAR-ROUTER:service:\(service):1#\(method)"
        let envelope = """
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAPSDK1="http://www.w3.org/2001/XMLSchema" xmlns:SOAPSDK2="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAPSDK3="http://schemas.xmlsoap.org/soap/encoding/">
        <SOAP-ENV:Header><SessionID>\(sessionID)</SessionID></SOAP-ENV:Header>
        <SOAP-ENV:Body>
        <M1:\(method) xmlns:M1="urn:NETGEAR-ROUTER:service:\(service):1">\(bodyParams)</M1:\(method)>
        </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
        """

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue(soapAction, forHTTPHeaderField: "SOAPAction")
        if let cookie, !cookie.isEmpty { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        req.httpBody = envelope.data(using: .utf8)

        let session = makeSession()
        do {
            let (data, response) = try await session.data(for: req)
            let text = String(data: data, encoding: .utf8) ?? ""
            let http = response as? HTTPURLResponse
            let setCookie = http?.value(forHTTPHeaderField: "Set-Cookie")
            let ok = (http?.statusCode == 200) && text.contains("ResponseCode>000")
            return (ok, text.isEmpty ? "HTTP \(http?.statusCode ?? -1)" : text, setCookie)
        } catch {
            throw RouterError.unreachable
        }
    }

    private func xml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
