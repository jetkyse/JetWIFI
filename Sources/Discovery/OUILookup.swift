import Foundation

/// Maps a MAC address prefix (OUI) to a hardware vendor.
///
/// This ships with a compact built-in table of the most common consumer vendors.
/// To cover the full IEEE registry, drop the official `oui.csv` into Resources and
/// `OUILookup` will load and prefer it automatically (see `loadExtendedTable`).
enum OUILookup {

    /// First-24-bits prefix (uppercase, no separators) → vendor.
    private static let builtIn: [String: String] = [
        "FCFBFB": "Apple", "F0989D": "Apple", "A4C361": "Apple", "DC2B2A": "Apple",
        "D0817A": "Apple", "C82A14": "Apple", "B8E856": "Apple", "A860B6": "Apple",
        "001451": "Apple", "0023DF": "Apple", "3C0754": "Apple", "685B35": "Apple",
        "F4F15A": "Apple", "9C207B": "Apple",
        "001A11": "Google", "F4F5D8": "Google", "F88FCA": "Google", "A47733": "Google",
        "D8EB46": "Google", "3C5AB4": "Google",
        "FC65DE": "Amazon", "44650D": "Amazon", "84D6D0": "Amazon", "F0272D": "Amazon",
        "6837E9": "Amazon", "0C47C9": "Amazon", "40B4CD": "Amazon",
        "B827EB": "Raspberry Pi", "DCA632": "Raspberry Pi", "E45F01": "Raspberry Pi",
        "D83ADD": "Raspberry Pi", "2CCF67": "Raspberry Pi",
        "001882": "Samsung", "5056BF": "Samsung", "8425DB": "Samsung", "F008F1": "Samsung",
        "C01173": "Samsung", "341513": "Samsung",
        "00236C": "Cisco", "001D7E": "Cisco-Linksys", "C0C1C0": "Cisco",
        "AC84C6": "TP-Link", "50C7BF": "TP-Link", "C006C3": "TP-Link", "9C5322": "TP-Link",
        "B0BE76": "TP-Link", "003192": "TP-Link", "1C61B4": "TP-Link",
        "A0F3C1": "TP-Link", "E894F6": "TP-Link",
        "2C3033": "NETGEAR", "A040A0": "NETGEAR", "9CD36D": "NETGEAR", "3894ED": "NETGEAR",
        "C03F0E": "NETGEAR", "204E7F": "NETGEAR",
        "AC9E17": "ASUS", "2C56DC": "ASUS", "F832E4": "ASUS", "04D4C4": "ASUS",
        "1C872C": "ASUS", "D017C2": "ASUS", "BCEE7B": "ASUS",
        "F0B4D2": "eero", "8CC8CD": "eero", "4C1744": "eero",
        "00111A": "Ring", "F8F005": "Ring",
        "18B430": "Nest", "641666": "Nest",
        "D073D5": "Nanoleaf", "B0C5CA": "Sonos", "5CAAFD": "Sonos", "949F3E": "Sonos",
        "00042F": "Roku", "CCB8A8": "Roku", "DC3A5E": "Roku",
        "7C2EBD": "Microsoft", "5CBA37": "Microsoft", "C83F26": "Microsoft",
        "0017FA": "Microsoft Xbox", "7CED8D": "Microsoft",
        "C863FC": "Sony PlayStation", "F8461C": "Sony", "A8E3EE": "Sony PlayStation",
        "98B6E9": "Nintendo", "582F40": "Nintendo", "0CFE45": "Nintendo",
        "001788": "Philips Hue", "ECB5FA": "Philips Hue"
    ]

    private static var extended: [String: String] = loadExtendedTable()

    /// Returns the vendor for a MAC like `ac:9e:17:12:34:56`, or nil.
    static func vendor(for mac: String?) -> String? {
        guard let mac else { return nil }
        let prefix = mac
            .uppercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .prefix(6)
        let key = String(prefix)
        return extended[key] ?? builtIn[key]
    }

    /// Loads an optional bundled `oui.csv` (format: `AABBCC,Vendor Name`).
    private static func loadExtendedTable() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "oui", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }
        var table: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let cols = line.split(separator: ",", maxSplits: 1)
            guard cols.count == 2 else { continue }
            let key = cols[0].uppercased().replacingOccurrences(of: ":", with: "")
            table[String(key.prefix(6))] = cols[1].trimmingCharacters(in: .whitespaces)
        }
        return table
    }
}
