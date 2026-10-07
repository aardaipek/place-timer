import Foundation

/// Bildirimlerin hangi sıklıkta düşeceği.
public enum NotificationInterval: String, Codable, Sendable, CaseIterable {
    case off
    case every30Minutes
    case hourly

    /// `nil` bildirimlerin tamamen kapalı olduğu anlamına gelir.
    public var seconds: TimeInterval? {
        switch self {
        case .off: nil
        case .every30Minutes: 30 * 60
        case .hourly: 60 * 60
        }
    }

    public var displayName: String {
        switch self {
        case .off: "Kapalı"
        case .every30Minutes: "30 dakikada bir"
        case .hourly: "Saatte bir"
        }
    }
}

/// Kullanıcı ayarları. `preferences.json` dosyasında saklanır.
///
/// Her alan `decodeIfPresent` ile okunur: ileride yeni bir ayar eklendiğinde
/// kullanıcının mevcut dosyası bozulmasın, eksik alan varsayılanına düşsün.
public struct Preferences: Codable, Sendable, Equatable {
    public var showSeconds: Bool
    public var showPlaceNameInMenuBar: Bool
    /// Bu süreden uzun ara (uyku, ekran kapalı, dokunmamak) oturumu, aranın
    /// başladığı anda kapatır.
    public var gapThreshold: TimeInterval
    public var notificationInterval: NotificationInterval

    /// Ayarlarda sunulan ara eşikleri. "Hemen" yok: ekran kararması da ara
    /// sayıldığı için her bakışını kaçıran kullanıcının oturumu bölünürdü.
    public static let gapOptions: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60, 2 * 60 * 60]

    public init(
        showSeconds: Bool = false,
        showPlaceNameInMenuBar: Bool = true,
        gapThreshold: TimeInterval = 30 * 60,
        notificationInterval: NotificationInterval = .hourly
    ) {
        self.showSeconds = showSeconds
        self.showPlaceNameInMenuBar = showPlaceNameInMenuBar
        self.gapThreshold = gapThreshold
        self.notificationInterval = notificationInterval
    }

    /// Seçenek listesindeki en yakın değer. 1.0'ın serbest uyku eşiği
    /// (0'dan 4 saate) buradan geçerek yeni listeye oturuyor.
    public static func nearestGapOption(to seconds: TimeInterval) -> TimeInterval {
        gapOptions.min { abs($0 - seconds) < abs($1 - seconds) } ?? 30 * 60
    }

    private enum CodingKeys: String, CodingKey {
        case showSeconds, showPlaceNameInMenuBar, gapThreshold, notificationInterval
    }

    /// 1.0 bu anahtarları yazıyordu. Ayrı bir anahtar kümesinden okuyoruz ki
    /// `encode` sentezlenmeye devam etsin ve eski anahtarlar geri yazılmasın.
    private enum LegacyKeys: String, CodingKey {
        case sessionResetSleepThreshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let defaults = Preferences()

        let gap = try container.decodeIfPresent(TimeInterval.self, forKey: .gapThreshold)
            ?? legacy.decodeIfPresent(
                TimeInterval.self, forKey: .sessionResetSleepThreshold
            ).map(Self.nearestGapOption(to:))
            ?? defaults.gapThreshold

        self.init(
            showSeconds: try container.decodeIfPresent(Bool.self, forKey: .showSeconds)
                ?? defaults.showSeconds,
            showPlaceNameInMenuBar: try container.decodeIfPresent(
                Bool.self, forKey: .showPlaceNameInMenuBar
            ) ?? defaults.showPlaceNameInMenuBar,
            gapThreshold: gap,
            notificationInterval: try container.decodeIfPresent(
                NotificationInterval.self, forKey: .notificationInterval
            ) ?? defaults.notificationInterval
        )
    }
}
