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
    public var sessionResetSleepThreshold: TimeInterval
    public var idleThreshold: TimeInterval
    public var notificationInterval: NotificationInterval

    public init(
        showSeconds: Bool = false,
        showPlaceNameInMenuBar: Bool = true,
        sessionResetSleepThreshold: TimeInterval = 60 * 60,
        idleThreshold: TimeInterval = 5 * 60,
        notificationInterval: NotificationInterval = .hourly
    ) {
        self.showSeconds = showSeconds
        self.showPlaceNameInMenuBar = showPlaceNameInMenuBar
        self.sessionResetSleepThreshold = sessionResetSleepThreshold
        self.idleThreshold = idleThreshold
        self.notificationInterval = notificationInterval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Preferences()
        self.init(
            showSeconds: try container.decodeIfPresent(Bool.self, forKey: .showSeconds)
                ?? defaults.showSeconds,
            showPlaceNameInMenuBar: try container.decodeIfPresent(
                Bool.self, forKey: .showPlaceNameInMenuBar
            ) ?? defaults.showPlaceNameInMenuBar,
            sessionResetSleepThreshold: try container.decodeIfPresent(
                TimeInterval.self, forKey: .sessionResetSleepThreshold
            ) ?? defaults.sessionResetSleepThreshold,
            idleThreshold: try container.decodeIfPresent(
                TimeInterval.self, forKey: .idleThreshold
            ) ?? defaults.idleThreshold,
            notificationInterval: try container.decodeIfPresent(
                NotificationInterval.self, forKey: .notificationInterval
            ) ?? defaults.notificationInterval
        )
    }
}
