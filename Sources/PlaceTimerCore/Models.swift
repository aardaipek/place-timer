import Foundation

/// Bir yerin kimliği.
///
/// Bir yer birden çok SSID'ye sahip olabilir: router'lar 2.4 GHz ve 5 GHz
/// bantlarını çoğu zaman ayrı adlarla yayınlar (`Ev` ve `Ev-5G`), ve Mac bant
/// değiştirdiğinde SSID değişir. Tek SSID anahtar olsaydı bu, yer değişimi
/// sanılıp oturumu boş yere sıfırlardı.
///
/// Koordinat, aynı SSID'yi paylaşan zincir şubelerini ayırt etmek için saklanır.
public struct Place: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var ssids: Set<String>
    public var bssids: Set<String>
    public var displayName: String
    public var latitude: Double?
    public var longitude: Double?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        ssids: Set<String>,
        bssids: Set<String> = [],
        displayName: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.ssids = ssids
        self.bssids = bssids
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }
}

/// Tek bir oturum: bir yerde kesintisiz geçirilen zaman dilimi.
public struct Session: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    /// Oturum "Bilinmeyen yer"de başladıysa nil; yer sonradan çözülürse doldurulur.
    public var placeID: UUID?
    public let startedAt: Date
    public var endedAt: Date?
    /// Klavye/fare etkinliği olan saniyelerin toplamı.
    public var activeSeconds: TimeInterval
    /// Bildirimi gönderilmiş aralık işaretleri (1, 2, 3 …). Yeniden başlatmada
    /// aynı bildirimin tekrar gitmemesi için diske yazılır.
    public var notifiedMarks: Set<Int>

    public init(
        id: UUID = UUID(),
        placeID: UUID?,
        startedAt: Date,
        endedAt: Date? = nil,
        activeSeconds: TimeInterval = 0,
        notifiedMarks: Set<Int> = []
    ) {
        self.id = id
        self.placeID = placeID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.notifiedMarks = notifiedMarks
    }

    private enum CodingKeys: String, CodingKey {
        case id, placeID, startedAt, endedAt, activeSeconds, notifiedMarks
    }

    /// v1 bu alanı `notifiedHourMarks` diye yazıyordu. Ayrı bir anahtar
    /// kümesinden okuyoruz ki `encode` sentezlenmeye devam etsin.
    private enum LegacyKeys: String, CodingKey {
        case notifiedHourMarks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            placeID: try container.decodeIfPresent(UUID.self, forKey: .placeID),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            endedAt: try container.decodeIfPresent(Date.self, forKey: .endedAt),
            activeSeconds: try container.decodeIfPresent(
                TimeInterval.self, forKey: .activeSeconds
            ) ?? 0,
            notifiedMarks: try container.decodeIfPresent(
                Set<Int>.self, forKey: .notifiedMarks
            ) ?? legacy.decodeIfPresent(
                Set<Int>.self, forKey: .notifiedHourMarks
            ) ?? []
        )
    }

    /// Yerde geçen süre: duvar saati, 60 dk altındaki uyku aralarını içerir.
    public func elapsed(at now: Date) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

/// Wi-Fi taramasının sonucu. `.unknown`, Wi-Fi'ye bağlı olunmadığı anlamına
/// gelir ve oturumu kapatmaz — yalnızca görünen adı etkiler.
public enum PlaceRef: Sendable, Equatable, Hashable {
    case known(UUID)
    case unknown
}

/// `SessionEngine`'in tükettiği olaylar. Hiçbiri sistem tipi içermez.
public enum SessionEvent: Sendable, Equatable {
    case wake
    case sleep
    case screenLocked
    case screenUnlocked
    case placeResolved(PlaceRef)
    /// Saniyede bir; `idleSeconds` son kullanıcı girdisinden bu yana geçen süre.
    case tick(idleSeconds: TimeInterval)
    /// Kullanıcı sayacı elle sıfırladı: oturum kapanır, aynı yerde yenisi açılır.
    case endSessionRequested
}

/// Motorun dışarıya bildirdiği yan etkiler. Motor bunları kendisi uygulamaz.
public enum SessionEffect: Sendable, Equatable {
    case sessionStarted(Session)
    case sessionEnded(Session)
    /// `index` kaçıncı aralık, `elapsed` o anda yerde geçen toplam süre.
    /// Bildirim metni süreyi yazacağı için ham indeksi tek başına taşımak yetmez.
    case markReached(index: Int, elapsed: TimeInterval, placeID: UUID?)
}

public struct EngineConfiguration: Sendable, Equatable {
    /// Bu süreyi aşan uyku oturumu kapatır.
    public var sessionResetSleepThreshold: TimeInterval
    /// Bu süreden uzun hareketsizlikte aktif sayaç durur.
    public var idleThreshold: TimeInterval
    /// İki tick arasında sayaca eklenebilecek azami süre; kaçan tick'lerin
    /// aktif süreyi şişirmesini engeller.
    public var maxTickDelta: TimeInterval
    /// Bildirim aralığı saniye cinsinden; `nil` ise bildirim üretilmez.
    public var notificationInterval: TimeInterval?

    public init(
        sessionResetSleepThreshold: TimeInterval = 60 * 60,
        idleThreshold: TimeInterval = 5 * 60,
        maxTickDelta: TimeInterval = 5,
        notificationInterval: TimeInterval? = 60 * 60
    ) {
        self.sessionResetSleepThreshold = sessionResetSleepThreshold
        self.idleThreshold = idleThreshold
        self.maxTickDelta = maxTickDelta
        self.notificationInterval = notificationInterval
    }

    /// Kullanıcı ayarlarından türetir.
    public init(preferences: Preferences) {
        self.init(
            sessionResetSleepThreshold: preferences.sessionResetSleepThreshold,
            idleThreshold: preferences.idleThreshold,
            notificationInterval: preferences.notificationInterval.seconds
        )
    }
}
