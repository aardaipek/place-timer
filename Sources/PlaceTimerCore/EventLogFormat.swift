import Foundation

/// `events.log` satırları: `<ISO8601> <mesaj>\n`. Oturum beklenmedik biçimde
/// bölündüğünde nedenini (konum kayması mı, kısa ağ geçişi mi) veriyle görmek
/// için tutulur; cihazdan çıkmaz.
public enum EventLogFormat {
    public static let keepDays = 14

    public static func line(_ message: String, at date: Date) -> String {
        let flat = message.replacingOccurrences(of: "\n", with: " ")
        return "\(date.formatted(.iso8601)) \(flat)\n"
    }

    public static func pruned(_ text: String, now: Date, keepDays: Int = keepDays) -> String {
        let cutoff = now.addingTimeInterval(-Double(keepDays) * 86400)
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { line in
                guard
                    let stamp = line.split(separator: " ", maxSplits: 1).first,
                    let date = try? Date(String(stamp), strategy: .iso8601)
                else { return false }
                return date >= cutoff
            }
            .map { $0 + "\n" }
            .joined()
    }
}
