import Foundation

/// Best-effort reverse-DNS (PTR) lookup for an IPv4 address.
enum ReverseDNS {
    static func hostname(for ip: String) -> String? {
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_INET, ai_socktype: 0, ai_protocol: 0,
            ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ip, nil, &hints, &info) == 0, let addr = info else { return nil }
        defer { freeaddrinfo(info) }

        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            addr.pointee.ai_addr, addr.pointee.ai_addrlen,
            &host, socklen_t(host.count), nil, 0, NI_NAMEREQD
        )
        guard result == 0 else { return nil }
        let name = String(cString: host)
        // If the resolver just echoed the IP back, it isn't a real name.
        return name == ip ? nil : name
    }
}
