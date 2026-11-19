import Foundation

/// Reads the kernel ARP cache (IPv4 → MAC) via sysctl(PF_ROUTE).
///
/// This is the same mechanism Fing-style apps use on iOS. An entry only appears
/// once the OS has resolved that neighbour at the link layer, which is why the
/// discovery service first "touches" every host (UDP/TCP) to populate the cache.
enum ARPTable {

    struct Entry {
        let ip: String
        let mac: String
    }

    static func read() -> [Entry] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, Int32(RTF_LLINFO)]
        var len = 0

        // First call: ask for required buffer size.
        if sysctl(&mib, u_int(mib.count), nil, &len, nil, 0) < 0 { return [] }
        guard len > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: len)
        let status = buffer.withUnsafeMutableBytes { raw -> Int32 in
            sysctl(&mib, u_int(mib.count), raw.baseAddress, &len, nil, 0)
        }
        guard status == 0 else { return [] }

        var entries: [Entry] = []
        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < len {
                let rtm = base.advanced(by: offset).assumingMemoryBound(to: rt_msghdr.self)
                let msgLen = Int(rtm.pointee.rtm_msglen)
                if msgLen == 0 { break }

                // The IPv4 sockaddr immediately follows the header, then the
                // sockaddr_dl (link-layer / MAC). We read the IP part as
                // sockaddr_in — its leading layout matches sockaddr_inarp, which
                // Swift doesn't reliably import.
                let sinPtr = base.advanced(by: offset + MemoryLayout<rt_msghdr>.stride)
                    .assumingMemoryBound(to: sockaddr_in.self)
                let sin = sinPtr.pointee
                let ip = ipString(from: sin.sin_addr)

                let sdlRaw = UnsafeRawPointer(sinPtr)
                    .advanced(by: roundUp(Int(sinPtr.pointee.sin_len)))
                let sdl = sdlRaw.assumingMemoryBound(to: sockaddr_dl.self)
                if let mac = macString(from: sdl), !ip.isEmpty {
                    entries.append(Entry(ip: ip, mac: mac))
                }

                offset += msgLen
            }
        }
        return entries
    }

    private static func roundUp(_ a: Int) -> Int {
        a > 0 ? ((a + 3) & ~3) : 4
    }

    private static func ipString(from addr: in_addr) -> String {
        var a = addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &a, &buf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buf)
    }

    private static func macString(from sdl: UnsafePointer<sockaddr_dl>) -> String? {
        let dl = sdl.pointee
        let alen = Int(dl.sdl_alen)
        guard alen == 6 else { return nil }
        // The link-layer address sits after the interface name inside sdl_data.
        var data = dl.sdl_data
        return withUnsafePointer(to: &data) { ptr -> String? in
            let bytes = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            let start = Int(dl.sdl_nlen)
            var octets: [String] = []
            for i in 0..<6 {
                octets.append(String(format: "%02x", bytes[start + i]))
            }
            let mac = octets.joined(separator: ":")
            // Filter the all-zero / incomplete entries the cache sometimes holds.
            return mac == "00:00:00:00:00:00" ? nil : mac
        }
    }
}
