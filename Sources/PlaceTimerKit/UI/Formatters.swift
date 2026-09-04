import Foundation

public enum DurationFormat {
    /// Menubar ve panel başlığı için: `2:14`, `0:07`.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 3600, (total % 3600) / 60)
    }

    /// Okunur biçim: `1sa 47dk`, `47dk`, `3dk`.
    public static func readable(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)sa \(minutes)dk" }
        return "\(minutes)dk"
    }

    /// Oturum aralığı: `09:10–11:30` veya süregelen oturum için `12:40–…`.
    public static func range(from start: Date, to end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startText = formatter.string(from: start)
        guard let end else { return "\(startText)–…" }
        return "\(startText)–\(formatter.string(from: end))"
    }

    /// Menubar dar bir yer; uzun adlar kesilir.
    public static func truncate(_ name: String, to limit: Int = 12) -> String {
        guard name.count > limit else { return name }
        return name.prefix(limit - 1).trimmingCharacters(in: .whitespaces) + "…"
    }
}
