# PlaceTimer v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Oturumları doğru ölç (tek ara eşiği, yer kararlılığı, aynı yere dönüşte geri açma, gün sınırında kırpma), düzeltmeyi öneri + elle birleştirme ile kolaylaştır, ayarlar penceresini Liquid Glass diline taşı ve 1.1.0'ı TestFlight'a çıkar.

**Architecture:** Bütün kurallar `PlaceTimerCore`'da saf, zamanı dışarıdan alan fonksiyon ve değer tiplerinde yaşar ve `swift test` ile sınanır. `PlaceTimerKit` yalnızca bağlar: `AppCoordinator` motoru, depoları, öneri durumunu ve olay günlüğünü yönetir; SwiftUI view'ları koordinatörü okur. Ayarlar penceresi `NSHostingController` köprüsüyle gerçek bir cam araç çubuğu ve yüzen kenar çubuğu alır.

**Tech Stack:** Swift 6.2, SwiftUI (macOS 26, Liquid Glass), Swift Charts, Swift Testing, CoreWLAN/CoreLocation (mevcut), SwiftPM.

**Spec:** `docs/superpowers/specs/2026-10-07-place-timer-v3-design.md`

## Global Constraints

- Minimum macOS 26 (`Package.swift` `.macOS(.v26)`), `swift-tools-version: 6.2`. Üçüncü parti bağımlılık yok.
- `PlaceTimerCore` sistem çerçevesine dokunmaz (Foundation hariç); her fonksiyon `now: Date` alır.
- Arayüz metinleri Türkçe ve tam Türkçe karakterli. Saatler `tr_TR`, 24 saat ("12:36").
- Ara eşiği seçenekleri: 15 dk · **30 dk (varsayılan)** · 1 saat · 2 saat. "Hemen" yok.
- Yer kararlılık süresi: **3 dakika**.
- Öneri eşikleri: aynı ad (büyük/küçük harf, aksan ve kenar boşluğu duyarsız) ya da ≤ **150 m**; bölünmüş oturum aralığı < **3 × ara eşiği**; boş oturum < **2 dakika**.
- Olay günlüğü en fazla **14 gün** tutar, cihazdan çıkmaz.
- Hafta **pazartesi** başlar, sistem bölgesinden bağımsız (`Calendar.placeTimer`).
- Ayarlar penceresi sabit **720 × 560**, kenar çubuğu **200**.
- Sürüm: `CFBundleShortVersionString` **1.1.0**, `CFBundleVersion` **5**.
- Eski `preferences.json` / `state.json` dosyaları bozulmadan okunur (`decodeIfPresent`).
- Her görev sonunda `swift build` ve `swift test` temiz; son görevde `swift build -Xswiftc -warnings-as-errors`.
- Commit mesajları Türkçe, ASCII (repo geleneği), sonda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Sistem bölgesi en_US iken hafta başı:** kullanıcının Mac'i İngilizce bölgede; "Bu hafta" pazar değil pazartesi başlamalı → Task 4'te test.
2. **Silinen/düzenlenen oturumun hayaleti:** motorun `recentlyEnded` listesinde kalan, kullanıcının sildiği bir oturum aynı yere dönüşte geri açılmamalı → Task 3 (`forgetRecent`) ve Task 5'te test.
3. **1.0'dan kalan dosyalar:** `sessionResetSleepThreshold: 0` içeren tercih ve `recentlyEnded` içermeyen durum dosyası çökmeden doğru varsayılana düşmeli → Task 1 ve Task 3'te test.
4. **Uzaktayken gelen Wi-Fi olayı:** kullanıcı yokken (oturum hareketsizlikten kapanmışken) gelen bir ağ çözümü oturum açmamalı → Task 2'de test.
5. **Boş veri:** hiç yer/oturum yokken öneri, istatistik ve CSV boş döner, çökmez → Task 4 ve Task 6'da test.

---

## Dosya haritası

| Dosya | Sorumluluk | Görev |
|---|---|---|
| `Sources/PlaceTimerCore/Preferences.swift` | `gapThreshold`, eski anahtardan göç | 1 |
| `Sources/PlaceTimerCore/Models.swift` | `SessionEvent`, `SessionEffect`, `EngineConfiguration`, `Session.startedAt` var | 1, 2, 3, 5 |
| `Sources/PlaceTimerCore/SessionEngine.swift` | Ara, kararlılık, geri açma, düzeltme kancaları | 1, 2, 3, 5 |
| `Sources/PlaceTimerCore/Storage/AppState.swift` | `recentlyEnded` kalıcılığı | 3 |
| `Sources/PlaceTimerCore/Statistics.swift` | Takvim, dönem, kırpma, toplamlar, gün listesi, CSV | 4 |
| `Sources/PlaceTimerCore/History.swift` | `merge`, `update`, `EditError` | 5 |
| `Sources/PlaceTimerCore/Suggestions.swift` (yeni) | `Suggestion`, `SuggestionState`, üretim | 6 |
| `Sources/PlaceTimerCore/EventLogFormat.swift` (yeni) | Günlük satırı ve budama | 7 |
| `Sources/PlaceTimerKit/EventLog.swift` (yeni) | Günlük dosyası | 7 |
| `Sources/PlaceTimerKit/AppCoordinator.swift` | Bağlama | 1–7 |
| `Sources/PlaceTimerKit/PowerMonitor.swift` | Ekran bildirimleri uyku değil | 1 |
| `Sources/PlaceTimerKit/LocationService.swift` | Konum doğruluğu | 7 |
| `Sources/PlaceTimerKit/UI/AppWindow.swift` | Ayarlar penceresi stili | 8 |
| `Sources/PlaceTimerKit/UI/SettingsView.swift`, `Settings/SettingsTab.swift`, `Design.swift` | Cam kabuk | 8 |
| `Sources/PlaceTimerKit/UI/Settings/Statistics/*` (yeni klasör) | İstatistik sayfası | 9 |
| `Sources/PlaceTimerKit/UI/Panel*`, `PlacePromptView.swift`, `DayStripView.swift`, `Formatters.swift` | Panel | 4, 10 |
| `Resources/Info.plist`, `Resources/PlaceTimer.entitlements`, `docs/*` | Sürüm, izin, belge | 9, 11 |

---

### Task 1: Tek ara eşiği

Uyku, ekranın kararması ve dokunmamak tek kurala bağlanır. Eski iki eşik ve "aktif süre" kalkar.

**Files:**
- Modify: `Sources/PlaceTimerCore/Preferences.swift`
- Modify: `Sources/PlaceTimerCore/Models.swift` (`SessionEvent`, `EngineConfiguration`)
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift` (tamamı)
- Modify: `Sources/PlaceTimerKit/PowerMonitor.swift`, `Sources/PlaceTimerKit/AppCoordinator.swift`
- Modify: `Sources/PlaceTimerKit/UI/Settings/ThresholdOption.swift`, `Sources/PlaceTimerKit/UI/Settings/GeneralSettingsView.swift`, `Sources/PlaceTimerKit/UI/PanelSummaryView.swift`
- Modify: `Tests/PlaceTimerCoreTests/PreferencesTests.swift` (tamamı), `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`
- Create: `Tests/PlaceTimerCoreTests/GapRuleTests.swift`

**Interfaces:**
- Produces: `Preferences.gapThreshold: TimeInterval`, `Preferences.gapOptions: [TimeInterval]`, `Preferences.nearestGapOption(to:) -> TimeInterval`; `EngineConfiguration(gapThreshold:placeChangeStability:notificationInterval:)` ve alanları; `SessionEvent` = `.wake, .sleep, .placeResolved(PlaceRef), .tick(idleSeconds:), .endSessionRequested`; motorda `private mutating func startSession(at:placeID:) -> [SessionEffect]` (dizi döner — Task 3 buna geri açmayı ekler).

- [ ] **Step 1: Tercih testlerini yeni davranışa göre yaz**

`Tests/PlaceTimerCoreTests/PreferencesTests.swift` dosyasının tamamını şununla değiştir:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Tercihler")
struct PreferencesTests {

    @Test("Varsayılanlar")
    func defaults() {
        let prefs = Preferences()

        #expect(prefs.showSeconds == false)
        #expect(prefs.showPlaceNameInMenuBar == true)
        #expect(prefs.gapThreshold == 1800)
        #expect(prefs.notificationInterval == .hourly)
    }

    @Test("Bildirim aralıkları saniyeye çevrilir")
    func intervalSeconds() {
        #expect(NotificationInterval.off.seconds == nil)
        #expect(NotificationInterval.every30Minutes.seconds == 1800)
        #expect(NotificationInterval.hourly.seconds == 3600)
    }

    @Test("Diske yazılıp aynen geri okunur")
    func roundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("preferences.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var prefs = Preferences()
        prefs.showSeconds = true
        prefs.notificationInterval = .every30Minutes
        prefs.gapThreshold = 3600

        let store = JSONFileStore<Preferences>(url: url)
        try store.save(prefs)

        #expect(try store.load() == prefs)
    }

    @Test("Eksik alanlar varsayılanla dolar")
    func partialJSONDecodes() throws {
        let json = Data(#"{"showSeconds": true}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)

        #expect(decoded.showSeconds == true)
        #expect(decoded.notificationInterval == .hourly)
        #expect(decoded.gapThreshold == 1800)
    }

    @Test(
        "1.0'ın uyku eşiği en yakın ara seçeneğine taşınır",
        arguments: [
            (0.0, 900.0), (300.0, 900.0), (900.0, 900.0), (1800.0, 1800.0),
            (3600.0, 3600.0), (7200.0, 7200.0), (14400.0, 7200.0),
        ]
    )
    func legacySleepThresholdMigrates(old: Double, expected: Double) throws {
        let json = Data(
            #"{"sessionResetSleepThreshold": \#(old), "idleThreshold": 300}"#.utf8
        )
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)
        #expect(decoded.gapThreshold == expected)
    }

    @Test("Yeni anahtar eskisine üstün gelir")
    func newKeyWins() throws {
        let json = Data(#"{"gapThreshold": 3600, "sessionResetSleepThreshold": 0}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)
        #expect(decoded.gapThreshold == 3600)
    }

    @Test("Eski anahtarlar diske yazılmaz")
    func legacyKeysAreNotWritten() throws {
        let data = try JSONEncoder().encode(Preferences())
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("sessionResetSleepThreshold"))
        #expect(!text.contains("idleThreshold"))
        #expect(text.contains("gapThreshold"))
    }
}
```

- [ ] **Step 2: Ara kuralı testlerini yaz**

Create `Tests/PlaceTimerCoreTests/GapRuleTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

/// Evde 0. dakikada başlamış bir oturum. Varsayılan ara eşiği 30 dakika.
private func started(
    _ configuration: EngineConfiguration = EngineConfiguration()
) -> SessionEngine {
    var engine = SessionEngine(configuration: configuration)
    engine.handle(.wake, at: at(0))
    engine.handle(.placeResolved(.known(ev)), at: at(0))
    return engine
}

@Suite("Ara eşiği")
struct GapRuleTests {

    @Test("Eşikten kısa uyku oturumu bozmaz, ara süreye dahildir")
    func shortSleepKeepsSession() {
        var engine = started()
        let id = engine.currentSession?.id

        engine.handle(.sleep, at: at(10))
        let effects = engine.handle(.wake, at: at(30))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.elapsed(at: at(30)) == 30 * 60)
    }

    @Test("Eşikten uzun uyku oturumu uykuya dalma anında kapatır")
    func longSleepEndsAtSleep() {
        var engine = started()
        let id = engine.currentSession?.id

        engine.handle(.sleep, at: at(10))
        let effects = engine.handle(.wake, at: at(50))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmadı: \(effects)")
            return
        }
        #expect(ended.id == id)
        #expect(ended.endedAt == at(10))
        #expect(engine.currentSession?.startedAt == at(50))
    }

    @Test("Uyanık ama dokunulmayan Mac oturumu son girdi anında kapatır")
    func idleAwakeEndsAtLastInput() {
        var engine = started()

        // 40. dakikada 31 dakikadır dokunulmuyor: son girdi 9. dakikada.
        let effects = engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmadı: \(effects)")
            return
        }
        #expect(ended.endedAt == at(9))
        #expect(engine.currentSession == nil)
    }

    @Test("Kullanıcı dönünce yeni oturum ilk girdi anında başlar")
    func returnStartsNewSession() {
        var engine = started()
        engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))
        engine.handle(.tick(idleSeconds: 32 * 60), at: at(41))
        #expect(engine.currentSession == nil)

        let effects = engine.handle(.tick(idleSeconds: 2), at: at(120))

        guard case .sessionStarted(let session) = effects.first else {
            Issue.record("oturum açılmadı: \(effects)")
            return
        }
        #expect(session.startedAt == at(120).addingTimeInterval(-2))
        #expect(session.placeID == ev)
    }

    @Test("Eşikten kısa hareketsizlik oturumu bozmaz")
    func shortIdleKeepsSession() {
        var engine = started()
        let effects = engine.handle(.tick(idleSeconds: 29 * 60), at: at(40))
        #expect(effects.isEmpty)
        #expect(engine.currentSession != nil)
    }

    @Test("Uykudayken gelen tick oturumu kapatmaz")
    func ticksWhileAsleepAreIgnored() {
        var engine = started()
        engine.handle(.sleep, at: at(5))
        let effects = engine.handle(.tick(idleSeconds: 3600), at: at(6))
        #expect(effects.isEmpty)
        #expect(engine.currentSession != nil)
    }

    @Test("Eşik değişince yeni değer hemen geçerli olur")
    func thresholdUpdateAppliesImmediately() {
        var engine = started()
        engine.updateConfiguration(EngineConfiguration(gapThreshold: 3600), at: at(1))
        let effects = engine.handle(.tick(idleSeconds: 45 * 60), at: at(50))
        #expect(effects.isEmpty)
        #expect(engine.configuration.gapThreshold == 3600)
    }
}
```

- [ ] **Step 3: Testlerin derlenmediğini gör**

Run: `swift test --filter "GapRuleTests|PreferencesTests"`
Expected: FAIL — `gapThreshold` üyesi yok.

- [ ] **Step 4: `Preferences`'ı değiştir**

`Sources/PlaceTimerCore/Preferences.swift` içinde `Preferences` yapısının tamamını (`NotificationInterval` aynen kalır) şununla değiştir:

```swift
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
```

- [ ] **Step 5: Olayları ve yapılandırmayı değiştir**

`Sources/PlaceTimerCore/Models.swift` içinde:

`SessionEvent`'ten `case screenLocked` ve `case screenUnlocked` satırlarını sil. Kalan hâli:

```swift
/// `SessionEngine`'in tükettiği olaylar. Hiçbiri sistem tipi içermez.
///
/// Ekran kilidi ve ekranın kararması ayrı olay değil: ikisi de `tick`'teki
/// `idleSeconds`'ı büyütür ve ara kuralına oradan girer.
public enum SessionEvent: Sendable, Equatable {
    case wake
    case sleep
    case placeResolved(PlaceRef)
    /// Saniyede bir; `idleSeconds` son kullanıcı girdisinden bu yana geçen süre.
    case tick(idleSeconds: TimeInterval)
    /// Kullanıcı sayacı elle sıfırladı: oturum kapanır, aynı yerde yenisi açılır.
    case endSessionRequested
}
```

`EngineConfiguration`'ın tamamını şununla değiştir:

```swift
public struct EngineConfiguration: Sendable, Equatable {
    /// Bu süreden uzun ara oturumu aranın başladığı anda kapatır.
    public var gapThreshold: TimeInterval
    /// Bilinen bir yerden başka bir bilinen yere geçişin onaylanması için yeni
    /// yerin kesintisiz görülmesi gereken süre. Bant/AP gidip gelmelerini yutar.
    public var placeChangeStability: TimeInterval
    /// Bildirim aralığı saniye cinsinden; `nil` ise bildirim üretilmez.
    public var notificationInterval: TimeInterval?

    public init(
        gapThreshold: TimeInterval = 30 * 60,
        placeChangeStability: TimeInterval = 3 * 60,
        notificationInterval: TimeInterval? = 60 * 60
    ) {
        self.gapThreshold = gapThreshold
        self.placeChangeStability = placeChangeStability
        self.notificationInterval = notificationInterval
    }

    /// Kullanıcı ayarlarından türetir.
    public init(preferences: Preferences) {
        self.init(
            gapThreshold: preferences.gapThreshold,
            notificationInterval: preferences.notificationInterval.seconds
        )
    }
}
```

`Session.activeSeconds` alanının belge yorumunu değiştir (alan kalır, eski dosyalar okunsun diye):

```swift
    /// 1.0'ın klavye/fare etkinliği sayacı. Artık yazılmıyor ve gösterilmiyor;
    /// eski dosyalar bozulmadan okunsun diye alan duruyor.
    public var activeSeconds: TimeInterval
```

`Session.elapsed(at:)` yorumunu "Yerde geçen süre: duvar saati, ara eşiğinden kısa araları içerir." yap.

- [ ] **Step 6: Motoru ara kuralıyla yeniden yaz**

`Sources/PlaceTimerCore/SessionEngine.swift` dosyasının tamamını şununla değiştir:

```swift
import Foundation

/// Oturum durum makinesi.
///
/// Bilinçli olarak hiçbir sistem API'sine dokunmaz: girdileri sade
/// `SessionEvent` değerleri, zaman ise her çağrıya dışarıdan geçirilen bir
/// `Date`'tir. Böylece "90 dakika uyuyup uyandı" gibi senaryolar gerçek zaman
/// beklenmeden test edilebilir.
///
/// Tek kural ara kuralı: uyku, ekranın kararması, kilit ve dokunmamak aynı
/// şeydir. Ara eşikten kısaysa oturum sürer ve ara süreye dahildir; uzunsa
/// oturum aranın başladığı anda kapanır. Agent çalışırken mutfağa giden
/// kullanıcı bilgisayarın başında değildir ama işin içindedir.
public struct SessionEngine: Sendable {
    public private(set) var currentSession: Session?
    public private(set) var currentPlace: PlaceRef
    public private(set) var isAsleep: Bool

    public private(set) var configuration: EngineConfiguration

    private var sleepStartedAt: Date?
    /// Uyandıktan sonraki ilk yer çözümlemesine kadar taşınır. Yer uyku
    /// sırasında değiştiyse eski oturum uyanma anında değil, uykuya dalma
    /// anında kapanmalı — yoksa yolda geçen süre yeni yerin hanesine yazılır.
    private var pendingSleepStart: Date?
    /// Uyanık bir Mac'te kullanıcı ara eşiğinden uzun süre dokunmadığı için
    /// oturum kapandı; ilk girdide yeni oturum açılacak.
    private var isAway = false

    /// - Parameter restoring: Diskten okunan açık oturum. Uygulama çökse veya
    ///   güncellense bile oturum kaldığı yerden devam eder.
    public init(
        configuration: EngineConfiguration = EngineConfiguration(),
        restoring session: Session? = nil
    ) {
        self.configuration = configuration
        self.currentSession = session
        self.currentPlace = session?.placeID.map { PlaceRef.known($0) } ?? .unknown
        self.isAsleep = false
    }

    /// Oturumun o yerde geçirdiği duvar saati süresi.
    public func elapsed(at now: Date) -> TimeInterval {
        currentSession?.elapsed(at: now) ?? 0
    }

    /// Ayarlar değişince yapılandırmayı, açık oturumu bozmadan günceller.
    ///
    /// Bildirim aralığı değişirse geçmiş işaretler dolu sayılır. Aksi halde
    /// saatlikten 30 dakikalığa geçildiğinde o ana kadar birikmiş bütün
    /// bildirimler topluca düşerdi.
    public mutating func updateConfiguration(
        _ configuration: EngineConfiguration,
        at now: Date
    ) {
        let previousInterval = self.configuration.notificationInterval
        self.configuration = configuration

        guard
            configuration.notificationInterval != previousInterval,
            let interval = configuration.notificationInterval, interval > 0,
            var session = currentSession
        else { return }

        let passed = Int(session.elapsed(at: now) / interval)
        session.notifiedMarks = passed >= 1 ? Set(1...passed) : []
        currentSession = session
    }

    @discardableResult
    public mutating func handle(_ event: SessionEvent, at now: Date) -> [SessionEffect] {
        switch event {
        case .wake:
            handleWake(at: now)
        case .sleep:
            handleSleep(at: now)
        case .placeResolved(let place):
            handlePlaceResolved(place, at: now)
        case .tick(let idleSeconds):
            handleTick(idleSeconds: idleSeconds, at: now)
        case .endSessionRequested:
            handleEndSessionRequested(at: now)
        }
    }

    // MARK: - Olay işleyicileri

    /// İki yer birleştirildiğinde açık oturumun yer kimliğini taşır.
    ///
    /// `placeResolved` göndermek işe yaramaz: motor onu gerçek bir yer
    /// değişimi sayıp oturumu kapatır. Oysa kullanıcı hiçbir yere gitmedi,
    /// yalnızca iki kaydın aynı yer olduğunu söyledi.
    public mutating func reassignPlace(from source: UUID, to target: UUID) {
        guard source != target else { return }
        if currentSession?.placeID == source { currentSession?.placeID = target }
        if currentPlace == .known(source) { currentPlace = .known(target) }
    }

    private mutating func handleWake(at now: Date) -> [SessionEffect] {
        isAsleep = false
        isAway = false

        guard let sleptAt = sleepStartedAt else {
            // Uykudan değil, soğuk başlangıçtan geliyoruz.
            return currentSession == nil ? startSession(at: now) : []
        }
        sleepStartedAt = nil

        if now.timeIntervalSince(sleptAt) > configuration.gapThreshold {
            var effects = endSession(at: sleptAt)
            effects += startSession(at: now)
            return effects
        }

        // Kısa ara: oturum sürüyor, ama yerin değişmediğini henüz bilmiyoruz.
        pendingSleepStart = sleptAt
        return currentSession == nil ? startSession(at: now) : []
    }

    /// Oturumu kapatıp aynı yerde hemen yenisini açar.
    ///
    /// Takibi büsbütün durdurmuyoruz: otomatik bir takipçinin izlemeyi
    /// bırakması tuhaf olurdu. Amaç yanlış başlamış bir sayacı düzeltmek.
    private mutating func handleEndSessionRequested(at now: Date) -> [SessionEffect] {
        guard currentSession != nil else { return [] }
        var effects = endSession(at: now)
        effects += startSession(at: now)
        return effects
    }

    /// Art arda gelen uyku bildirimlerinde ilk an korunur: ara en erken
    /// başladığı yerden ölçülür.
    private mutating func handleSleep(at now: Date) -> [SessionEffect] {
        isAsleep = true
        if sleepStartedAt == nil { sleepStartedAt = now }
        pendingSleepStart = nil
        return []
    }

    private mutating func handlePlaceResolved(
        _ place: PlaceRef,
        at now: Date
    ) -> [SessionEffect] {
        // Yer değişimi uyku sırasında olduysa oturum uykuya dalma anında biter.
        let closeAt = pendingSleepStart ?? now
        pendingSleepStart = nil

        switch place {
        case .unknown:
            // Wi-Fi düştü ya da hiç yok. Oturum kapanmaz, yalnızca adı değişir.
            currentPlace = .unknown
            return currentSession == nil && !isAway ? startSession(at: now) : []

        case .known(let placeID):
            currentPlace = .known(placeID)
            // Kullanıcı yokken gelen ağ çözümü oturum açmaz; dönüşte açılır.
            guard !isAway else { return [] }

            guard var session = currentSession else {
                return startSession(at: now, placeID: placeID)
            }
            if session.placeID == nil || session.placeID == placeID {
                // "Bilinmeyen yer"de başlamıştı, Wi-Fi geç geldi: aynı oturum.
                session.placeID = placeID
                currentSession = session
                return []
            }
            var effects = endSession(at: closeAt)
            effects += startSession(at: now, placeID: placeID)
            return effects
        }
    }

    private mutating func handleTick(
        idleSeconds: TimeInterval,
        at now: Date
    ) -> [SessionEffect] {
        guard !isAsleep else { return [] }

        if isAway {
            guard idleSeconds < configuration.gapThreshold else { return [] }
            isAway = false
            return startSession(at: now.addingTimeInterval(-idleSeconds))
        }

        guard var session = currentSession else { return [] }

        // Uyanık ama dokunulmuyor: ekran kapalı, kilitli ya da kullanıcı
        // uzakta. Oturum son girdi anında kapanır, ara süreye yazılmaz.
        if idleSeconds > configuration.gapThreshold {
            isAway = true
            return endSession(at: now.addingTimeInterval(-idleSeconds))
        }

        // Saat sınırları duvar saatine bakar; uykudan sonra biriken sınırlar
        // ilk tick'te toplu olarak yakalanır.
        var effects: [SessionEffect] = []
        if let interval = configuration.notificationInterval, interval > 0 {
            let reached = Int(session.elapsed(at: now) / interval)
            if reached >= 1 {
                for mark in 1...reached where !session.notifiedMarks.contains(mark) {
                    session.notifiedMarks.insert(mark)
                    effects.append(
                        .markReached(
                            index: mark,
                            elapsed: TimeInterval(mark) * interval,
                            placeID: session.placeID
                        )
                    )
                }
            }
        }

        currentSession = session
        return effects
    }

    // MARK: - Oturum yaşam döngüsü

    private var knownCurrentPlaceID: UUID? {
        if case .known(let id) = currentPlace { return id }
        return nil
    }

    private mutating func startSession(at now: Date, placeID: UUID? = nil) -> [SessionEffect] {
        let session = Session(placeID: placeID ?? knownCurrentPlaceID, startedAt: now)
        currentSession = session
        return [.sessionStarted(session)]
    }

    private mutating func endSession(at time: Date) -> [SessionEffect] {
        guard var session = currentSession else { return [] }
        session.endedAt = max(session.startedAt, time)
        currentSession = nil
        return [.sessionEnded(session)]
    }
}
```

- [ ] **Step 7: Eski motor testlerini yeni kurala uyarla**

`Tests/PlaceTimerCoreTests/SessionEngineTests.swift` içinde:

1. Şu testleri tamamen sil (kalkan davranışları sınıyorlar): `"Uyku eşiği sıfırken oturum kapağın kapandığı anda biter"`, `"Ekran kilitliyken aktif sayaç durur, yerde geçen süre akar"`, `"5 dakikalık hareketsizlik aktif sayacı durdurur, girdi gelince sürer"`, `"Kaçan tick'ler aktif süreyi şişirmez"`, `"Uykudayken gelen tick'ler yok sayılır"` (yerini `GapRuleTests.ticksWhileAsleepAreIgnored` aldı).
2. `"45 dakikalık uyku oturumu bozmaz"` testini şununla değiştir:

```swift
    @Test("20 dakikalık uyku oturumu bozmaz")
    func shortSleepKeepsSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))
        let started = engine.currentSession?.id

        engine.handle(.sleep, at: at(30))
        let effects = engine.handle(.wake, at: at(50))
        engine.handle(.placeResolved(.known(kafe)), at: at(50))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == started)
        // Yerde geçen süre uyku aralığını içerir.
        #expect(engine.elapsed(at: at(50)) == 50 * 60)
    }
```

3. `"Açık oturum ve sayaçlar korunur"` testinde `EngineConfiguration(idleThreshold: 120)` → `EngineConfiguration(gapThreshold: 3600)`; `activeSeconds` içeren `let aktif = …` ve `#expect(motor.activeSeconds == aktif)` satırlarını sil; `#expect(motor.configuration.idleThreshold == 120)` → `#expect(motor.configuration.gapThreshold == 3600)`.
4. `"Uyku boyunca biriken saat sınırları uyanışta toplu düşer"` testinde uyku artık eşiği aşmamalı: `engine.handle(.wake, at: at(55))` ve `engine.handle(.placeResolved(.known(kafe)), at: at(55))` satırlarındaki `55` → `35`; yorumu `// 25 dk: oturum sürüyor` yap. Beklenti (70. dakikada 1. saat işareti) aynen kalır.
5. Silinen testlerden sonra `advance` yardımcısını kullanan test kalmadıysa yardımcıyı da sil (kullanılmayan `private` fonksiyon uyarısı vermesin).

- [ ] **Step 8: Kit'i derlenir hâle getir**

`Sources/PlaceTimerKit/PowerMonitor.swift`: `onScreenLocked`, `onScreenUnlocked` özelliklerini; `screensDidSleepNotification`, `screensDidWakeNotification` ve iki `DistributedNotificationCenter` gözlemini sil. Tip yorumunu şöyle güncelle:

```swift
/// Sistem uykusu ve uyanmayı dinler.
///
/// Ekranın kararması ve kilit bilinçli olarak dinlenmiyor: ikisi de uyanık bir
/// Mac'te `IdleReader`'ın süresini büyütür ve motorun ara kuralına oradan
/// girer. Uyku sayılsalardı agent'ı bekleyen kullanıcının oturumu bölünürdü.
```

`Sources/PlaceTimerKit/AppCoordinator.swift`:
- `power.onScreenLocked = …` ve `power.onScreenUnlocked = …` satırlarını sil.
- `public private(set) var activeSeconds: TimeInterval = 0` ve `refreshDisplay` içindeki `activeSeconds = engine.activeSeconds` satırını sil.

`Sources/PlaceTimerKit/UI/Settings/ThresholdOption.swift`: `sleep` ve `idle` dizilerini sil, yerine:

```swift
    static let gap: [ThresholdOption] = Preferences.gapOptions.map { seconds in
        let minutes = Int(seconds / 60)
        let title = minutes < 60 ? "\(minutes) dakika" : "\(minutes / 60) saat"
        return ThresholdOption(title: title, seconds: seconds)
    }
```

Dosyanın başına `import PlaceTimerCore` ekle.

`Sources/PlaceTimerKit/UI/Settings/GeneralSettingsView.swift`: "Oturum" bölümündeki iki `Picker`'ı tek pickerla değiştir ve `sessionFooter`'ı sadeleştir:

```swift
            Section {
                Picker("Ara eşiği", selection: $draft.gapThreshold) {
                    ForEach(ThresholdOption.gap) { Text($0.title).tag($0.seconds) }
                }
            } header: {
                Text("Oturum")
            } footer: {
                Text(
                    "Bilgisayardan bu süreden uzun uzak kalırsan oturum, ayrıldığın "
                        + "anda biter. Daha kısa aralar — mutfak, agent'ı beklemek, "
                        + "Wi-Fi kopması — oturumu bozmaz."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
```

`sessionFooter` özelliğini sil.

`Sources/PlaceTimerKit/UI/PanelSummaryView.swift`: `LabeledContent("Aktif", …)` bloğunu sil.

- [ ] **Step 9: Testleri çalıştır**

Run: `swift build && swift test`
Expected: PASS, uyarı yok.

- [ ] **Step 10: Commit**

```bash
git add -A Sources Tests
git commit -m "feat: tek ara esigi; ekran kararmasi ve hareketsizlik ayni kurala bagli

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Yer kararlılığı ve kullanıcının seçtiği yer

**Files:**
- Modify: `Sources/PlaceTimerCore/Models.swift` (`SessionEvent`)
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift`
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`
- Modify: `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`
- Create: `Tests/PlaceTimerCoreTests/PlaceStabilityTests.swift`

**Interfaces:**
- Consumes: Task 1'in `EngineConfiguration.placeChangeStability`, `startSession(at:placeID:) -> [SessionEffect]`.
- Produces: `SessionEvent.placeChosen(UUID)`; motorda `private mutating func commitPlaceChange(to:closingAt:startingAt:) -> [SessionEffect]` ve `handlePlaceResolved(_:immediate:at:)` (Task 3 bu fonksiyona tek koşul ekler).

- [ ] **Step 1: Kararlılık testlerini yaz**

Create `Tests/PlaceTimerCoreTests/PlaceStabilityTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func startedAtHome() -> SessionEngine {
    var engine = SessionEngine()
    engine.handle(.wake, at: at(0))
    engine.handle(.placeResolved(.known(ev)), at: at(0))
    return engine
}

@Suite("Yer kararlılığı")
struct PlaceStabilityTests {

    @Test("Başka ağ 3 dakikadan kısa sürerse oturum bölünmez")
    func briefFlipDoesNotSplit() {
        var engine = startedAtHome()
        let id = engine.currentSession?.id

        var effects: [SessionEffect] = []
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(10))
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(12))
        effects += engine.handle(.placeResolved(.known(ev)), at: at(12.5))
        // Sayaç sıfırlandı: kafe yeniden görülünce bekleme baştan başlar.
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(13))
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(15.9))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.currentSession?.placeID == ev)
    }

    @Test("Yeni yer 3 dakika sürerse oturum ilk gözlem anında bölünür")
    func stableChangeSplitsAtFirstSighting() {
        var engine = startedAtHome()

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.known(kafe)), at: at(11))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(13))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.placeID == ev)
        #expect(ended.endedAt == at(10))
        #expect(started.placeID == kafe)
        #expect(started.startedAt == at(10))
    }

    @Test("Wi-Fi yokluğu kararlılık sayacını sıfırlamaz")
    func unknownDoesNotResetPending() {
        var engine = startedAtHome()

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.unknown), at: at(11))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(13))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
    }

    @Test("Kullanıcının seçtiği yer beklemeden geçerli olur")
    func chosenPlaceAppliesImmediately() {
        var engine = startedAtHome()

        let effects = engine.handle(.placeChosen(kafe), at: at(10))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
        #expect(started.placeID == kafe)
    }

    @Test("Kısa uykudan sonra yer değiştiyse beklemeden uykuya dalma anında bölünür")
    func changeAfterShortSleepSplitsAtSleep() {
        var engine = startedAtHome()

        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(20))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(20.1))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
        #expect(started.startedAt == at(20.1))
    }

    @Test("Kullanıcı yokken gelen ağ çözümü oturum açmaz")
    func resolutionWhileAwayDoesNotStart() {
        var engine = startedAtHome()
        engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))
        #expect(engine.currentSession == nil)

        var effects = engine.handle(.placeResolved(.unknown), at: at(41))
        effects += engine.handle(.placeResolved(.known(ev)), at: at(42))

        #expect(effects.isEmpty)
        #expect(engine.currentSession == nil)
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `swift test --filter PlaceStabilityTests`
Expected: FAIL — `placeChosen` yok; mevcut motor anında bölüyor.

- [ ] **Step 3: Olayı ekle**

`Sources/PlaceTimerCore/Models.swift` içinde `SessionEvent`'e `case placeResolved(PlaceRef)` satırının altına ekle:

```swift
    /// Kullanıcı yeri kendisi seçti (panelden, yeni yer sorusundan).
    /// Otomatik çözümden farkı: kararlılık süresi beklenmez.
    case placeChosen(UUID)
```

- [ ] **Step 4: Motoru güncelle**

`Sources/PlaceTimerCore/SessionEngine.swift` içinde:

`isAway` özelliğinin altına ekle:

```swift
    /// Kararlılık süresi dolmamış bir yer değişimi adayı.
    private struct PendingPlace: Sendable {
        let placeID: UUID
        let firstSeenAt: Date
    }

    private var pendingPlace: PendingPlace?
```

`handle(_:at:)` içindeki `case .placeResolved` satırını şu iki satırla değiştir:

```swift
        case .placeResolved(let place):
            handlePlaceResolved(place, immediate: false, at: now)
        case .placeChosen(let placeID):
            handlePlaceResolved(.known(placeID), immediate: true, at: now)
```

`handlePlaceResolved(_:at:)` fonksiyonunun tamamını şununla değiştir ve hemen altına `commitPlaceChange` ekle:

```swift
    private mutating func handlePlaceResolved(
        _ place: PlaceRef,
        immediate: Bool,
        at now: Date
    ) -> [SessionEffect] {
        // Uykudan yeni uyanıldı: yer değiştiyse oturum uykuya dalma anında biter.
        let closeAtSleep = pendingSleepStart
        pendingSleepStart = nil

        switch place {
        case .unknown:
            // Wi-Fi düştü ya da hiç yok. Oturum kapanmaz, yalnızca adı değişir;
            // kararlılık adayı da korunur — bilinmeyen an iki yere de yazılmaz.
            currentPlace = .unknown
            return currentSession == nil && !isAway ? startSession(at: now) : []

        case .known(let placeID):
            // Kullanıcı yokken gelen ağ çözümü oturum açmaz; dönüşte açılır.
            guard !isAway else {
                currentPlace = .known(placeID)
                return []
            }
            guard var session = currentSession else {
                pendingPlace = nil
                currentPlace = .known(placeID)
                return startSession(at: now, placeID: placeID)
            }
            if session.placeID == nil || session.placeID == placeID {
                // "Bilinmeyen yer"de başlamıştı, Wi-Fi geç geldi: aynı oturum.
                session.placeID = placeID
                currentSession = session
                currentPlace = .known(placeID)
                pendingPlace = nil
                return []
            }
            if let sleptAt = closeAtSleep {
                return commitPlaceChange(to: placeID, closingAt: sleptAt, startingAt: now)
            }
            if immediate {
                return commitPlaceChange(to: placeID, closingAt: now, startingAt: now)
            }

            let firstSeen: Date
            if let pending = pendingPlace, pending.placeID == placeID {
                firstSeen = pending.firstSeenAt
            } else {
                firstSeen = now
                pendingPlace = PendingPlace(placeID: placeID, firstSeenAt: now)
            }
            guard now.timeIntervalSince(firstSeen) >= configuration.placeChangeStability else {
                return []
            }
            // Yeni yerdeki ilk dakikalar kaybolmasın: bölünme ilk gözlem anında.
            return commitPlaceChange(to: placeID, closingAt: firstSeen, startingAt: firstSeen)
        }
    }

    private mutating func commitPlaceChange(
        to placeID: UUID,
        closingAt closeTime: Date,
        startingAt startTime: Date
    ) -> [SessionEffect] {
        pendingPlace = nil
        currentPlace = .known(placeID)
        var effects = endSession(at: closeTime)
        effects += startSession(at: startTime, placeID: placeID)
        return effects
    }
```

`handleSleep` içine `pendingPlace = nil` ekle (uyku adayı geçersiz kılar).

- [ ] **Step 5: Eski "anında bölünme" testini uyarla**

`Tests/PlaceTimerCoreTests/SessionEngineTests.swift` içinde iki test uyanıkken anında bölünme bekliyor; ikisinde de motoru `SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))` ile kur:
- `"Uyanıkken yer değişimi oturumu o an kapatır"` → adını `"Kararlılık süresi sıfırken uyanıkken yer değişimi oturumu o an kapatır"` yap.
- `"Yeni oturum saat sınırlarını sıfırdan sayar"` (90. dakikada ev → kafe) → yalnızca yapılandırma değişir.

Ardından `swift test --filter SessionEngineTests` çalıştır; anında bölünme bekleyen başka bir test kırılırsa ona da aynı yapılandırmayı uygula.

- [ ] **Step 6: Koordinatörde kullanıcı seçimlerini `.placeChosen`'a taşı**

`Sources/PlaceTimerKit/AppCoordinator.swift` içinde `createPlace(named:)`, `mergeIntoPlace(_:)` ve `overrideCurrentPlace(_:)` fonksiyonlarındaki `apply(.placeResolved(.known(…)))` çağrılarını `apply(.placeChosen(…))` yap (üç yer). `checkNetwork` içindeki `manualSelection` dalı otomatik yoklama olduğu için `.placeResolved` olarak kalır.

- [ ] **Step 7: Testleri çalıştır**

Run: `swift build && swift test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A Sources Tests
git commit -m "feat: yer degisimi 3 dakika kararlilik bekliyor; elle secim beklemiyor

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Aynı yere dönüşte oturum geri açılır

Kullanıcının en sık şikâyeti: Wi-Fi kopup aynı ağa dönülünce eski oturumun kaybolması. Motor son kapanan iki oturumu tutar; aynı yere eşik içinde dönülürse eskisini geri açar. Araya giren kısa ve bitişik başka-yer oturumu da ona katılır.

**Files:**
- Modify: `Sources/PlaceTimerCore/Models.swift` (`SessionEffect`)
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift`
- Modify: `Sources/PlaceTimerCore/Storage/AppState.swift`
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`
- Create: `Tests/PlaceTimerCoreTests/ResumeTests.swift`
- Modify: `docs/superpowers/specs/2026-10-07-place-timer-v3-design.md` (§3.3)

**Interfaces:**
- Consumes: Task 2'nin `handlePlaceResolved(_:immediate:at:)`, `commitPlaceChange`.
- Produces: `SessionEffect.sessionResumed(Session, replacing: [UUID])`; `SessionEngine.recentlyEnded: [Session]` (public private(set)); `SessionEngine.init(configuration:restoring:recentlyEnded:)`; `mutating func forgetRecent()`; `AppState.recentlyEnded: [Session]`; `AppState.init(currentSession:lastHeartbeatAt:recentlyEnded:)`.

- [ ] **Step 1: Geri açma testlerini yaz**

Create `Tests/PlaceTimerCoreTests/ResumeTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func closedAtHome(until end: Double) -> Session {
    Session(placeID: ev, startedAt: at(0), endedAt: at(end))
}

private func resumed(_ effects: [SessionEffect]) -> (Session, [UUID])? {
    for effect in effects {
        if case .sessionResumed(let session, let replacing) = effect {
            return (session, replacing)
        }
    }
    return nil
}

@Suite("Oturumun geri açılması")
struct ResumeTests {

    @Test("Aynı yere eşik içinde dönülünce eski oturum geri açılır")
    func resumesWithinThreshold() {
        let eski = closedAtHome(until: 20)
        var engine = SessionEngine(recentlyEnded: [eski])

        let effects = engine.handle(.wake, at: at(25))

        guard let (session, replacing) = resumed(effects) else {
            Issue.record("geri açılmadı: \(effects)")
            return
        }
        #expect(session.id == eski.id)
        #expect(session.endedAt == nil)
        #expect(replacing == [eski.id])
        #expect(engine.currentSession?.id == eski.id)
        #expect(engine.elapsed(at: at(25)) == 25 * 60)
    }

    @Test("Eşikten sonra dönülürse yeni oturum açılır")
    func newSessionAfterThreshold() {
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        let effects = engine.handle(.wake, at: at(60))
        guard case .sessionStarted = effects.first else {
            Issue.record("yeni oturum yok: \(effects)")
            return
        }
    }

    @Test("Kısa bir başka ağ eski oturuma katılır")
    func briefDetourIsAbsorbed() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        let evID = engine.currentSession!.id

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        let kafeID = engine.currentSession!.id
        let effects = engine.handle(.placeResolved(.known(ev)), at: at(15))

        guard let (session, replacing) = resumed(effects) else {
            Issue.record("geri açılmadı: \(effects)")
            return
        }
        #expect(session.id == evID)
        #expect(Set(replacing) == [evID, kafeID])
        #expect(engine.elapsed(at: at(15)) == 15 * 60)
    }

    @Test("Önceki yere dönüş kararlılık süresi beklemez")
    func returnSkipsStability() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.known(kafe)), at: at(13))  // kafe onaylandı

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(14))

        #expect(resumed(effects) != nil)
        #expect(engine.currentSession?.placeID == ev)
    }

    @Test("Uykuyla ayrılan bir ziyaret katılmaz")
    func detourAcrossSleepIsKept() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(20))
        engine.handle(.placeResolved(.known(kafe)), at: at(20))  // ev 10'da kapandı

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(26))

        #expect(resumed(effects) == nil)
        guard case .sessionStarted = effects.last else {
            Issue.record("yeni oturum yok: \(effects)")
            return
        }
    }

    @Test("Eşikten uzun süren başka yer katılmaz")
    func longDetourIsKept() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(10))

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(45))

        #expect(resumed(effects) == nil)
    }

    @Test("Elle bitirilen oturum geri açılmaz")
    func manualEndIsFinal() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))

        let effects = engine.handle(.endSessionRequested, at: at(10))

        #expect(resumed(effects) == nil)
        #expect(engine.recentlyEnded.isEmpty)
    }

    @Test("Unutulan oturumlar geri açılmaz")
    func forgottenSessionsStayClosed() {
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        engine.forgetRecent()
        let effects = engine.handle(.wake, at: at(25))
        #expect(resumed(effects) == nil)
    }

    @Test("Yeniden başlatmada son kapanan oturumlar korunur")
    func restartKeepsRecentlyEnded() {
        let eski = closedAtHome(until: 20)
        let state = AppState(currentSession: nil, lastHeartbeatAt: at(20), recentlyEnded: [eski])

        let restored = SessionEngine.restored(from: state, now: at(22))

        #expect(resumed(restored.effects)?.0.id == eski.id)
    }

    @Test("1.0'ın durum dosyası okunur")
    func legacyStateDecodes() throws {
        let json = Data(#"{"lastHeartbeatAt": 0}"#.utf8)
        let state = try JSONDecoder().decode(AppState.self, from: json)
        #expect(state.recentlyEnded.isEmpty)
        #expect(state.currentSession == nil)
    }

    @Test("Birleştirilen yer son kapanan oturumlara da yansır")
    func reassignUpdatesRecentlyEnded() {
        let hedef = UUID()
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        engine.reassignPlace(from: ev, to: hedef)
        #expect(engine.recentlyEnded.first?.placeID == hedef)
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `swift test --filter ResumeTests`
Expected: FAIL — `recentlyEnded`, `sessionResumed` yok.

- [ ] **Step 3: Etkiyi ekle**

`Sources/PlaceTimerCore/Models.swift` içinde `SessionEffect`'e `case sessionEnded(Session)` satırının altına ekle:

```swift
    /// Kapanmış bir oturum geri açıldı. `replacing`, geçmişten çıkarılması
    /// gereken oturum kimlikleri: geri açılanın kendisi ve ona katılan kısa
    /// ara oturum.
    case sessionResumed(Session, replacing: [UUID])
```

- [ ] **Step 4: Motora geri açmayı ekle**

`Sources/PlaceTimerCore/SessionEngine.swift` içinde:

`currentSession`'ın altına ekle:

```swift
    /// Son kapanan en fazla iki oturum, eskisi başta. Aynı yere eşik içinde
    /// dönüldüğünde geri açmanın dayanağı; uygulama yeniden başlasa da
    /// çalışsın diye `AppState`'e yazılır.
    public private(set) var recentlyEnded: [Session]
```

`init`'i şununla değiştir:

```swift
    /// - Parameters:
    ///   - restoring: Diskten okunan açık oturum. Uygulama çökse veya
    ///     güncellense bile oturum kaldığı yerden devam eder.
    ///   - recentlyEnded: Diskten okunan son kapanan oturumlar.
    public init(
        configuration: EngineConfiguration = EngineConfiguration(),
        restoring session: Session? = nil,
        recentlyEnded: [Session] = []
    ) {
        self.configuration = configuration
        self.currentSession = session
        self.recentlyEnded = recentlyEnded
        self.currentPlace = session?.placeID.map { PlaceRef.known($0) } ?? .unknown
        self.isAsleep = false
    }
```

`reassignPlace` içine, son satırın altına:

```swift
        for index in recentlyEnded.indices where recentlyEnded[index].placeID == source {
            recentlyEnded[index].placeID = target
        }
```

`reassignPlace`'in altına ekle:

```swift
    /// Geçmiş elle değiştirildi (silme, birleştirme, düzenleme): motorun
    /// elindeki kopyalar artık güvenilir değil. Silinmiş bir oturumun aynı yere
    /// dönüşte hortlamaması için unutulur.
    public mutating func forgetRecent() {
        recentlyEnded.removeAll()
    }
```

`handleEndSessionRequested`'ı şununla değiştir:

```swift
    private mutating func handleEndSessionRequested(at now: Date) -> [SessionEffect] {
        guard currentSession != nil else { return [] }
        var effects = endSession(at: now)
        // Kullanıcı açıkça bitirdi: bu oturum geri açılmamalı.
        recentlyEnded.removeAll()
        effects += startSession(at: now)
        return effects
    }
```

`handlePlaceResolved` içinde `if immediate {` satırını şununla değiştir:

```swift
            if immediate || isReturnToPrevious(placeID, at: now) {
```

"Oturum yaşam döngüsü" bölümündeki `startSession` ve `endSession`'ı şunlarla değiştir; altına yardımcıları ekle:

```swift
    private mutating func startSession(at now: Date, placeID: UUID? = nil) -> [SessionEffect] {
        let resolved = placeID ?? knownCurrentPlaceID

        if let match = resumable(placeID: resolved, at: now) {
            var session = match.session
            session.endedAt = nil
            if session.placeID == nil { session.placeID = resolved }
            currentSession = session
            recentlyEnded.removeAll { match.replacing.contains($0.id) }
            return [.sessionResumed(session, replacing: match.replacing)]
        }

        let session = Session(placeID: resolved, startedAt: now)
        currentSession = session
        return [.sessionStarted(session)]
    }

    private mutating func endSession(at time: Date) -> [SessionEffect] {
        guard var session = currentSession else { return [] }
        session.endedAt = max(session.startedAt, time)
        currentSession = nil
        recentlyEnded.append(session)
        if recentlyEnded.count > 2 {
            recentlyEnded.removeFirst(recentlyEnded.count - 2)
        }
        return [.sessionEnded(session)]
    }

    private struct ResumeMatch {
        let session: Session
        let replacing: [UUID]
    }

    /// Yeni açılacak oturumun yerine geri açılabilecek kapanmış oturum.
    ///
    /// İki durum var:
    /// - Son kapanan oturum aynı yerde ve eşik içinde kapandı → o geri açılır.
    /// - Son kapanan oturum kısa bir başka-yer oturumuydu, ondan öncekinin
    ///   hemen ardından başladı (arada uyku yok) ve öncekisi aynı yerde → ikisi
    ///   tek oturum olur. Bant ya da hotspot'a kısa süre takılmak böyle görünür;
    ///   kafeye gidip dönmek ise arada bir uyku bırakır ve katılmaz.
    private func resumable(placeID: UUID?, at now: Date) -> ResumeMatch? {
        guard
            let last = recentlyEnded.last,
            let lastEnd = last.endedAt,
            now.timeIntervalSince(lastEnd) < configuration.gapThreshold
        else { return nil }

        if Self.samePlace(last.placeID, placeID) {
            return ResumeMatch(session: last, replacing: [last.id])
        }

        guard recentlyEnded.count >= 2 else { return nil }
        let previous = recentlyEnded[recentlyEnded.count - 2]
        guard
            let previousEnd = previous.endedAt,
            Self.samePlace(previous.placeID, placeID),
            last.startedAt == previousEnd,
            last.elapsed(at: now) < configuration.gapThreshold
        else { return nil }
        return ResumeMatch(session: previous, replacing: [previous.id, last.id])
    }

    /// Açık oturum, son kapanan oturumun bitişiyle başladıysa, kısaysa ve
    /// kullanıcı o oturumun yerine döndüyse: dönüş kararlılık beklemez.
    private func isReturnToPrevious(_ placeID: UUID, at now: Date) -> Bool {
        guard
            let current = currentSession,
            let previous = recentlyEnded.last,
            previous.placeID == placeID,
            previous.endedAt == current.startedAt
        else { return false }
        return current.elapsed(at: now) < configuration.gapThreshold
    }

    /// Bilinmeyen yer, her iki yere de uyar: "Bilinmeyen yer"de başlayıp
    /// Wi-Fi geç gelen oturum aynı oturumdur.
    private static func samePlace(_ a: UUID?, _ b: UUID?) -> Bool {
        a == nil || b == nil || a == b
    }
```

- [ ] **Step 5: `AppState`'i genişlet**

`Sources/PlaceTimerCore/Storage/AppState.swift` içinde `AppState` yapısını şununla değiştir ve `restored(...)` içindeki motor kurulumunu güncelle:

```swift
public struct AppState: Codable, Sendable, Equatable {
    public var currentSession: Session?
    public var lastHeartbeatAt: Date?
    /// Motorun son kapanan oturumları; aynı yere dönüşte geri açma için.
    public var recentlyEnded: [Session]

    public init(
        currentSession: Session? = nil,
        lastHeartbeatAt: Date? = nil,
        recentlyEnded: [Session] = []
    ) {
        self.currentSession = currentSession
        self.lastHeartbeatAt = lastHeartbeatAt
        self.recentlyEnded = recentlyEnded
    }

    /// 1.0'ın dosyasında `recentlyEnded` yok.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            currentSession: try container.decodeIfPresent(Session.self, forKey: .currentSession),
            lastHeartbeatAt: try container.decodeIfPresent(Date.self, forKey: .lastHeartbeatAt),
            recentlyEnded: try container.decodeIfPresent([Session].self, forKey: .recentlyEnded)
                ?? []
        )
    }
}
```

`restored(from:configuration:now:)` içinde:

```swift
        var engine = SessionEngine(
            configuration: configuration,
            restoring: state.currentSession,
            recentlyEnded: state.recentlyEnded
        )
```

- [ ] **Step 6: Koordinatörü bağla**

`Sources/PlaceTimerKit/AppCoordinator.swift` içinde:

`handle(effects:)` içine yeni dal:

```swift
            case .sessionResumed(_, let replacing):
                history.removeAll { replacing.contains($0.id) }
                persistHistory()
                persistState(at: Date())
```

`persistState(at:)`:

```swift
    private func persistState(at now: Date) {
        try? stateStore.save(
            AppState(
                currentSession: engine.currentSession,
                lastHeartbeatAt: now,
                recentlyEnded: engine.recentlyEnded
            )
        )
    }
```

`deleteSession(_:)` içinde `history = SessionHistory.remove(...)` satırının altına `engine.forgetRecent()` ekle.

- [ ] **Step 7: Spec'i uygulamaya uydur**

`docs/superpowers/specs/2026-10-07-place-timer-v3-design.md` §8'deki `state.json` satırını "`state.json`: yeni isteğe bağlı `recentlyEnded: [Session]`." yap; §9 tablosunda `SessionEngine` satırındaki `lastEnded` → `recentlyEnded`. §3.3 "Uygulama:" paragrafını şununla değiştir:

```markdown
Uygulama: motor son kapanan **iki** oturumu `recentlyEnded` olarak tutar ve
`AppState`'e yazar (yeniden başlatmada da çalışsın). Son kapanan oturum aynı
yerdeyse o geri açılır. Son kapanan, ondan öncekinin hemen ardından başlamış
(arada uyku yok), ara eşiğinden kısa bir başka-yer oturumuysa ve öncekisi aynı
yerdeyse ikisi tek oturum olur — kısa süre başka bir ağa takılmak böyle
görünür; kafeye gidip dönmek arada uyku bıraktığı için katılmaz. Önceki yere
dönüş kararlılık süresini beklemez. Geri açma `.sessionResumed(Session,
replacing:)` etkisi üretir; koordinatör `replacing` kimliklerini geçmişten
çıkarır. Geçmiş elle değiştiğinde (silme, birleştirme, düzenleme) motor bu
listeyi unutur (`forgetRecent`).
```

- [ ] **Step 8: Testleri çalıştır**

Run: `swift build && swift test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A Sources Tests docs/superpowers/specs
git commit -m "feat: ayni yere esik icinde donuste oturum geri aciliyor

Wi-Fi kopup ayni aga donuldugunde ya da kisa sure baska bir aga takilindiginda
eski oturum kaldigi yerden devam ediyor, yeni kayit acilmiyor.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: İstatistik çekirdeği — dönem, kırpma, toplamlar, CSV

**Files:**
- Modify: `Sources/PlaceTimerCore/Statistics.swift` (tamamı)
- Modify: `Tests/PlaceTimerCoreTests/StatisticsTests.swift` (tamamı), `Tests/PlaceTimerCoreTests/HistoryTests.swift` (`SessionsInRangeTests`)
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`, `Sources/PlaceTimerKit/UI/Formatters.swift`, `Sources/PlaceTimerKit/UI/DayStripView.swift`, `Sources/PlaceTimerKit/UI/PanelSummaryView.swift`, `Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift` (geçici uyarlama)

**Interfaces:**
- Produces (Core):
  - `extension Calendar { static var placeTimer: Calendar }`
  - `struct PlaceTotal { placeID: UUID?; totalSeconds: TimeInterval; sessionCount: Int; id: String }`
  - `enum StatsScope: String, CaseIterable { case day, week, month; var displayName: String }`
  - `struct StatsPeriod: Hashable { scope; interval: DateInterval; static func containing(_:scope:calendar:) -> StatsPeriod; func shifted(by:calendar:) -> StatsPeriod; func contains(_:) -> Bool; func title(now:calendar:) -> String }`
  - `func overlap(of: Session, with: DateInterval, now: Date) -> TimeInterval`
  - `func totalSeconds(from: [Session], in: DateInterval, now: Date) -> TimeInterval`
  - `func placeTotals(from: [Session], in: StatsPeriod, now: Date) -> [PlaceTotal]`
  - `func previousComparableTotal(from: [Session], for: StatsPeriod, now: Date, calendar:) -> TimeInterval`
  - `struct PlaceShare: Identifiable { placeID: UUID?; seconds: TimeInterval; id: String }`
  - `struct DayTotal: Identifiable { day: Date; shares: [PlaceShare]; total: TimeInterval }`
  - `func dailyTotals(from: [Session], in: StatsPeriod, now: Date, calendar:) -> [DayTotal]`
  - `struct SessionDay: Identifiable { day: Date; sessions: [Session]; total: TimeInterval; placeCount: Int }`
  - `func sessionDays(from: [Session], in: StatsPeriod, now: Date, calendar:) -> [SessionDay]`
  - `func sessionsOverlapping(_: [Session], interval: DateInterval, now: Date) -> [Session]`
  - `func daySegments(from: [Session], on: Date, now: Date, calendar:) -> [DaySegment]`
  - `func sessionsCSV(_: [Session], in: StatsPeriod, now: Date, timeZone: TimeZone, placeName: (UUID?) -> String) -> String`
- Produces (Kit): `DurationFormat.time(_ date: Date) -> String`; koordinatörde `totals(in:)`, `totalSeconds(in:)`, `previousTotalSeconds(for:)`, `dailyTotals(in:)`, `sessionDays(in:)`, `segments(on:)`, `csv(in:)`, `todayTotalSeconds`, `placesTodayCount`.

- [ ] **Step 1: Yeni istatistik testlerini yaz**

`Tests/PlaceTimerCoreTests/StatisticsTests.swift` dosyasının tamamını şununla değiştir:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()

/// Testlerin makinenin bölgesel ayarlarından etkilenmemesi için sabit takvim.
private var takvim: Calendar {
    var calendar = Calendar.placeTimer
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}

private func gun(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
    takvim.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func oturum(_ placeID: UUID?, from start: Date, to end: Date?) -> Session {
    Session(placeID: placeID, startedAt: start, endedAt: end)
}

private func hafta(_ date: Date) -> StatsPeriod {
    .containing(date, scope: .week, calendar: takvim)
}

@Suite("İstatistik dönemi")
struct StatsPeriodTests {

    @Test("Hafta pazartesi başlar, sistem bölgesinden bağımsız")
    func weekStartsMonday() {
        // 20 Eylül 2026 pazar; hafta 14 Eylül pazartesi başlamalı.
        let period = hafta(gun(20, 12))
        #expect(period.interval.start == gun(14, 0))
        #expect(period.interval.end == gun(21, 0))
    }

    @Test("Varsayılan takvim de pazartesi başlar")
    func defaultCalendarStartsMonday() {
        #expect(Calendar.placeTimer.firstWeekday == 2)
    }

    @Test("Önceki ve sonraki dönem")
    func shifting() {
        let period = hafta(gun(16, 12))
        #expect(period.shifted(by: -1, calendar: takvim) == hafta(gun(9, 12)))
        #expect(period.shifted(by: 1, calendar: takvim) == hafta(gun(23, 12)))
    }

    @Test("Başlıklar bugüne göre adlandırılır")
    func titles() {
        let simdi = gun(16, 12)
        let gunDonemi = StatsPeriod.containing(simdi, scope: .day, calendar: takvim)
        #expect(gunDonemi.title(now: simdi, calendar: takvim) == "Bugün")
        #expect(gunDonemi.shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Dün")
        #expect(hafta(simdi).title(now: simdi, calendar: takvim) == "Bu hafta")
        #expect(hafta(simdi).shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Geçen hafta")
        let ay = StatsPeriod.containing(simdi, scope: .month, calendar: takvim)
        #expect(ay.title(now: simdi, calendar: takvim) == "Bu ay")
        #expect(ay.shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Geçen ay")
        #expect(ay.shifted(by: -2, calendar: takvim).title(now: simdi, calendar: takvim).contains("Temmuz"))
    }
}

@Suite("Kırpma ve toplamlar")
struct TotalsTests {

    @Test("Geceyi aşan oturum iki güne bölünür")
    func midnightSplit() {
        let gece = [oturum(ev, from: gun(16, 23), to: gun(17, 1))]
        let gunler = dailyTotals(from: gece, in: hafta(gun(16, 12)), now: gun(18, 12), calendar: takvim)

        #expect(gunler.first { $0.day == gun(16, 0) }?.total == 3600)
        #expect(gunler.first { $0.day == gun(17, 0) }?.total == 3600)

        let carsamba = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        #expect(placeTotals(from: gece, in: carsamba, now: gun(18, 12)).first?.totalSeconds == 3600)
    }

    @Test("Hafta sınırını aşan oturum iki haftaya bölünür")
    func weekBoundarySplit() {
        let gece = [oturum(ev, from: gun(20, 23), to: gun(21, 2))]
        let simdi = gun(22, 12)
        #expect(totalSeconds(from: gece, in: hafta(gun(20, 12)).interval, now: simdi) == 3600)
        #expect(totalSeconds(from: gece, in: hafta(gun(21, 12)).interval, now: simdi) == 2 * 3600)
    }

    @Test("Açık oturum şu ana kadar sayılır")
    func openSessionCountsUntilNow() {
        let acik = [oturum(ev, from: gun(16, 9), to: nil)]
        let bugun = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        #expect(placeTotals(from: acik, in: bugun, now: gun(16, 12)).first?.totalSeconds == 3 * 3600)
    }

    @Test("Yerler toplam süreye göre azalan sıralanır, oturum sayısı tutulur")
    func placeTotalsSorted() {
        let oturumlar = [
            oturum(ev, from: gun(16, 9), to: gun(16, 10)),
            oturum(kafe, from: gun(16, 11), to: gun(16, 14)),
            oturum(ev, from: gun(16, 15), to: gun(16, 16)),
        ]
        let bugun = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        let toplamlar = placeTotals(from: oturumlar, in: bugun, now: gun(16, 20))
        #expect(toplamlar.map(\.placeID) == [kafe, ev])
        #expect(toplamlar.last?.sessionCount == 2)
    }

    @Test("Karşılaştırma önceki dönemin aynı anına kadar yapılır")
    func comparisonUsesSamePortion() {
        let oturumlar = [
            oturum(ev, from: gun(7, 9), to: gun(7, 11)),    // geçen pzt 2sa
            oturum(ev, from: gun(11, 9), to: gun(11, 12)),  // geçen cuma 3sa
        ]
        // Bu hafta çarşamba öğlen: geçen haftanın çarşamba öğlenine kadarı.
        let simdi = gun(16, 12)
        #expect(previousComparableTotal(from: oturumlar, for: hafta(simdi), now: simdi, calendar: takvim) == 2 * 3600)
    }

    @Test("Bitmiş dönem önceki dönemin tamamıyla karşılaştırılır")
    func finishedPeriodComparesWhole() {
        let oturumlar = [
            oturum(ev, from: gun(7, 9), to: gun(7, 11)),    // 7–13 Eyl haftası: 2sa
            oturum(ev, from: gun(11, 9), to: gun(11, 12)),  // aynı hafta: 3sa
        ]
        // 14–20 Eyl haftası bitmiş (şimdi 28 Eyl); öncesi bütünüyle 5sa.
        let bitmis = hafta(gun(16, 12))
        #expect(previousComparableTotal(from: oturumlar, for: bitmis, now: gun(28, 12), calendar: takvim) == 5 * 3600)
    }

    @Test("Gün listesi en yeni gün başta, boş gün yok")
    func sessionDaysNewestFirst() {
        let oturumlar = [
            oturum(ev, from: gun(14, 9), to: gun(14, 10)),
            oturum(kafe, from: gun(16, 9), to: gun(16, 10)),
            oturum(ev, from: gun(16, 11), to: gun(16, 12)),
        ]
        let gunler = sessionDays(from: oturumlar, in: hafta(gun(16, 12)), now: gun(16, 20), calendar: takvim)
        #expect(gunler.map(\.day) == [gun(16, 0), gun(14, 0)])
        #expect(gunler.first?.sessions.map(\.startedAt) == [gun(16, 11), gun(16, 9)])
        #expect(gunler.first?.placeCount == 2)
        #expect(gunler.first?.total == 2 * 3600)
    }

    @Test("Ayın günleri yaz saati geçişinde de doğru sayılır")
    func monthDaysAcrossDST() {
        var berlin = Calendar.placeTimer
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let ekim = StatsPeriod.containing(
            berlin.date(from: DateComponents(year: 2026, month: 10, day: 10))!,
            scope: .month, calendar: berlin
        )
        #expect(dailyTotals(from: [], in: ekim, now: Date(), calendar: berlin).count == 31)
    }

    @Test("Veri yokken her şey boş döner")
    func emptyInputs() {
        let period = hafta(gun(16, 12))
        #expect(placeTotals(from: [], in: period, now: gun(16, 12)).isEmpty)
        #expect(sessionDays(from: [], in: period, now: gun(16, 12), calendar: takvim).isEmpty)
        #expect(dailyTotals(from: [], in: period, now: gun(16, 12), calendar: takvim).allSatisfy { $0.total == 0 })
    }
}

@Suite("Gün şeridi")
struct DaySegmentTests {

    @Test("Segmentler güne kırpılır ve sıralıdır")
    func clippedAndSorted() {
        let oturumlar = [
            oturum(kafe, from: gun(16, 12), to: gun(16, 14)),
            oturum(ev, from: gun(15, 22), to: gun(16, 2)),
            oturum(ev, from: gun(17, 9), to: gun(17, 10)),
        ]
        let segmentler = daySegments(from: oturumlar, on: gun(16, 12), now: gun(16, 20), calendar: takvim)
        #expect(segmentler.count == 2)
        #expect(segmentler.first?.start == gun(16, 0))
        #expect(segmentler.first?.end == gun(16, 2))
        #expect(segmentler.last?.placeID == kafe)
    }

    @Test("Açık oturum şu ana kadar uzanır")
    func openSessionExtendsToNow() {
        let acik = [oturum(ev, from: gun(16, 9), to: nil)]
        let segmentler = daySegments(from: acik, on: gun(16, 12), now: gun(16, 12), calendar: takvim)
        #expect(segmentler.first?.end == gun(16, 12))
    }

    @Test("Boş günde segment yoktur")
    func emptyDay() {
        #expect(daySegments(from: [], on: gun(16, 12), now: gun(16, 12), calendar: takvim).isEmpty)
    }
}

@Suite("CSV")
struct CSVTests {

    @Test("Dönemin oturumları kırpılmış süreyle yazılır")
    func csvRows() {
        let oturumlar = [
            oturum(ev, from: gun(16, 9), to: gun(16, 10, 30)),
            oturum(kafe, from: gun(20, 23), to: gun(21, 1)),
        ]
        let csv = sessionsCSV(
            oturumlar, in: hafta(gun(16, 12)), now: gun(22, 12),
            timeZone: TimeZone(identifier: "Europe/Istanbul")!
        ) { $0 == ev ? "Ev, \"merkez\"" : "Kafe" }

        let satirlar = csv.split(separator: "\n").map(String.init)
        #expect(satirlar.first == "başlangıç,bitiş,süre_dk,yer")
        #expect(satirlar[1] == #"2026-09-16 09:00,2026-09-16 10:30,90,"Ev, ""merkez""""#)
        #expect(satirlar[2] == "2026-09-20 23:00,2026-09-21 01:00,60,Kafe")
    }

    @Test("Oturum yoksa yalnızca başlık yazılır")
    func emptyCSV() {
        let csv = sessionsCSV([], in: hafta(gun(16, 12)), now: gun(16, 12), timeZone: .current) { _ in "" }
        #expect(csv == "başlangıç,bitiş,süre_dk,yer\n")
    }
}
```

`Tests/PlaceTimerCoreTests/HistoryTests.swift` içindeki `SessionsInRangeTests` suite'inde iki `sessionsIn(.today, from: X, now: Y)` çağrısını şununla değiştir:

```swift
sessionsOverlapping(X, interval: StatsPeriod.containing(Y, scope: .day).interval, now: Y)
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `swift test --filter "StatsPeriodTests|TotalsTests|DaySegmentTests|CSVTests"`
Expected: FAIL — `Calendar.placeTimer`, `StatsPeriod` yok.

- [ ] **Step 3: `Statistics.swift`'i yeniden yaz**

`Sources/PlaceTimerCore/Statistics.swift` dosyasının tamamını şununla değiştir:

```swift
import Foundation

extension Calendar {
    /// İstatistiğin takvimi. Arayüz Türkçe: sistem bölgesi en_US olsa bile
    /// "bu hafta" pazar değil pazartesi başlamalı.
    public static var placeTimer: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .current
        return calendar
    }
}

private let turkish = Locale(identifier: "tr_TR")

/// Bir yerin belirli bir dönemdeki toplamı.
public struct PlaceTotal: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let totalSeconds: TimeInterval
    public let sessionCount: Int

    public var id: String { placeID?.uuidString ?? "bilinmeyen" }

    public init(placeID: UUID?, totalSeconds: TimeInterval, sessionCount: Int) {
        self.placeID = placeID
        self.totalSeconds = totalSeconds
        self.sessionCount = sessionCount
    }
}

/// İstatistiğin ölçeği. Dönemler takvim tabanlıdır, kayan pencere değil.
public enum StatsScope: String, Sendable, CaseIterable, Hashable {
    case day, week, month

    public var displayName: String {
        switch self {
        case .day: "Gün"
        case .week: "Hafta"
        case .month: "Ay"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// Belirli bir gün, hafta ya da ay. Geçmişte gezinmek `shifted(by:)` ile.
public struct StatsPeriod: Sendable, Hashable {
    public let scope: StatsScope
    public let interval: DateInterval

    public static func containing(
        _ date: Date,
        scope: StatsScope,
        calendar: Calendar = .placeTimer
    ) -> StatsPeriod {
        let interval = calendar.dateInterval(of: scope.component, for: date)
            ?? DateInterval(start: date, duration: 0)
        return StatsPeriod(scope: scope, interval: interval)
    }

    public func shifted(by steps: Int, calendar: Calendar = .placeTimer) -> StatsPeriod {
        let anchor = calendar.date(byAdding: scope.component, value: steps, to: interval.start)
            ?? interval.start
        return .containing(anchor, scope: scope, calendar: calendar)
    }

    /// Bitiş hariç: gece yarısı ertesi güne aittir.
    public func contains(_ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    /// "Bugün", "Geçen hafta", "22–28 Eyl", "Temmuz 2026".
    public func title(now: Date, calendar: Calendar = .placeTimer) -> String {
        let current = StatsPeriod.containing(now, scope: scope, calendar: calendar)
        if self == current {
            switch scope {
            case .day: return "Bugün"
            case .week: return "Bu hafta"
            case .month: return "Bu ay"
            }
        }
        if self == current.shifted(by: -1, calendar: calendar) {
            switch scope {
            case .day: return "Dün"
            case .week: return "Geçen hafta"
            case .month: return "Geçen ay"
            }
        }

        var style = Date.FormatStyle(locale: turkish, calendar: calendar, timeZone: calendar.timeZone)
        switch scope {
        case .day:
            style = style.weekday(.abbreviated).day().month(.abbreviated)
            return interval.start.formatted(style)
        case .week:
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let sameMonth = calendar.isDate(interval.start, equalTo: last, toGranularity: .month)
            let startText = interval.start.formatted(
                sameMonth ? style.day() : style.day().month(.abbreviated)
            )
            return "\(startText)–\(last.formatted(style.day().month(.abbreviated)))"
        case .month:
            return interval.start.formatted(style.month(.wide).year())
        }
    }
}

// MARK: - Kırpma

/// Oturumun bir aralığa düşen kısmı. Açık oturum `now`'a kadar sayılır.
public func overlap(of session: Session, with interval: DateInterval, now: Date) -> TimeInterval {
    let start = max(session.startedAt, interval.start)
    let end = min(session.endedAt ?? now, interval.end)
    return max(0, end.timeIntervalSince(start))
}

public func totalSeconds(from sessions: [Session], in interval: DateInterval, now: Date) -> TimeInterval {
    sessions.reduce(0) { $0 + overlap(of: $1, with: interval, now: now) }
}

/// Aralıkla kesişen oturumlar, en yenisi başta.
public func sessionsOverlapping(
    _ sessions: [Session],
    interval: DateInterval,
    now: Date
) -> [Session] {
    sessions
        .filter { overlap(of: $0, with: interval, now: now) > 0 }
        .sorted { $0.startedAt > $1.startedAt }
}

// MARK: - Toplamlar

/// Oturumları yere göre toplar; toplam süreye göre azalan.
public func placeTotals(from sessions: [Session], in period: StatsPeriod, now: Date) -> [PlaceTotal] {
    var accumulator: [UUID?: (total: TimeInterval, count: Int)] = [:]
    for session in sessions {
        let seconds = overlap(of: session, with: period.interval, now: now)
        guard seconds > 0 else { continue }
        var entry = accumulator[session.placeID] ?? (0, 0)
        entry.total += seconds
        entry.count += 1
        accumulator[session.placeID] = entry
    }
    return accumulator
        .map { PlaceTotal(placeID: $0.key, totalSeconds: $0.value.total, sessionCount: $0.value.count) }
        .sorted { $0.totalSeconds > $1.totalSeconds }
}

/// Önceki dönemin toplamı. Dönem henüz sürüyorsa önceki dönem de aynı
/// noktaya kadar sayılır: çarşamba öğlen "bu hafta"yı geçen haftanın tamamıyla
/// kıyaslamak her hafta "eksik" gösterirdi.
public func previousComparableTotal(
    from sessions: [Session],
    for period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> TimeInterval {
    let previous = period.shifted(by: -1, calendar: calendar).interval
    guard period.contains(now) else {
        return totalSeconds(from: sessions, in: previous, now: now)
    }
    let elapsed = now.timeIntervalSince(period.interval.start)
    let cutoff = min(previous.end, previous.start.addingTimeInterval(elapsed))
    return totalSeconds(from: sessions, in: DateInterval(start: previous.start, end: cutoff), now: now)
}

/// Bir günde bir yerin payı.
public struct PlaceShare: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let seconds: TimeInterval
    public var id: String { placeID?.uuidString ?? "bilinmeyen" }
}

/// Grafiğin bir çubuğu.
public struct DayTotal: Sendable, Equatable, Identifiable {
    public let day: Date
    public let shares: [PlaceShare]
    public var total: TimeInterval { shares.reduce(0) { $0 + $1.seconds } }
    public var id: Date { day }
}

/// Dönemin her günü (boş günler dahil), eskiden yeniye.
public func dailyTotals(
    from sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [DayTotal] {
    days(in: period.interval, calendar: calendar).map { day in
        var byPlace: [UUID?: TimeInterval] = [:]
        for session in sessions {
            let seconds = overlap(of: session, with: day, now: now)
            if seconds > 0 { byPlace[session.placeID, default: 0] += seconds }
        }
        let shares = byPlace
            .map { PlaceShare(placeID: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
        return DayTotal(day: day.start, shares: shares)
    }
}

/// Oturum listesinin bir bölümü.
public struct SessionDay: Sendable, Equatable, Identifiable {
    public let day: Date
    /// O günle kesişen oturumlar, en yenisi başta. Geceyi aşan bir oturum iki
    /// günde de görünür.
    public let sessions: [Session]
    /// Oturumların o güne düşen toplamı.
    public let total: TimeInterval
    /// O gün kaç farklı yer var; tek yerse satırlar yer adını tekrarlamaz.
    public let placeCount: Int
    public var id: Date { day }
}

/// Dönemin oturumlu günleri, en yeni gün başta. Gelecek ve boş günler yok.
public func sessionDays(
    from sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [SessionDay] {
    days(in: period.interval, calendar: calendar)
        .filter { $0.start <= now }
        .reversed()
        .compactMap { day in
            let daySessions = sessionsOverlapping(sessions, interval: day, now: now)
            guard !daySessions.isEmpty else { return nil }
            return SessionDay(
                day: day.start,
                sessions: daySessions,
                total: totalSeconds(from: daySessions, in: day, now: now),
                placeCount: Set(daySessions.map(\.placeID)).count
            )
        }
}

private func days(in interval: DateInterval, calendar: Calendar) -> [DateInterval] {
    var result: [DateInterval] = []
    var cursor = calendar.startOfDay(for: interval.start)
    while cursor < interval.end {
        guard let day = calendar.dateInterval(of: .day, for: cursor) else { break }
        result.append(day)
        cursor = day.end
    }
    return result
}

// MARK: - Gün şeridi

/// Gün şeridinin tek bir parçası.
public struct DaySegment: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let start: Date
    public let end: Date

    public var id: Date { start }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(placeID: UUID?, start: Date, end: Date) {
        self.placeID = placeID
        self.start = start
        self.end = end
    }
}

/// Bir günün oturumları zaman sırasıyla, güne kırpılmış. Oturumlar arası
/// boşluklar segment üretmez: "bilgisayar kapalıydı" ile "buradaydım" ayrışır.
public func daySegments(
    from sessions: [Session],
    on day: Date,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [DaySegment] {
    guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
    return sessions
        .filter { overlap(of: $0, with: interval, now: now) > 0 }
        .sorted { $0.startedAt < $1.startedAt }
        .map {
            DaySegment(
                placeID: $0.placeID,
                start: max($0.startedAt, interval.start),
                end: min($0.endedAt ?? now, interval.end)
            )
        }
}

// MARK: - Dışa aktarma

/// Dönemin oturumları CSV olarak, eskiden yeniye. Süre döneme kırpılmış
/// dakikadır; saatler oturumun kendi başlangıç ve bitişidir.
public func sessionsCSV(
    _ sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    timeZone: TimeZone = .current,
    placeName: (UUID?) -> String
) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    var lines = ["başlangıç,bitiş,süre_dk,yer"]
    for session in sessionsOverlapping(sessions, interval: period.interval, now: now).reversed() {
        let minutes = Int(overlap(of: session, with: period.interval, now: now) / 60)
        lines.append([
            formatter.string(from: session.startedAt),
            session.endedAt.map(formatter.string(from:)) ?? "",
            String(minutes),
            csvField(placeName(session.placeID)),
        ].joined(separator: ","))
    }
    return lines.joined(separator: "\n") + "\n"
}

private func csvField(_ value: String) -> String {
    guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
    return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
```

- [ ] **Step 4: Çekirdek testlerini çalıştır**

Run: `swift test --filter "StatsPeriodTests|TotalsTests|DaySegmentTests|CSVTests|SessionsInRangeTests"`
Expected: PASS. (Kit henüz derlenmeyebilir; `swift test` tüm paketi derlediği için Step 5'i bitirmeden tam test çalışmaz — bu adımda hata alırsan Step 5'e geç, sonra Step 6'da hepsini çalıştır.)

- [ ] **Step 5: Kit'i yeni API'ye taşı**

`Sources/PlaceTimerKit/UI/Formatters.swift` içinde `DurationFormat`'a ekle ve `range`'i ona dayandır:

```swift
    /// Saat: `12:36`. Arayüz yalnızca Türkçe; sistem bölgesi en_US olsa bile
    /// "12:36 PM" yazılmasın diye yerel ayar sabit.
    public static func time(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: Locale(identifier: "tr_TR"))
        )
    }

    /// Oturum aralığı: `09:10–11:30` veya süregelen oturum için `12:40–…`.
    public static func range(from start: Date, to end: Date?) -> String {
        guard let end else { return "\(time(start))–…" }
        return "\(time(start))–\(time(end))"
    }
```

(eski `DateFormatter`'lı `range` silinir.)

`Sources/PlaceTimerKit/UI/DayStripView.swift`: iki `Text(…, format: .dateTime.hour().minute())` satırını `Text(DurationFormat.time(start))` ve `Text(DurationFormat.time(now))` yap. Görünüm parametrelerine `var height: CGFloat = Design.stripHeight` ekle ve `.frame(height: Design.stripHeight)` → `.frame(height: height)`.

`Sources/PlaceTimerKit/UI/PanelSummaryView.swift`: `value: started.formatted(date: .omitted, time: .shortened)` → `value: DurationFormat.time(started)`.

`Sources/PlaceTimerKit/AppCoordinator.swift`:

"Görünen durum" bölümüne:

```swift
    public private(set) var todayTotalSeconds: TimeInterval = 0
    /// Bugün kaç farklı yerde bulunuldu; tek yerse panel "Bugün burada"yı
    /// "Bugün toplam"ın tekrarı olarak göstermez.
    public private(set) var placesTodayCount: Int = 0
```

`refreshDisplay(now:)` içindeki `todaySegments`/`todayHereSeconds` satırlarını şununla değiştir:

```swift
        let today = StatsPeriod.containing(now, scope: .day)
        let todayTotals = placeTotals(from: allSessions, in: today, now: now)
        todaySegments = daySegments(from: allSessions, on: now, now: now)
        todayTotalSeconds = todayTotals.reduce(0) { $0 + $1.totalSeconds }
        placesTodayCount = todayTotals.count
        todayHereSeconds = todayTotals
            .first { $0.placeID == engine.currentSession?.placeID }?
            .totalSeconds ?? 0
```

"İstatistik" bölümündeki `totals(for:)` fonksiyonunu ve "Oturum düzeltmeleri"ndeki `sessions(for:)` fonksiyonunu sil; yerine "İstatistik" bölümüne:

```swift
    public func totals(in period: StatsPeriod) -> [PlaceTotal] {
        placeTotals(from: allSessions, in: period, now: Date())
    }

    public func totalSeconds(in period: StatsPeriod) -> TimeInterval {
        PlaceTimerCore.totalSeconds(from: allSessions, in: period.interval, now: Date())
    }

    public func previousTotalSeconds(for period: StatsPeriod) -> TimeInterval {
        previousComparableTotal(from: allSessions, for: period, now: Date())
    }

    public func dailyTotals(in period: StatsPeriod) -> [DayTotal] {
        PlaceTimerCore.dailyTotals(from: allSessions, in: period, now: Date())
    }

    public func sessionDays(in period: StatsPeriod) -> [SessionDay] {
        PlaceTimerCore.sessionDays(from: allSessions, in: period, now: Date())
    }

    public func segments(on day: Date) -> [DaySegment] {
        daySegments(from: allSessions, on: day, now: Date())
    }

    public func csv(in period: StatsPeriod) -> String {
        sessionsCSV(allSessions, in: period, now: Date()) { placeName(for: $0) }
    }
```

`Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift` (Task 9'da baştan yazılacak; burada yalnızca derlensin):
- `@State private var range: StatsRange = .week` → `@State private var scope: StatsScope = .week` ve `private var period: StatsPeriod { .containing(Date(), scope: scope) }`.
- `coordinator.totals(for: range)` → `coordinator.totals(in: period)`; `coordinator.sessions(for: range)` → `coordinator.sessionDays(in: period).flatMap(\.sessions)`.
- Picker: `Picker("Aralık", selection: $scope) { ForEach(StatsScope.allCases, id: \.self) { Text($0.displayName).tag($0) } }`.
- `"Aktif \(…) · \(total.sessionCount) oturum"` metnini `"\(total.sessionCount) oturum"` yap.

- [ ] **Step 6: Bütün testleri çalıştır**

Run: `swift build && swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A Sources Tests
git commit -m "feat: istatistik donemleri, gun sinirinda kirpma, karsilastirma ve CSV

Hafta sistem bolgesinden bagimsiz pazartesi basliyor; saatler tr_TR 24 saat.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Geçmişi elle düzeltme — birleştir, düzenle, geri al

**Files:**
- Modify: `Sources/PlaceTimerCore/Models.swift` (`Session.startedAt` → `var`)
- Modify: `Sources/PlaceTimerCore/History.swift`
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift` (`replaceCurrentSession`)
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`
- Modify: `Tests/PlaceTimerCoreTests/HistoryTests.swift` (yeni suite'ler eklenir)

**Interfaces:**
- Consumes: Task 3'ün `forgetRecent()`.
- Produces: `SessionHistory.EditError` (`differentPlaces, tooFew, invalidRange, future, overlaps`); `SessionHistory.merge(_ ids: Set<UUID>, in: [Session]) -> Result<[Session], EditError>`; `SessionHistory.update(_ edited: Session, in: [Session], now: Date) -> Result<[Session], EditError>`; `SessionHistory.previous(of id: UUID, in: [Session]) -> Session?`; `SessionEngine.replaceCurrentSession(_:)`; koordinatörde `session(id:)`, `previousSession(of:)`, `mergeSessions(_:) -> SessionHistory.EditError?`, `mergeWithPrevious(_:) -> SessionHistory.EditError?`, `validateEdit(_:) -> SessionHistory.EditError?`, `updateSession(_:) -> SessionHistory.EditError?`, `deleteSessions(_:)`, `canUndo`, `undoLastEdit()`.

- [ ] **Step 1: Testleri yaz**

`Tests/PlaceTimerCoreTests/HistoryTests.swift` dosyasının sonuna ekle (dosyadaki `at(_:)` ve `oturum(_:from:to:)` yardımcıları dakika alıyor, onları kullan):

```swift
@Suite("Oturum birleştirme")
struct SessionMergeTests {

    @Test("Aynı yerdeki oturumlar aradaki boşlukla birlikte tek oturum olur")
    func mergesSamePlace() throws {
        let ev = UUID()
        let a = oturum(ev, from: 0, to: 30)
        let b = oturum(ev, from: 40, to: 60)
        let sonuc = try SessionHistory.merge([a.id, b.id], in: [a, b]).get()

        #expect(sonuc.count == 1)
        #expect(sonuc.first?.id == a.id)
        #expect(sonuc.first?.startedAt == at(0))
        #expect(sonuc.first?.endedAt == at(60))
    }

    @Test("Farklı yerler birleştirilemez")
    func rejectsDifferentPlaces() {
        let a = oturum(UUID(), from: 0, to: 30)
        let b = oturum(UUID(), from: 40, to: 60)
        #expect(SessionHistory.merge([a.id, b.id], in: [a, b]) == .failure(.differentPlaces))
    }

    @Test("Arada başka bir yerin oturumu varsa birleştirilemez")
    func rejectsOverlapWithOthers() {
        let ev = UUID()
        let a = oturum(ev, from: 0, to: 30)
        let arada = oturum(UUID(), from: 30, to: 40)
        let b = oturum(ev, from: 40, to: 60)
        #expect(SessionHistory.merge([a.id, b.id], in: [a, arada, b]) == .failure(.overlaps))
    }

    @Test("Tek oturum birleştirilemez")
    func rejectsSingle() {
        let a = oturum(UUID(), from: 0, to: 30)
        #expect(SessionHistory.merge([a.id], in: [a]) == .failure(.tooFew))
    }

    @Test("Açık oturum katılırsa sonuç açık kalır")
    func openSessionStaysOpen() throws {
        let ev = UUID()
        let a = oturum(ev, from: 0, to: 30)
        let acik = Session(placeID: ev, startedAt: at(40))
        let sonuc = try SessionHistory.merge([a.id, acik.id], in: [a, acik]).get()
        #expect(sonuc.first?.endedAt == nil)
        #expect(sonuc.first?.startedAt == at(0))
    }

    @Test("Önceki oturum aynı yerdeki en yakın eski oturumdur")
    func previousSession() {
        let ev = UUID()
        let a = oturum(ev, from: 0, to: 30)
        let baska = oturum(UUID(), from: 30, to: 35)
        let b = oturum(ev, from: 40, to: 60)
        #expect(SessionHistory.previous(of: b.id, in: [a, baska, b])?.id == a.id)
        #expect(SessionHistory.previous(of: a.id, in: [a, baska, b]) == nil)
    }
}

@Suite("Oturum düzenleme")
struct SessionEditTests {

    @Test("Saatler değişir")
    func updatesTimes() throws {
        var a = oturum(UUID(), from: 0, to: 30)
        a.startedAt = at(5)
        let sonuc = try SessionHistory.update(a, in: [a], now: at(100)).get()
        #expect(sonuc.first?.startedAt == at(5))
    }

    @Test("Bitiş başlangıçtan önce olamaz")
    func rejectsInvertedRange() {
        var a = oturum(UUID(), from: 0, to: 30)
        a.endedAt = at(-5)
        #expect(SessionHistory.update(a, in: [a], now: at(100)) == .failure(.invalidRange))
    }

    @Test("Başlangıç gelecekte olamaz")
    func rejectsFuture() {
        var a = Session(placeID: UUID(), startedAt: at(0))
        a.startedAt = at(200)
        #expect(SessionHistory.update(a, in: [a], now: at(100)) == .failure(.future))
    }

    @Test("Komşu oturumla çakışamaz")
    func rejectsOverlap() {
        let a = oturum(UUID(), from: 0, to: 30)
        var b = oturum(UUID(), from: 40, to: 60)
        b.startedAt = at(20)
        #expect(SessionHistory.update(b, in: [a, b], now: at(100)) == .failure(.overlaps))
    }
}

@Suite("Açık oturumun değiştirilmesi")
struct ReplaceCurrentTests {

    @Test("Açık oturum değiştirilir, son kapananlar unutulur")
    func replaceForgetsRecent() {
        let ev = UUID()
        var engine = SessionEngine(recentlyEnded: [oturum(ev, from: 0, to: 10)])
        engine.handle(.wake, at: at(100))   // eşikten sonra: yeni oturum
        var yeni = engine.currentSession!
        yeni.startedAt = at(50)

        engine.replaceCurrentSession(yeni)

        #expect(engine.currentSession?.startedAt == at(50))
        #expect(engine.recentlyEnded.isEmpty)
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `swift test --filter "SessionMergeTests|SessionEditTests|ReplaceCurrentTests"`
Expected: FAIL — `startedAt` değiştirilemez, `merge` yok.

- [ ] **Step 3: Çekirdeği yaz**

`Sources/PlaceTimerCore/Models.swift`: `public let startedAt: Date` → `public var startedAt: Date`.

`Sources/PlaceTimerCore/History.swift` içinde `SessionHistory` enum'una, `remove`'un altına ekle:

```swift
    public enum EditError: Error, Equatable, Sendable {
        case differentPlaces
        case tooFew
        case invalidRange
        case future
        case overlaps
    }

    /// Seçili oturumları tek oturumda toplar: en erken başlangıç, en geç bitiş,
    /// aradaki boşluk dahil. En eski oturumun kimliği kalır. Seçimde açık
    /// oturum varsa sonuç açıktır.
    public static func merge(
        _ ids: Set<UUID>,
        in sessions: [Session]
    ) -> Result<[Session], EditError> {
        let selected = sessions.filter { ids.contains($0.id) }.sorted { $0.startedAt < $1.startedAt }
        guard selected.count >= 2, var merged = selected.first else { return .failure(.tooFew) }
        guard Set(selected.map(\.placeID)).count == 1 else { return .failure(.differentPlaces) }

        if selected.contains(where: { $0.endedAt == nil }) {
            merged.endedAt = nil
        } else {
            merged.endedAt = selected.compactMap(\.endedAt).max()
        }
        merged.notifiedMarks = selected.reduce(into: Set<Int>()) { $0.formUnion($1.notifiedMarks) }

        let others = sessions.filter { !ids.contains($0.id) }
        let mergedEnd = merged.endedAt ?? .distantFuture
        if others.contains(where: { overlaps($0.startedAt, $0.endedAt ?? .distantFuture, merged.startedAt, mergedEnd) }) {
            return .failure(.overlaps)
        }
        return .success((others + [merged]).sorted { $0.startedAt < $1.startedAt })
    }

    /// Bir oturumun saatini ya da yerini değiştirir.
    public static func update(
        _ edited: Session,
        in sessions: [Session],
        now: Date
    ) -> Result<[Session], EditError> {
        guard edited.startedAt <= now else { return .failure(.future) }
        let end = edited.endedAt ?? now
        guard edited.startedAt < end else { return .failure(.invalidRange) }

        let others = sessions.filter { $0.id != edited.id }
        if others.contains(where: { overlaps($0.startedAt, $0.endedAt ?? now, edited.startedAt, end) }) {
            return .failure(.overlaps)
        }
        return .success((others + [edited]).sorted { $0.startedAt < $1.startedAt })
    }

    /// Aynı yerde, bu oturumdan önce biten en yakın oturum.
    public static func previous(of id: UUID, in sessions: [Session]) -> Session? {
        guard let target = sessions.first(where: { $0.id == id }) else { return nil }
        return sessions
            .filter {
                $0.id != id && $0.placeID == target.placeID
                    && ($0.endedAt ?? .distantFuture) <= target.startedAt
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private static func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }
```

`Sources/PlaceTimerCore/SessionEngine.swift` içinde `forgetRecent()`'in altına:

```swift
    /// Açık oturumu elle düzeltilmiş hâliyle değiştirir (birleştirme, saat
    /// düzeltme, geri alma). Son kapananlar da unutulur.
    public mutating func replaceCurrentSession(_ session: Session) {
        currentSession = session
        recentlyEnded.removeAll()
    }
```

- [ ] **Step 4: Çekirdek testlerini çalıştır**

Run: `swift test --filter "SessionMergeTests|SessionEditTests|ReplaceCurrentTests"`
Expected: PASS.

- [ ] **Step 5: Koordinatöre düzeltme ve geri almayı ekle**

`Sources/PlaceTimerKit/AppCoordinator.swift`:

Bağımlılıklar bölümüne:

```swift
    /// Son elle düzeltmeden önceki hâl. Tek adımlık geri alma yeterli: kullanıcı
    /// bir şeyi yanlış birleştirdiğinde hemen fark eder.
    private var undoSnapshot: (history: [Session], current: Session?)?
```

Görünen durum bölümüne:

```swift
    public private(set) var canUndo = false
```

`handle(effects:)` fonksiyonunun en başına (döngüden önce):

```swift
        // Motor oturumu kendisi değiştirdiyse eski anlık görüntü geçersiz.
        let changesSessions = effects.contains { effect in
            if case .markReached = effect { return false }
            return true
        }
        if changesSessions {
            undoSnapshot = nil
            canUndo = false
        }
```

"Oturum düzeltmeleri" bölümündeki `deleteSession(_:)`'ı sil ve yerine:

```swift
    public func session(id: UUID) -> Session? {
        allSessions.first { $0.id == id }
    }

    public func previousSession(of id: UUID) -> Session? {
        SessionHistory.previous(of: id, in: allSessions)
    }

    /// Yanlış açılmış oturumları siler. Açık oturum silinmez: paneldeki
    /// "Sayacı sıfırla" onu kapatıp yenisini açar.
    public func deleteSessions(_ ids: Set<UUID>) {
        let removable = ids.subtracting([engine.currentSession?.id].compactMap { $0 })
        guard !removable.isEmpty else { return }
        recordUndo()
        history.removeAll { removable.contains($0.id) }
        commitHistoryEdit()
    }

    public func deleteSession(_ id: UUID) {
        deleteSessions([id])
    }

    @discardableResult
    public func mergeSessions(_ ids: Set<UUID>) -> SessionHistory.EditError? {
        switch SessionHistory.merge(ids, in: allSessions) {
        case .failure(let error):
            return error
        case .success(let merged):
            recordUndo()
            apply(edited: merged)
            return nil
        }
    }

    @discardableResult
    public func mergeWithPrevious(_ id: UUID) -> SessionHistory.EditError? {
        guard let previous = previousSession(of: id) else { return .tooFew }
        return mergeSessions([previous.id, id])
    }

    public func validateEdit(_ session: Session) -> SessionHistory.EditError? {
        if case .failure(let error) = SessionHistory.update(session, in: allSessions, now: Date()) {
            return error
        }
        return nil
    }

    @discardableResult
    public func updateSession(_ session: Session) -> SessionHistory.EditError? {
        switch SessionHistory.update(session, in: allSessions, now: Date()) {
        case .failure(let error):
            return error
        case .success(let updated):
            recordUndo()
            apply(edited: updated)
            return nil
        }
    }

    public func undoLastEdit() {
        guard let snapshot = undoSnapshot else { return }
        history = snapshot.history
        if let current = snapshot.current { engine.replaceCurrentSession(current) }
        undoSnapshot = nil
        canUndo = false
        commitHistoryEdit()
    }

    private func recordUndo() {
        undoSnapshot = (history, engine.currentSession)
        canUndo = true
    }

    /// Düzeltilmiş tam listeyi (geçmiş + açık oturum) geri dağıtır.
    private func apply(edited sessions: [Session]) {
        if let open = sessions.first(where: { $0.endedAt == nil }) {
            engine.replaceCurrentSession(open)
        }
        history = sessions.filter { $0.endedAt != nil }
        commitHistoryEdit()
    }

    private func commitHistoryEdit() {
        engine.forgetRecent()
        persistHistory()
        persistState(at: Date())
        refreshDisplay()
    }
```

- [ ] **Step 6: Derle ve test et**

Run: `swift build && swift test`
Expected: PASS. (`StatisticsSettingsView` hâlâ `coordinator.deleteSession(session.id)` çağırıyor; imza korunduğu için derlenir.)

- [ ] **Step 7: Commit**

```bash
git add -A Sources Tests
git commit -m "feat: oturumlari birlestirme, saat duzeltme ve tek adim geri alma

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Öneriler

**Files:**
- Create: `Sources/PlaceTimerCore/Suggestions.swift`
- Create: `Tests/PlaceTimerCoreTests/SuggestionsTests.swift`
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`

**Interfaces:**
- Consumes: Task 5'in `mergeSessions(_:)`, `deleteSession(_:)`; mevcut `mergePlace(_:into:)`; `Coordinate.distance(to:)`, `Place.coordinate`.
- Produces: `enum Suggestion: Identifiable { case samePlace(keep: UUID, merge: UUID); case splitSession(first: UUID, second: UUID); case emptySession(UUID); var id: String }`; `struct SuggestionState: Codable { dismissed: Set<String>; acceptedSplits: Int }`; `func suggestions(places:sessions:dismissed:gapThreshold:) -> [Suggestion]`; koordinatörde `suggestions: [Suggestion]`, `apply(_:)`, `dismiss(_:)`, `applyAllSuggestions()`, `offersLongerGap: Bool`, `adoptLongerGap()`.

- [ ] **Step 1: Testleri yaz**

Create `Tests/PlaceTimerCoreTests/SuggestionsTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func yer(_ name: String, lat: Double? = nil, lon: Double? = nil, created: Double = 0) -> Place {
    Place(ssids: [UUID().uuidString], displayName: name, latitude: lat, longitude: lon, createdAt: at(created))
}

private func oturum(_ placeID: UUID?, _ start: Double, _ end: Double?) -> Session {
    Session(placeID: placeID, startedAt: at(start), endedAt: end.map(at))
}

@Suite("Öneriler")
struct SuggestionsTests {

    @Test("Aynı adlı iki yer için birleştirme önerilir, eski olan kalır")
    func sameNameSuggestsMerge() {
        let eski = yer("Home", created: 0)
        let yeni = yer(" home ", created: 10)
        let sonuc = suggestions(places: [yeni, eski], sessions: [], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.samePlace(keep: eski.id, merge: yeni.id)])
    }

    @Test("Aksan farkı aynı ad sayılır")
    func diacriticsIgnored() {
        let a = yer("Ofis Çalışma", created: 0)
        let b = yer("ofis calisma", created: 1)
        #expect(suggestions(places: [a, b], sessions: [], dismissed: [], gapThreshold: 1800).count == 1)
    }

    @Test("150 metre içindeki iki yer için birleştirme önerilir")
    func nearbySuggestsMerge() {
        let a = yer("Ev", lat: 41.0, lon: 29.0, created: 0)
        let b = yer("Ev-5G", lat: 41.0005, lon: 29.0, created: 1)   // ~55 m
        let c = yer("Kafe", lat: 41.01, lon: 29.0, created: 2)      // ~1 km
        let sonuc = suggestions(places: [a, b, c], sessions: [], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.samePlace(keep: a.id, merge: b.id)])
    }

    @Test("Aynı yerde kısa arayla bölünmüş oturumlar önerilir")
    func splitSessionSuggested() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let b = oturum(ev, 100, 160)     // 40 dk ara, 3×30 = 90 dk altında
        let c = oturum(ev, 300, 360)     // 140 dk ara: önerilmez
        let sonuc = suggestions(places: [], sessions: [a, b, c], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.splitSession(first: a.id, second: b.id)])
    }

    @Test("Açık oturum bölünmüş çiftin ikincisi olabilir")
    func openSessionCanBeSecond() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let acik = oturum(ev, 70, nil)
        #expect(suggestions(places: [], sessions: [a, acik], dismissed: [], gapThreshold: 1800)
            == [.splitSession(first: a.id, second: acik.id)])
    }

    @Test("İki dakikadan kısa kapanmış oturum silinmek üzere önerilir")
    func emptySessionSuggested() {
        let ev = UUID()
        let bos = oturum(ev, 0, 1)
        let sonuc = suggestions(places: [], sessions: [bos], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.emptySession(bos.id)])
    }

    @Test("Boş oturum bölünmüş çifte girmez")
    func emptyNotInSplit() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let bos = oturum(ev, 65, 66)
        #expect(suggestions(places: [], sessions: [a, bos], dismissed: [], gapThreshold: 1800)
            == [.emptySession(bos.id)])
    }

    @Test("Reddedilen öneri bir daha çıkmaz")
    func dismissedHidden() {
        let ev = UUID()
        let bos = oturum(ev, 0, 1)
        let oneri = Suggestion.emptySession(bos.id)
        #expect(suggestions(places: [], sessions: [bos], dismissed: [oneri.id], gapThreshold: 1800).isEmpty)
    }

    @Test("Kimlik kararlıdır: yer sırası değişse de aynıdır")
    func stableIDs() {
        let a = UUID(), b = UUID()
        #expect(Suggestion.samePlace(keep: a, merge: b).id == Suggestion.samePlace(keep: b, merge: a).id)
    }

    @Test("Veri yokken öneri yoktur")
    func emptyInput() {
        #expect(suggestions(places: [], sessions: [], dismissed: [], gapThreshold: 1800).isEmpty)
    }

    @Test("Durum dosyası eksik alanla okunur")
    func stateDecodes() throws {
        let state = try JSONDecoder().decode(SuggestionState.self, from: Data("{}".utf8))
        #expect(state.dismissed.isEmpty)
        #expect(state.acceptedSplits == 0)
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `swift test --filter SuggestionsTests`
Expected: FAIL — `Suggestion` yok.

- [ ] **Step 3: Çekirdeği yaz**

Create `Sources/PlaceTimerCore/Suggestions.swift`:

```swift
import Foundation

/// Uygulamanın kendi bulduğu düzeltme adayı. Kullanıcı tek tıkla onaylar ya
/// da reddeder; geçmişe dokunmak her zaman onayla olur.
public enum Suggestion: Sendable, Equatable, Identifiable {
    /// İki kayıt aynı yer gibi görünüyor. `keep` eski olan; birleştirmede kalır.
    case samePlace(keep: UUID, merge: UUID)
    /// Aynı yerde, arası kısa iki ardışık oturum.
    case splitSession(first: UUID, second: UUID)
    /// Hiçbir şey anlatmayan, çok kısa kapanmış oturum.
    case emptySession(UUID)

    /// Kararlı kimlik: reddedilenler bununla saklanır. Yer çiftinde sıra
    /// önemsiz; hangisinin eski olduğu ileride değişse de aynı öneridir.
    public var id: String {
        switch self {
        case .samePlace(let a, let b):
            "yer:" + [a.uuidString, b.uuidString].sorted().joined(separator: ":")
        case .splitSession(let a, let b):
            "bolunme:\(a.uuidString):\(b.uuidString)"
        case .emptySession(let a):
            "bos:\(a.uuidString)"
        }
    }
}

/// `suggestions.json` içeriği.
public struct SuggestionState: Codable, Sendable, Equatable {
    public var dismissed: Set<String>
    /// Onaylanan bölünme önerisi sayısı. Kullanıcı aynı türden aralığı tekrar
    /// tekrar birleştiriyorsa eşiği büyütmeyi önermenin dayanağı.
    public var acceptedSplits: Int

    public init(dismissed: Set<String> = [], acceptedSplits: Int = 0) {
        self.dismissed = dismissed
        self.acceptedSplits = acceptedSplits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dismissed: try container.decodeIfPresent(Set<String>.self, forKey: .dismissed) ?? [],
            acceptedSplits: try container.decodeIfPresent(Int.self, forKey: .acceptedSplits) ?? 0
        )
    }
}

public enum SuggestionRules {
    public static let samePlaceDistance: Double = 150
    public static let splitGapMultiplier: Double = 3
    public static let emptySessionLimit: TimeInterval = 120
}

/// Öneriler: önce yerler (en çok bölünmeye onlar yol açar), sonra oturumlar
/// en yenisi başta.
public func suggestions(
    places: [Place],
    sessions: [Session],
    dismissed: Set<String>,
    gapThreshold: TimeInterval
) -> [Suggestion] {
    var result: [Suggestion] = samePlaceSuggestions(places)

    let empties = sessions.filter {
        guard let end = $0.endedAt else { return false }
        return end.timeIntervalSince($0.startedAt) < SuggestionRules.emptySessionLimit
    }
    let emptyIDs = Set(empties.map(\.id))

    var sessionSuggestions: [(Date, Suggestion)] = empties.map { ($0.startedAt, .emptySession($0.id)) }

    let ordered = sessions
        .filter { !emptyIDs.contains($0.id) }
        .sorted { $0.startedAt < $1.startedAt }
    for (first, second) in zip(ordered, ordered.dropFirst()) {
        guard
            let placeID = first.placeID, second.placeID == placeID,
            let firstEnd = first.endedAt
        else { continue }
        let gap = second.startedAt.timeIntervalSince(firstEnd)
        guard gap >= 0, gap < gapThreshold * SuggestionRules.splitGapMultiplier else { continue }
        sessionSuggestions.append((second.startedAt, .splitSession(first: first.id, second: second.id)))
    }

    result += sessionSuggestions.sorted { $0.0 > $1.0 }.map(\.1)
    return result.filter { !dismissed.contains($0.id) }
}

private func samePlaceSuggestions(_ places: [Place]) -> [Suggestion] {
    let ordered = places.sorted { $0.createdAt < $1.createdAt }
    var result: [Suggestion] = []
    var merged: Set<UUID> = []

    for (index, keep) in ordered.enumerated() where !merged.contains(keep.id) {
        for candidate in ordered.dropFirst(index + 1) where !merged.contains(candidate.id) {
            guard isSamePlace(keep, candidate) else { continue }
            result.append(.samePlace(keep: keep.id, merge: candidate.id))
            merged.insert(candidate.id)
        }
    }
    return result
}

private func isSamePlace(_ a: Place, _ b: Place) -> Bool {
    if normalized(a.displayName) == normalized(b.displayName) { return true }
    guard let ca = a.coordinate, let cb = b.coordinate else { return false }
    return ca.distance(to: cb) <= SuggestionRules.samePlaceDistance
}

private func normalized(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
}
```

- [ ] **Step 4: Çekirdek testlerini çalıştır**

Run: `swift test --filter SuggestionsTests`
Expected: PASS. (`"Ofis Çalışma"`/`"ofis calisma"` testi `ı`→`i` katlamasına dayanıyor; geçmezse `normalized` içinde katlamadan önce `.replacingOccurrences(of: "ı", with: "i")` ekle ve testi yeniden çalıştır.)

- [ ] **Step 5: Koordinatöre öneri durumunu ekle**

`Sources/PlaceTimerKit/AppCoordinator.swift`:

Depolar bölümüne `private let suggestionStore: JSONFileStore<SuggestionState>` ve `private var suggestionState = SuggestionState()`; `init` içinde:

```swift
        suggestionStore = JSONFileStore(url: base.appendingPathComponent("suggestions.json"))
```

Görünen durum bölümüne:

```swift
    public private(set) var suggestions: [Suggestion] = []
```

`start()` içinde `history = …` satırının altına:

```swift
        suggestionState = (try? suggestionStore.load()) ?? SuggestionState()
```

ve `refreshDisplay()` çağrısından önce `refreshSuggestions()`.

`handle(effects:)` içinde `.sessionEnded` ve `.sessionResumed` dallarının sonuna `refreshSuggestions()`; `commitHistoryEdit()`, `mergePlace(_:into:)`, `createPlace(named:)`, `mergeIntoPlace(_:)`, `createPlaceManually(named:)`, `removePlace(_:)`, `renamePlace(_:to:)` sonlarına `refreshSuggestions()`; `updatePreferences(_:)` sonuna da (eşik değişince bölünme eşiği değişir).

Yeni bölüm:

```swift
    // MARK: - Öneriler

    /// Kullanıcı aynı türden aralığı üç kez birleştirdiyse ve eşik 1 saatin
    /// altındaysa, ara eşiğini büyütmeyi önermek mantıklı.
    public var offersLongerGap: Bool {
        suggestionState.acceptedSplits >= 3 && preferences.gapThreshold < 3600
    }

    public func apply(_ suggestion: Suggestion) {
        switch suggestion {
        case .samePlace(let keep, let merge):
            mergePlace(merge, into: keep)
        case .splitSession(let first, let second):
            if mergeSessions([first, second]) == nil {
                suggestionState.acceptedSplits += 1
            } else {
                // Artık uygulanamıyor (arada başka oturum oluştu): bir daha sorma.
                suggestionState.dismissed.insert(suggestion.id)
            }
        case .emptySession(let id):
            deleteSession(id)
        }
        persistSuggestionState()
        refreshSuggestions()
    }

    public func dismiss(_ suggestion: Suggestion) {
        suggestionState.dismissed.insert(suggestion.id)
        persistSuggestionState()
        refreshSuggestions()
    }

    public func applyAllSuggestions() {
        // Her uygulama listeyi yeniden kurar; sınır, uygulanamayan bir öneride
        // sonsuz döngüye karşı.
        for _ in 0..<200 {
            guard let next = suggestions.first else { break }
            apply(next)
        }
    }

    public func adoptLongerGap() {
        var updated = preferences
        updated.gapThreshold = 3600
        suggestionState.acceptedSplits = 0
        persistSuggestionState()
        updatePreferences(updated)
    }

    private func refreshSuggestions() {
        suggestions = PlaceTimerCore.suggestions(
            places: catalog.places,
            sessions: allSessions,
            dismissed: suggestionState.dismissed,
            gapThreshold: preferences.gapThreshold
        )
    }

    private func persistSuggestionState() {
        try? suggestionStore.save(suggestionState)
    }
```

`eraseAllData()` içine `suggestionState = SuggestionState()`, `persistSuggestionState()` ve sonda `refreshSuggestions()` ekle.

- [ ] **Step 6: Derle ve test et**

Run: `swift build && swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A Sources Tests
git commit -m "feat: ayni yer, bolunmus oturum ve bos oturum onerileri

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Olay günlüğü

**Files:**
- Create: `Sources/PlaceTimerCore/EventLogFormat.swift`, `Tests/PlaceTimerCoreTests/EventLogFormatTests.swift`
- Create: `Sources/PlaceTimerKit/EventLog.swift`
- Modify: `Sources/PlaceTimerKit/LocationService.swift`, `Sources/PlaceTimerKit/AppCoordinator.swift`, `Sources/PlaceTimerKit/UI/Settings/AboutSettingsView.swift`
- Modify: `docs/privacy-policy.md`

**Interfaces:**
- Produces: `EventLogFormat.line(_:at:) -> String`, `EventLogFormat.pruned(_:now:keepDays:) -> String`; `EventLog(url:)`, `record(_:at:)`, `prune(now:)`, `erase()`, `url`; `LocationService.accuracy: Double?`; koordinatörde `revealEventLog()`.

- [ ] **Step 1: Biçim testlerini yaz**

Create `Tests/PlaceTimerCoreTests/EventLogFormatTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Olay günlüğü biçimi")
struct EventLogFormatTests {

    private let simdi = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("Satır zaman damgası ve mesajdan oluşur, tek satırdır")
    func lineFormat() {
        let satir = EventLogFormat.line("wifi ssid=Ev\nbssid=x", at: simdi)
        #expect(satir.hasSuffix("wifi ssid=Ev bssid=x\n"))
        #expect(satir.filter { $0 == "\n" }.count == 1)
        #expect(satir.hasPrefix("20"))
    }

    @Test("14 günden eski satırlar budanır")
    func prunesOldLines() {
        let eski = EventLogFormat.line("eski", at: simdi.addingTimeInterval(-15 * 86400))
        let yeni = EventLogFormat.line("yeni", at: simdi.addingTimeInterval(-86400))
        let sonuc = EventLogFormat.pruned(eski + yeni, now: simdi)
        #expect(sonuc == yeni)
    }

    @Test("Okunamayan satırlar atılır")
    func dropsGarbage() {
        let yeni = EventLogFormat.line("yeni", at: simdi)
        #expect(EventLogFormat.pruned("bozuk satır\n" + yeni, now: simdi) == yeni)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `swift test --filter EventLogFormatTests`
Expected: FAIL — `EventLogFormat` yok.

- [ ] **Step 3: Biçimi yaz**

Create `Sources/PlaceTimerCore/EventLogFormat.swift`:

```swift
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
```

Run: `swift test --filter EventLogFormatTests` → PASS.

- [ ] **Step 4: Dosya sarmalayıcısını yaz**

Create `Sources/PlaceTimerKit/EventLog.swift`:

```swift
import Foundation
import PlaceTimerCore

/// Olay günlüğü dosyası. Yazma hataları yutulur: günlük teşhis içindir,
/// yazılamaması uygulamayı durdurmamalı.
@MainActor
public final class EventLog {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func record(_ message: String, at date: Date = Date()) {
        let data = Data(EventLogFormat.line(message, at: date).utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Açılışta bir kez: 14 günden eski satırları atar.
    public func prune(now: Date = Date()) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        try? Data(EventLogFormat.pruned(text, now: now).utf8).write(to: url, options: .atomic)
    }

    public func erase() {
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] **Step 5: Konum doğruluğunu sakla**

`Sources/PlaceTimerKit/LocationService.swift`: `coordinate` özelliğinin altına `public private(set) var accuracy: Double?` ekle. `didUpdateLocations` içinde `let accuracy = last.horizontalAccuracy` al ve `MainActor.assumeIsolated` bloğunda `self.accuracy = accuracy` yaz.

- [ ] **Step 6: Koordinatörde olayları kaydet**

`Sources/PlaceTimerKit/AppCoordinator.swift`:

Bağımlılıklara `private let eventLog: EventLog` ve `private var lastLoggedResolution: String?`; `init` içinde `eventLog = EventLog(url: base.appendingPathComponent("events.log"))`. `start()` başında `eventLog.prune()` ve `eventLog.record("uygulama açıldı")`.

Güç geri çağrılarını kaydedecek şekilde değiştir:

```swift
        power.onSleep = { [weak self] in
            self?.eventLog.record("uyku")
            self?.apply(.sleep)
        }
        power.onWake = { [weak self] in
            self?.eventLog.record("uyanma")
            self?.apply(.wake)
        }
```

`checkNetwork(at:)` içinde `let snapshot = WiFiReader.snapshot()` satırının altına:

```swift
        if snapshot != lastWiFi {
            let accuracy = location.accuracy.map { "±\(Int($0))m" } ?? "konum yok"
            eventLog.record(
                "wifi ssid=\(snapshot.ssid ?? "-") bssid=\(snapshot.bssid ?? "-") \(accuracy)", at: now
            )
        }
```

`switch catalog.resolve(...)` dalının her case'inde `apply` çağrısından önce, değişince kaydeden yardımcıyı çağır:

```swift
    private func logResolution(_ text: String, at now: Date) {
        guard text != lastLoggedResolution else { return }
        lastLoggedResolution = text
        eventLog.record("yer \(text)", at: now)
    }
```

Çağrılar: `.matched(let place)` → `logResolution("eşleşti \(place.displayName)", at: now)`; `.noNetwork` → `logResolution("ağ yok", at: now)`; `.possibleBranch(let existing)` → `logResolution("şube olabilir \(existing.displayName)", at: now)`; `.unknownNetwork` → `logResolution("tanınmayan ağ", at: now)`; manuel seçim dalı → `logResolution("elle seçilmiş", at: now)`.

`handle(effects:)` içinde her dalın başına:

```swift
            case .sessionStarted(let session):
                eventLog.record("oturum başladı \(session.id.uuidString.prefix(8)) yer=\(placeName(for: session.placeID))")
            case .sessionEnded(let session):
                eventLog.record("oturum bitti \(session.id.uuidString.prefix(8)) süre=\(DurationFormat.readable(session.elapsed(at: Date())))")
            case .sessionResumed(let session, let replacing):
                eventLog.record("oturum geri açıldı \(session.id.uuidString.prefix(8)) katılan=\(replacing.count - 1)")
```

(mevcut işlemler bu satırların altında aynen kalır.)

`endCurrentSession()` başına `eventLog.record("kullanıcı sayacı sıfırladı")`; `overrideCurrentPlace(_:)` başına `eventLog.record("kullanıcı yeri seçti \(placeName(for: placeID))")`; `deleteSessions`, `mergeSessions`, `updateSession`, `mergePlace` başarı yollarına kısa birer kayıt ("kullanıcı \(n) oturum sildi", "kullanıcı oturum birleştirdi", "kullanıcı oturum düzenledi", "kullanıcı yer birleştirdi").

`eraseAllData()` içine `eventLog.erase()`.

Yeni fonksiyon (Gizlilik bölümüne):

```swift
    public func revealEventLog() {
        if !FileManager.default.fileExists(atPath: eventLog.url.path) {
            eventLog.record("günlük açıldı")
        }
        NSWorkspace.shared.activateFileViewerSelecting([eventLog.url])
    }
```

- [ ] **Step 7: Hakkında'ya teşhis satırı**

`Sources/PlaceTimerKit/UI/Settings/AboutSettingsView.swift` içinde "Veriler" bölümünden önce:

```swift
            Section {
                LabeledContent("Olay günlüğü") {
                    Button("Finder'da göster", action: coordinator.revealEventLog)
                        .buttonStyle(.link)
                }
            } header: {
                Text("Teşhis")
            } footer: {
                Text(
                    "Uyku, Wi-Fi ve oturum olaylarının son 14 günü. Bir oturum "
                        + "beklenmedik biçimde bölündüğünde nedenini görmek için. "
                        + "Cihazından çıkmaz."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
```

"Veriler" footer metnini: "Kayıtlı yerlerin, bütün oturum geçmişin ve olay günlüğü silinir, sayaç sıfırdan başlar. Ayarların olduğu gibi kalır. Geri alınamaz."

- [ ] **Step 8: Gizlilik politikası**

`docs/privacy-policy.md` içinde verilerin cihazda tutulduğunu anlatan bölüme şu maddeyi ekle (dosyanın mevcut dilini ve biçimini koru):

```markdown
- **Olay günlüğü:** Uyku/uyanma, bağlanılan Wi-Fi ağının adı ve adresi, konum
  doğruluğu ve oturum olayları son 14 gün boyunca cihazında bir dosyada
  tutulur. Yalnızca sorun teşhisi içindir, hiçbir yere gönderilmez ve
  "Tüm verileri sil" ile silinir.
```

- [ ] **Step 9: Derle, test et, commit**

Run: `swift build && swift test`
Expected: PASS.

```bash
git add -A Sources Tests docs/privacy-policy.md
git commit -m "feat: yerel olay gunlugu ve Hakkinda'da gosterimi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Ayarlar penceresi — Liquid Glass kabuk

**Files:**
- Modify: `Sources/PlaceTimerKit/UI/AppWindow.swift`
- Modify: `Sources/PlaceTimerKit/UI/SettingsView.swift`, `Sources/PlaceTimerKit/UI/Settings/SettingsTab.swift`, `Sources/PlaceTimerKit/UI/Design.swift`
- Modify: `Sources/PlaceTimerKit/PlaceTimerScene.swift`, `Sources/PlaceTimerKit/AppCoordinator.swift`
- Modify: `docs/superpowers/specs/2026-10-07-place-timer-v3-design.md` (§6.2)

**Interfaces:**
- Produces: `AppWindow(title:style:)`, `AppWindow.Style { case standard, settings }`; `SettingsTab` internal kalır; `AppCoordinator.requestedSettingsTab: SettingsTab?` (internal); `PlaceTimerAppDelegate.presentSettings(tab:)` (internal, varsayılanlı).

- [ ] **Step 1: Pencere stilini ekle**

`Sources/PlaceTimerKit/UI/AppWindow.swift`:

`private let title: String` altına:

```swift
    /// Ayarlar penceresi macOS 26'nın cam kabuğunu alır: tam boy içerik,
    /// birleşik araç çubuğu ve yüzen kenar çubuğu. Diğer küçük pencereler
    /// (yer sorusu, ilk açılış) sade kalır.
    public enum Style {
        case standard
        case settings
    }

    private let style: Style
```

`init`:

```swift
    public init(title: String, style: Style = .standard) {
        self.title = title
        self.style = style
    }
```

`present` içinde `let controller = …` ile `window.isReleasedWhenClosed = false` arasını şununla değiştir:

```swift
        let controller = NSHostingController(rootView: content())
        if style == .settings {
            // SwiftUI'nin `.toolbar` ve `.navigationTitle`'ı pencereye geçsin.
            controller.sceneBridgingOptions = [.toolbars, .title]
        }
        let window = NSWindow(contentViewController: controller)
        window.title = title
        switch style {
        case .standard:
            window.styleMask = [.titled, .closable]
        case .settings:
            // `.fullSizeContentView` olmadan kenar çubuğu pencere kenarına
            // yapışık düz bir sütun çiziliyordu; cam panel ancak içerik
            // başlık çubuğunun altına uzandığında çıkıyor.
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
        }
        window.isReleasedWhenClosed = false
```

- [ ] **Step 2: Ölçüleri büyüt**

`Sources/PlaceTimerKit/UI/Design.swift`:

```swift
    static let settingsSidebarWidth: CGFloat = 200
    static let settingsPaneWidth: CGFloat = 520
    static let settingsWidth: CGFloat = settingsSidebarWidth + settingsPaneWidth
    static let settingsHeight: CGFloat = 560
```

Yorumun sonuna: "720×560: istatistiğin grafiği ve günlere bölünmüş listesi 600×460'a sığmıyordu."

- [ ] **Step 3: Kabuğu güncelle ve sekmeye yönlendirmeyi ekle**

`Sources/PlaceTimerKit/AppCoordinator.swift` görünen durum bölümüne:

```swift
    /// Panelden "ayarların şu bölümünü aç" isteği. Ayarlar penceresi zaten
    /// açıksa da sekme değişsin diye pencere bunu izler ve tüketir.
    var requestedSettingsTab: SettingsTab?
```

`Sources/PlaceTimerKit/UI/SettingsView.swift` `body`'sini şununla değiştir:

```swift
    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $tab) { bolum in
                Label(bolum.title, systemImage: bolum.symbol)
                    .tag(bolum)
            }
            .navigationSplitViewColumnWidth(Design.settingsSidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            pane
                .navigationTitle(tab.title)
                .frame(minWidth: Design.settingsPaneWidth, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
        .onChange(of: coordinator.requestedSettingsTab, initial: true) { _, istenen in
            guard let istenen else { return }
            tab = istenen
            coordinator.requestedSettingsTab = nil
        }
    }
```

Tip yorumuna ekle: "Pencere `AppWindow.Style.settings` ile açılıyor; kenar çubuğu ve araç çubuğu sistemin cam katmanı. İçerik bilinçli olarak cam değil: Liquid Glass gezinme ve kontrol katmanı içindir, okunacak metin için değil."

`Sources/PlaceTimerKit/PlaceTimerScene.swift`:
- `private let settingsWindow = AppWindow(title: "Ayarlar")` → `AppWindow(title: "Ayarlar", style: .settings)`.
- `presentSettings()`'i şununla değiştir:

```swift
    func presentSettings(tab: SettingsTab? = nil) {
        if let tab { coordinator.requestedSettingsTab = tab }
        settingsWindow.present { [weak self] in
            if let self { SettingsView(coordinator: coordinator) }
        }
    }
```

(Fonksiyon `public` idiyse ve dışarıdan parametresiz çağrılıyorsa, ayrıca `public func presentSettings() { presentSettings(tab: nil) }` bırak; `SettingsTab` internal olduğu için parametreli sürüm internal kalır.)

- [ ] **Step 4: Spec'i uydur**

`docs/superpowers/specs/2026-10-07-place-timer-v3-design.md` §6 madde 2'yi şununla değiştir:

```markdown
2. **Kenar çubuğu:** `NavigationSplitView` kalır, kenar çubuğu açma/kapama
   düğmesi kalkar (`.toolbar(removing: .sidebarToggle)`); pencere sabit ölçülü,
   kenar çubuğu her zaman görünür. Simgeler SF Symbols, tek renk.
   `backgroundExtensionEffect` kullanılmaz: o, kenar çubuğunun altına uzanacak
   bir görsel (fotoğraf, harita) içindir; gruplu formda yalnızca bulanık bir
   şerit üretir.
```

- [ ] **Step 5: Derle ve görsel olarak doğrula**

Run: `swift build && swift test`
Expected: PASS.

Run: `Scripts/build-app.sh` ve çıkan uygulamayı aç; menubar'dan Ayarlar'ı aç. Ekran görüntüsü al: `screencapture -l$(osascript -e 'tell app "System Events" to id of window 1 of process "PlaceTimer"' 2>/dev/null) /tmp/settings.png` çalışmazsa `screencapture -i` ile pencereyi seç ve görüntüyü oku.

Beklenen: kenar çubuğu pencere kenarından ayrık, yuvarlatılmış cam bir panel; başlık çubuğu içerikle birleşik; pencere başlığı seçili bölümün adı. Kenar çubuğu düz gri sütun olarak çiziliyorsa `window.toolbar = NSToolbar(identifier: "PlaceTimerSettings")` satırını `.settings` dalına ekleyip yeniden dene.

- [ ] **Step 6: Commit**

```bash
git add -A Sources docs/superpowers/specs
git commit -m "feat: ayarlar penceresi Liquid Glass kabugu; tam boy icerik, cam kenar cubugu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: İstatistik sayfası

**Files:**
- Delete/replace: `Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift`
- Create: `Sources/PlaceTimerKit/UI/Settings/Statistics/StatsSummaryView.swift`, `DailyChartView.swift`, `SessionRowView.swift`, `SessionEditView.swift`, `SuggestionRow.swift`, `SuggestionText.swift`, `CSVDocument.swift`, `EditErrorText.swift`
- Modify: `Resources/PlaceTimer.entitlements`

**Interfaces:**
- Consumes: Task 4 (`StatsPeriod`, koordinatörün istatistik API'si), Task 5 (düzeltme API'si, `canUndo`), Task 6 (`suggestions`, `apply`, `dismiss`, `applyAllSuggestions`, `offersLongerGap`, `adoptLongerGap`), `DayStripView(segments:now:height:)`.
- Produces: `SuggestionText.make(_:coordinator:) -> SuggestionText` (`title`, `detail`, `action`) — Task 10 panel kartı kullanır; `EditErrorText.message(_:) -> String`.

- [ ] **Step 1: Hata ve öneri metinleri**

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/EditErrorText.swift`:

```swift
import PlaceTimerCore

enum EditErrorText {
    static func message(_ error: SessionHistory.EditError) -> String {
        switch error {
        case .differentPlaces: "Farklı yerlerdeki oturumlar birleştirilemez."
        case .tooFew: "Birleştirmek için aynı yerde en az iki oturum gerekiyor."
        case .invalidRange: "Bitiş, başlangıçtan sonra olmalı."
        case .future: "Başlangıç gelecekte olamaz."
        case .overlaps: "Bu saatler başka bir oturumla çakışıyor."
        }
    }
}
```

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/SuggestionText.swift`:

```swift
import PlaceTimerCore

/// Bir önerinin kullanıcıya söylediği cümle. Panel kartı ve istatistik
/// sayfası aynı metni gösterir.
struct SuggestionText {
    let title: String
    let detail: String
    let action: String

    @MainActor
    static func make(_ suggestion: Suggestion, coordinator: AppCoordinator) -> SuggestionText {
        switch suggestion {
        case .samePlace(let keep, let merge):
            let a = coordinator.placeName(for: keep)
            let b = coordinator.placeName(for: merge)
            return SuggestionText(
                title: a == b ? "İki ayrı “\(a)” kaydı var" : "“\(b)” ile “\(a)” aynı yer mi?",
                detail: "Birleştirirsem ağları ve geçmişteki oturumları tek yerde toplanır.",
                action: "Birleştir"
            )
        case .splitSession(let first, let second):
            let ilk = coordinator.session(id: first)
            let ikinci = coordinator.session(id: second)
            let yer = coordinator.placeName(for: ilk?.placeID)
            let bitis = ilk?.endedAt.map(DurationFormat.time) ?? "?"
            let baslangic = ikinci.map { DurationFormat.time($0.startedAt) } ?? "?"
            return SuggestionText(
                title: "\(yer)'daki oturum bölünmüş görünüyor",
                detail: "\(bitis)'da biten ve \(baslangic)'da başlayan iki oturum tek oturum olabilir.",
                action: "Birleştir"
            )
        case .emptySession(let id):
            let oturum = coordinator.session(id: id)
            let yer = coordinator.placeName(for: oturum?.placeID)
            let saat = oturum.map { DurationFormat.time($0.startedAt) } ?? "?"
            return SuggestionText(
                title: "Boş bir oturum var",
                detail: "\(yer)'da \(saat)'da açılıp 2 dakika dolmadan kapanmış.",
                action: "Sil"
            )
        }
    }
}
```

Not: Türkçe ek uyumu ("'da/'de/'ta/'te") yer adına göre değişir; burada sabit "'da" kullanılıyor. Uygulayıcı isterse `PlaceTimerCore`'a küçük bir `locativeSuffix(for:)` (son ünlüye ve sert ünsüze göre "da/de/ta/te") ekleyip testleyebilir — kapsam dışı değil ama zorunlu da değil; sabit ek kabul edilebilir.

- [ ] **Step 2: CSV belgesi ve izin**

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/CSVDocument.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

`Resources/PlaceTimer.entitlements` içine `network.client` bloğunun altına:

```xml
  <!--
    Istatistikteki "Disa aktar..." icin. Kaydetme paneli yalnizca kullanicinin
    sectigi konuma yazma izni verir; baska hicbir dosyaya erisim yok.
  -->
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
```

- [ ] **Step 3: Satırlar, grafik ve özet**

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/SessionRowView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Gün bölümündeki tek oturum. Ana metin saat aralığı; yer adı yalnızca o gün
/// birden çok yer varsa görünür — tek yerli bir günde her satırda "Home"
/// yazmak bilgi değil gürültü.
struct SessionRowView: View {
    let session: Session
    let placeName: String
    let showsPlace: Bool
    let isCurrent: Bool
    /// Oturumun bu güne düşen kısmı.
    let seconds: TimeInterval

    var body: some View {
        HStack(spacing: Design.small) {
            Circle()
                .fill(PlaceColor.color(for: session.placeID))
                .frame(width: Design.dotSize, height: Design.dotSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(DurationFormat.range(from: session.startedAt, to: session.endedAt))
                    .monospacedDigit()
                if showsPlace {
                    Text(placeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Design.small)

            if isCurrent {
                Text("sürüyor")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Text(DurationFormat.readable(seconds))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
```

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/DailyChartView.swift`:

```swift
import Charts
import PlaceTimerCore
import SwiftUI

/// Haftanın ya da ayın günleri, yerlere göre yığılmış çubuklar. Renk yerin
/// rengi: paneldeki nokta ve gün şeridiyle aynı dil.
struct DailyChartView: View {
    let days: [DayTotal]
    let scope: StatsScope

    var body: some View {
        Chart {
            ForEach(days) { day in
                ForEach(day.shares) { share in
                    BarMark(
                        x: .value("Gün", day.day, unit: .day),
                        y: .value("Saat", share.seconds / 3600)
                    )
                    .foregroundStyle(PlaceColor.color(for: share.placeID))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: scope == .week ? 1 : 7)) {
                AxisValueLabel(format: scope == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let saat = value.as(Double.self) { Text("\(Int(saat))sa") }
                }
            }
        }
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .accessibilityLabel("Günlük süre grafiği")
    }
}
```

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/StatsSummaryView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Dönemin büyük toplamı, önceki dönemle farkı ve grafiği.
struct StatsSummaryView: View {
    let coordinator: AppCoordinator
    let period: StatsPeriod

    var body: some View {
        let now = Date()
        let total = coordinator.totalSeconds(in: period)

        VStack(alignment: .leading, spacing: Design.medium) {
            VStack(alignment: .leading, spacing: Design.tight) {
                Text(period.title(now: now))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(DurationFormat.readable(total))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let comparison = comparisonText(total: total, now: now) {
                    Text(comparison)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if period.scope == .day {
                let segments = coordinator.segments(on: period.interval.start)
                if !segments.isEmpty {
                    DayStripView(segments: segments, now: min(now, period.interval.end), height: 14)
                }
            } else {
                DailyChartView(days: coordinator.dailyTotals(in: period), scope: period.scope)
                    .frame(height: 160)
            }
        }
        .padding(.vertical, Design.small)
    }

    private func comparisonText(total: TimeInterval, now: Date) -> String? {
        let previous = coordinator.previousTotalSeconds(for: period)
        guard previous > 0 || total > 0 else { return nil }
        let diff = total - previous
        guard abs(diff) >= 60 else { return "Önceki dönemle aynı" }

        let label: String
        switch (period.scope, period.contains(now)) {
        case (.day, true): label = "Dünün bu saatinden"
        case (.week, true): label = "Geçen haftanın bu anından"
        case (.month, true): label = "Geçen ayın bu anından"
        case (.day, false): label = "Önceki günden"
        case (.week, false): label = "Önceki haftadan"
        case (.month, false): label = "Önceki aydan"
        }
        let amount = DurationFormat.readable(abs(diff))
        return "\(label) \(amount) \(diff > 0 ? "fazla" : "az")"
    }
}
```

- [ ] **Step 4: Öneri satırı ve düzenleme sayfası**

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/SuggestionRow.swift`:

```swift
import PlaceTimerCore
import SwiftUI

struct SuggestionRow: View {
    let suggestion: Suggestion
    let coordinator: AppCoordinator

    var body: some View {
        let text = SuggestionText.make(suggestion, coordinator: coordinator)

        HStack(alignment: .firstTextBaseline, spacing: Design.medium) {
            Image(systemName: "wand.and.sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(text.title)
                Text(text.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Design.small)
            Button("Yoksay") { coordinator.dismiss(suggestion) }
                .buttonStyle(.glass)
            Button(text.action) { coordinator.apply(suggestion) }
                .buttonStyle(.glassProminent)
        }
        .padding(.vertical, Design.tight)
    }
}
```

Create `Sources/PlaceTimerKit/UI/Settings/Statistics/SessionEditView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Bir oturumun saatini ve yerini düzeltir. Açık oturumun yalnızca
/// başlangıcı değişir: bitişi yok, yerini de otomatik takip yönetiyor.
struct SessionEditView: View {
    let coordinator: AppCoordinator
    @State private var draft: Session
    @State private var end: Date
    private let isCurrent: Bool
    @Environment(\.dismiss) private var dismiss

    init(coordinator: AppCoordinator, session: Session) {
        self.coordinator = coordinator
        _draft = State(initialValue: session)
        _end = State(initialValue: session.endedAt ?? Date())
        isCurrent = session.endedAt == nil
    }

    private var edited: Session {
        var session = draft
        if !isCurrent { session.endedAt = end }
        return session
    }

    var body: some View {
        let error = coordinator.validateEdit(edited)

        Form {
            DatePicker("Başlangıç", selection: $draft.startedAt)
            if !isCurrent {
                DatePicker("Bitiş", selection: $end)
            }
            Picker("Yer", selection: $draft.placeID) {
                Text("Bilinmeyen yer").tag(UUID?.none)
                ForEach(coordinator.knownPlaces) { place in
                    Text(place.displayName).tag(Optional(place.id))
                }
            }
            .disabled(isCurrent)

            if let error {
                Label(EditErrorText.message(error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Vazgeç") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    if coordinator.updateSession(edited) == nil { dismiss() }
                }
                .disabled(error != nil)
            }
        }
    }
}
```

- [ ] **Step 5: Sayfanın kendisi**

`Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift` dosyasının tamamını şununla değiştir:

```swift
import PlaceTimerCore
import SwiftUI

/// Laptopla geçen süre: gün, hafta, ay ve geçmişleri.
///
/// Üstte asıl sorunun cevabı (toplam ve önceki dönemle fark), altında
/// öneriler, yerler ve günlere bölünmüş oturumlar. Dönem seçimi ve gezinme
/// pencerenin cam araç çubuğunda; içerikte kontrol kalabalığı yok.
///
/// Oturumlar `List` içinde: seçim, ⌫ ile silme ve sağ tık menüsü `Form`'da
/// yok. Satır içi "Sil" linkleri bu yüzden kalktı.
struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator

    @State private var scope: StatsScope = .week
    @State private var period = StatsPeriod.containing(Date(), scope: .week)
    @State private var selection: Set<UUID> = []
    @State private var editing: Session?
    @State private var exporting = false
    @State private var editError: SessionHistory.EditError?
    @State private var showsEditError = false

    var body: some View {
        let days = coordinator.sessionDays(in: period)
        let totals = coordinator.totals(in: period)
        let periodTotal = totals.reduce(0) { $0 + $1.totalSeconds }

        List(selection: $selection) {
            Section {
                StatsSummaryView(coordinator: coordinator, period: period)
            }

            if !coordinator.suggestions.isEmpty {
                Section {
                    ForEach(coordinator.suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion, coordinator: coordinator)
                            .selectionDisabled()
                    }
                    if coordinator.offersLongerGap {
                        HStack {
                            Text("Bu aralıkları sık birleştiriyorsun. Ara eşiğini 1 saate çıkarayım mı?")
                                .font(.callout)
                            Spacer()
                            Button("Eşiği 1 saate çıkar", action: coordinator.adoptLongerGap)
                                .buttonStyle(.glass)
                        }
                        .selectionDisabled()
                    }
                } header: {
                    HStack {
                        Text("Öneriler")
                        Spacer()
                        Button("Tümünü uygula", action: coordinator.applyAllSuggestions)
                            .buttonStyle(.link)
                    }
                }
            }

            if !totals.isEmpty {
                Section("Yerler") {
                    ForEach(totals) { total in
                        placeRow(total, of: periodTotal)
                            .selectionDisabled()
                    }
                }
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.sessions) { session in
                        SessionRowView(
                            session: session,
                            placeName: coordinator.placeName(for: session.placeID),
                            showsPlace: day.placeCount > 1,
                            isCurrent: session.id == coordinator.currentSessionID,
                            seconds: overlap(of: session, with: dayInterval(day.day), now: Date())
                        )
                        .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text(StatsPeriod.containing(day.day, scope: .day).title(now: Date()))
                        Spacer()
                        Text(DurationFormat.readable(day.total))
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if days.isEmpty && coordinator.suggestions.isEmpty {
                ContentUnavailableView {
                    Label("Kayıt yok", systemImage: "chart.bar")
                } description: {
                    Text("Bu dönemde henüz bir oturum yok.")
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            sessionMenu(ids)
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first { editing = coordinator.session(id: id) }
        }
        .onDeleteCommand {
            coordinator.deleteSessions(selection)
            selection = []
        }
        .onChange(of: scope) { _, yeni in
            period = .containing(Date(), scope: yeni)
        }
        .toolbar { toolbarContent }
        .sheet(item: $editing) { session in
            SessionEditView(coordinator: coordinator, session: session)
        }
        .fileExporter(
            isPresented: $exporting,
            document: CSVDocument(text: coordinator.csv(in: period)),
            contentType: .commaSeparatedText,
            defaultFilename: "PlaceTimer \(period.title(now: Date()))"
        ) { _ in }
        .onChange(of: editError) { _, yeni in
            showsEditError = yeni != nil
        }
        .alert("Birleştirilemedi", isPresented: $showsEditError, presenting: editError) { _ in
            Button("Tamam", role: .cancel) { editError = nil }
        } message: { error in
            Text(EditErrorText.message(error))
        }
    }

    /// Yaz saati günlerinde 23 ya da 25 saat; sabit 86.400 saniye bir saat
    /// kaydırırdı.
    private func dayInterval(_ day: Date) -> DateInterval {
        Calendar.placeTimer.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86_400)
    }

    /// Seçimde yalnızca açık oturum varsa silinecek bir şey yok.
    private func onlyCurrent(_ ids: Set<UUID>) -> Bool {
        guard let current = coordinator.currentSessionID else { return false }
        return ids == [current]
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Ölçek", selection: $scope) {
                ForEach(StatsScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ControlGroup {
                Button("Önceki", systemImage: "chevron.left") {
                    period = period.shifted(by: -1)
                }
                Button("Sonraki", systemImage: "chevron.right") {
                    period = period.shifted(by: 1)
                }
                .disabled(period.contains(Date()))
            }
            Button("Bugün") {
                period = .containing(Date(), scope: scope)
            }
            .disabled(period.contains(Date()))
            Button("Geri al", systemImage: "arrow.uturn.backward", action: coordinator.undoLastEdit)
                .keyboardShortcut("z")
                .disabled(!coordinator.canUndo)
            Button("Dışa aktar…", systemImage: "square.and.arrow.up") {
                exporting = true
            }
        }
    }

    @ViewBuilder
    private func sessionMenu(_ ids: Set<UUID>) -> some View {
        if ids.count == 1, let id = ids.first {
            Button("Düzenle…") { editing = coordinator.session(id: id) }
            Button("Öncekiyle birleştir") { editError = coordinator.mergeWithPrevious(id) }
                .disabled(coordinator.previousSession(of: id) == nil)
        } else if ids.count > 1 {
            Button("Birleştir") { editError = coordinator.mergeSessions(ids) }
        }
        Divider()
        Button("Sil", role: .destructive) {
            coordinator.deleteSessions(ids)
            selection.subtract(ids)
        }
        .disabled(onlyCurrent(ids))
    }

    private func placeRow(_ total: PlaceTotal, of periodTotal: TimeInterval) -> some View {
        let share = periodTotal > 0 ? total.totalSeconds / periodTotal : 0

        return VStack(alignment: .leading, spacing: Design.tight) {
            HStack(spacing: Design.small) {
                Circle()
                    .fill(PlaceColor.color(for: total.placeID))
                    .frame(width: Design.dotSize, height: Design.dotSize)
                    .accessibilityHidden(true)
                Text(coordinator.placeName(for: total.placeID))
                    .lineLimit(1)
                Spacer(minLength: Design.small)
                Text(DurationFormat.readable(total.totalSeconds))
                    .monospacedDigit()
            }
            ProgressView(value: share)
                .progressViewStyle(.linear)
                .tint(PlaceColor.color(for: total.placeID))
                .accessibilityHidden(true)
            Text("%\(Int((share * 100).rounded())) · \(total.sessionCount) oturum")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Design.tight)
    }
}

#Preview {
    StatisticsSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
```

- [ ] **Step 6: Derle ve görsel doğrula**

Run: `swift build && swift test`
Expected: PASS, uyarı yok.

Run: `Scripts/build-app.sh`, uygulamayı aç, Ayarlar → İstatistik. Kontrol et:
- Araç çubuğunda segmentli Gün/Hafta/Ay, ‹ › ve "Bugün" cam kapsüllerde.
- Hafta görünümünde yığılmış çubuk grafik; gün görünümünde kalın gün şeridi.
- Oturumlar günlere bölünmüş; sağ tık menüsü "Düzenle… / Öncekiyle birleştir / Sil"; ⌫ siliyor; ⌘Z geri alıyor.
- Öneriler bölümü (iki "Home" varsa) görünüyor; "Birleştir" uygulanıyor.
- "Dışa aktar…" kaydetme paneli açıyor ve dosya yazılıyor (sandbox izni).
- Koyu tema ve Erişilebilirlik → "Saydamlığı azalt" açıkken okunur.

- [ ] **Step 7: Commit**

```bash
git add -A Sources Resources/PlaceTimer.entitlements
git commit -m "feat: istatistik sayfasi yeniden; grafik, gecmis donemler, oneriler, duzeltme, CSV

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Panel — gün toplamı, öneri kartı, cam düğmeler

**Files:**
- Modify: `Sources/PlaceTimerKit/UI/PanelSummaryView.swift`, `PanelView.swift`, `PanelHeaderView.swift`, `PlacePromptView.swift`
- Create: `Sources/PlaceTimerKit/UI/PanelSuggestionCard.swift`

**Interfaces:**
- Consumes: `coordinator.todayTotalSeconds`, `placesTodayCount`, `todayHereSeconds`, `suggestions`, `apply`, `dismiss`; `SuggestionText.make`; `PlaceTimerAppDelegate.presentSettings(tab:)`.

- [ ] **Step 1: Özet satırları**

`Sources/PlaceTimerKit/UI/PanelSummaryView.swift` içindeki ikinci `VStack`'in içeriğini şununla değiştir:

```swift
            VStack(alignment: .leading, spacing: Design.tight) {
                LabeledContent(
                    "Bugün toplam",
                    value: DurationFormat.readable(coordinator.todayTotalSeconds)
                )
                // Tek yerli günde "Bugün burada" toplamın aynısı; tekrar etmiyoruz.
                if coordinator.placesTodayCount > 1 {
                    LabeledContent(
                        "Bugün burada",
                        value: DurationFormat.readable(coordinator.todayHereSeconds)
                    )
                }
                if let started = coordinator.sessionStartedAt {
                    LabeledContent("Başlangıç", value: DurationFormat.time(started))
                }
            }
```

Tip yorumunu güncelle: "Büyük sayı bu oturum; altındaki ilk satır asıl soru — bugün laptopla toplam ne kadar."

- [ ] **Step 2: Öneri kartı**

Create `Sources/PlaceTimerKit/UI/PanelSuggestionCard.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Paneldeki tek öneri. Gerçekten yüzen bir şey olduğu için cam: sayaç
/// metninin üstünde, gelip giden bir kart.
struct PanelSuggestionCard: View {
    let suggestion: Suggestion
    let remaining: Int
    let coordinator: AppCoordinator

    var body: some View {
        let text = SuggestionText.make(suggestion, coordinator: coordinator)

        VStack(alignment: .leading, spacing: Design.small) {
            Label(text.title, systemImage: "wand.and.sparkles")
                .font(.subheadline.weight(.semibold))
            Text(text.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Design.small) {
                Button(text.action) { coordinator.apply(suggestion) }
                    .buttonStyle(.glassProminent)
                Button("Yoksay") { coordinator.dismiss(suggestion) }
                    .buttonStyle(.glass)
                Spacer(minLength: 0)
                if remaining > 0 {
                    Button("+\(remaining) öneri") {
                        PlaceTimerAppDelegate.shared?.presentSettings(tab: .istatistik)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .padding(Design.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
```

- [ ] **Step 3: Paneli bağla**

`Sources/PlaceTimerKit/UI/PanelView.swift`:

`@Bindable var coordinator` altına `@Namespace private var glass`.

`if let prompt … else { … }` bloğunu şununla değiştir:

```swift
                if let prompt = coordinator.prompt {
                    PlacePromptView(prompt: prompt, coordinator: coordinator)
                } else {
                    PanelHeaderView(coordinator: coordinator)
                    PanelSummaryView(coordinator: coordinator)

                    GlassEffectContainer {
                        if let suggestion = coordinator.suggestions.first {
                            PanelSuggestionCard(
                                suggestion: suggestion,
                                remaining: coordinator.suggestions.count - 1,
                                coordinator: coordinator
                            )
                            .glassEffectID(suggestion.id, in: glass)
                        }
                    }
                    .animation(.snappy, value: coordinator.suggestions.first?.id)
                }
```

Tip yorumuna ekle: "Cam iki yerde: üstteki düğmeler ve öneri kartı — ikisi de içeriğin üstünde yüzen kontroller."

- [ ] **Step 4: Başlık düğmelerini tek cam grupta topla**

`Sources/PlaceTimerKit/UI/PanelHeaderView.swift` içinde `Menu(...)` ile `Button("Ayarlar"…)` bloğunu şu kapsayıcıya al:

```swift
            GlassEffectContainer(spacing: Design.tight) {
                HStack(spacing: Design.tight) {
                    Menu("Oturum kontrolleri", systemImage: "ellipsis") {
                        // … mevcut menü içeriği aynen …
                    }
                    .labelStyle(.iconOnly)
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button("Ayarlar", systemImage: "gearshape", action: openSettings)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                }
            }
```

- [ ] **Step 5: Yer sorusu düğmeleri**

`Sources/PlaceTimerKit/UI/PlacePromptView.swift`: iki `.buttonStyle(.bordered)` → `.buttonStyle(.glass)`; `Button("Ekle", action: commit)` altına `.buttonStyle(.glassProminent)`.

- [ ] **Step 6: Derle ve görsel doğrula**

Run: `swift build && swift test`
Expected: PASS.

Run: `Scripts/build-app.sh`, menubar panelini aç. Kontrol et: "Bugün toplam" ilk satır; "Aktif" yok; saatler "12:36" biçiminde; iki "Home" varsa öneri kartı camda; "Birleştir" sonrası kart kayboluyor ve bir sonraki öneriye morph ile geçiyor; `•••` ve ⚙︎ tek cam grubunda.

- [ ] **Step 7: Commit**

```bash
git add -A Sources
git commit -m "feat: panelde gun toplami, oneri karti ve tek cam dugme grubu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Sürüm 1.1.0 ve TestFlight

**Files:**
- Modify: `Resources/Info.plist`, `docs/app-store.md`, `docs/superpowers/specs/2026-10-07-place-timer-v3-design.md` (Durum)

- [ ] **Step 1: Sürümü yükselt**

`Resources/Info.plist`: `CFBundleShortVersionString` → `1.1.0`, `CFBundleVersion` → `5`.

- [ ] **Step 2: Temiz derleme ve testler**

Run: `swift test && swift build -Xswiftc -warnings-as-errors`
Expected: PASS, uyarı yok.

- [ ] **Step 3: Yerelde sıfır veriyle ve mevcut veriyle dene**

Run: `Scripts/build-app.sh --fresh` (veri yokken ilk açılış: çökme yok, öneri yok, istatistik boş durumu). Sonra `Scripts/build-app.sh` (mevcut veriyle: 1.0 tercihleri 1.1'e taşındı mı — Genel'de "Ara eşiği" doğru seçenekte mi; iki "Home" önerisi geliyor mu).

- [ ] **Step 4: Mağaza paketini üret**

Önce yayınlanmış Xcode'u ve profili doğrula:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version
mdfind -name "provisionprofile" | grep -i placetimer
```

Xcode sürümü beta değilse ve profil bulunduysa:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  PROFILE="<bulunan profil yolu>" Scripts/build-appstore.sh
```

Expected: `==> Hazir: build/appstore/PlaceTimer.pkg`. Profil yoksa ya da Xcode beta ise dur ve kullanıcıya sor (`docs/app-store.md` §0).

- [ ] **Step 5: Yükle ve TestFlight'a aç**

`ascelerate` skill'ini çağır ve onun yönergesiyle `build/appstore/PlaceTimer.pkg`'yi App Store Connect'e yükle; derleme işlendikten sonra 1.1.0 (5)'i dahili test grubuna ekle. Skill çalışmazsa Transporter.app ile yükle ve TestFlight'ı App Store Connect web arayüzünden aç.

Bu adım dışa dönük bir eylemdir: yüklemeden hemen önce kullanıcıya "1.1.0 (5) App Store Connect'e yükleniyor" diye bildir.

- [ ] **Step 6: Belgeleri güncelle ve commit**

`docs/app-store.md` "Gönderim öncesi son gözden geçirme" listesinin altına bir kayıt ekle: "1.1.0 (5) TestFlight'a yüklendi — <tarih>". Spec'in `**Durum:**` satırını "Uygulandı, TestFlight'ta" yap.

```bash
git add Resources/Info.plist docs
git commit -m "chore: 1.1.0 (5) TestFlight'a yuklendi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
