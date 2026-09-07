import Foundation
import PlaceTimerCore

public enum DurationFormat {
    /// Menubar ve panel başlığı için: `2:14` veya `2:14:07`.
    public static func clock(
        _ seconds: TimeInterval,
        showSeconds: Bool = false
    ) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        guard showSeconds else {
            return String(format: "%d:%02d", hours, minutes)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, total % 60)
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

/// Menubar başlığının kuruluşu.
///
/// Hem sahne hem de ayarlardaki önizleme aynı metni üretmek zorunda: önizleme
/// biçimi kendi kurarsa kullanıcı ayarı değiştirir, önizleme bir şey gösterir,
/// menubar başka bir şey. Tek kaynak burası.
public enum MenuBarTitle {
    public static func text(
        placeName: String,
        elapsed: TimeInterval,
        preferences: Preferences,
        needsLocationPermission: Bool = false
    ) -> String {
        guard !needsLocationPermission else { return "◷ İzin gerekli" }
        let time = DurationFormat.clock(elapsed, showSeconds: preferences.showSeconds)
        guard preferences.showPlaceNameInMenuBar else { return time }
        return "\(DurationFormat.truncate(placeName)) · \(time)"
    }
}
