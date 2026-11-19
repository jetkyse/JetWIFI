import Foundation

/// Reads the device's own IPv4 address and subnet from the active Wi-Fi interface,
/// and enumerates the host addresses in that subnet.
enum NetworkInterface {

    struct Info {
        let localIP: String
        let netmask: String
        /// Best guess at the gateway (x.x.x.1 of the subnet).
        let gatewayGuess: String
        let hostAddresses: [String]
    }

    /// Returns info for the Wi-Fi interface (`en0`) if connected.
    static func current() -> Info? {
        guard let (ip, mask) = ipAndMask(for: "en0") else { return nil }
        let hosts = hostAddresses(ip: ip, mask: mask)
        let gateway = gatewayGuess(ip: ip, mask: mask)
        return Info(localIP: ip, netmask: mask, gatewayGuess: gateway, hostAddresses: hosts)
    }

    /// Pulls the IPv4 address and netmask for a named interface via getifaddrs.
    static func ipAndMask(for name: String) -> (ip: String, mask: String)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var result: (String, String)?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let addr = p.pointee.ifa_addr.pointee
            let ifName = String(cString: p.pointee.ifa_name)
            if addr.sa_family == UInt8(AF_INET), ifName == name {
                let ipStr = Self.string(from: p.pointee.ifa_addr)
                let maskStr = Self.string(from: p.pointee.ifa_netmask)
                if let ipStr, let maskStr {
                    result = (ipStr, maskStr)
                    break
                }
            }
            ptr = p.pointee.ifa_next
        }
        return result
    }

    private static func string(from sockaddr: UnsafeMutablePointer<sockaddr>?) -> String? {
        guard let sockaddr else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let len = socklen_t(sockaddr.pointee.sa_len)
        let err = getnameinfo(sockaddr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        guard err == 0 else { return nil }
        return String(cString: host)
    }

    /// Enumerates usable host addresses in the subnet (skips network, broadcast, and self).
    static func hostAddresses(ip: String, mask: String) -> [String] {
        guard let ipN = ipv4ToUInt32(ip), let maskN = ipv4ToUInt32(mask) else { return [] }
        let network = ipN & maskN
        let broadcast = network | ~maskN
        // Guard against scanning enormous subnets (e.g. a /8). Cap at a /22 = 1022 hosts.
        let count = broadcast - network
        guard count > 1, count <= 1024 else { return [] }

        var hosts: [String] = []
        var addr = network + 1
        while addr < broadcast {
            if addr != ipN {
                hosts.append(uint32ToIPv4(addr))
            }
            addr += 1
        }
        return hosts
    }

    static func gatewayGuess(ip: String, mask: String) -> String {
        guard let ipN = ipv4ToUInt32(ip), let maskN = ipv4ToUInt32(mask) else { return ip }
        let network = ipN & maskN
        return uint32ToIPv4(network + 1)
    }

    static func ipv4ToUInt32(_ s: String) -> UInt32? {
        let parts = s.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 <= 255 }) else { return nil }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }

    static func uint32ToIPv4(_ n: UInt32) -> String {
        "\((n >> 24) & 0xFF).\((n >> 16) & 0xFF).\((n >> 8) & 0xFF).\(n & 0xFF)"
    }
}
