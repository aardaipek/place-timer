# PlaceTimer v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PlaceTimer'a görünür ve müdahale edilebilir bir yüz kazandırmak — Liquid Glass arayüz, dört sekmeli ayarlar penceresi, yer yönetimi, manuel kontrol, gün şeridi ve istatistik.

**Architecture:** Yeni mantığın tamamı `PlaceTimerCore` içinde saf değer tipleri ve saf fonksiyonlar olarak yazılır; sistem çerçevelerine dokunmaz ve zaman dışarıdan geçirilir, dolayısıyla eksiksiz testlenir. `PlaceTimerKit` bu çekirdeği SwiftUI'ye bağlar. Ayarlar `preferences.json`'a yazılan bir değer tipidir ve motorun yapılandırmasını çalışırken günceller.

**Tech Stack:** Swift 6.4, SwiftUI (macOS 26 Liquid Glass), Swift Testing, SwiftPM, Core Graphics (simge üretimi), `iconutil`.

**Spec:** `docs/superpowers/specs/2026-09-05-place-timer-v2-design.md`

## Global Constraints

- **Minimum macOS 26.** `Package.swift` → `platforms: [.macOS(.v26)]` **ve** `// swift-tools-version: 6.2`. `.v26` sabiti `@available(_PackageDescription 6.2)` ile kilitli; tools-version 6.0'da `'v26' is unavailable` hatası verir. Liquid Glass API'leri (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `.glassProminent`) bu sürümde geldi.
- **Tüm `swift` komutları** `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` öneki ile çalıştırılır. Makinede `xcode-select` hâlâ Command Line Tools'u gösteriyor; `sudo` gerekmez.
- **`PlaceTimerCore` hiçbir sistem çerçevesi import etmez.** Yalnızca `Foundation`. AppKit, SwiftUI, CoreLocation, CoreWLAN, MapKit yasak — bu hedefin testlenebilirliğinin tek güvencesi budur.
- **Derleme uyarısız olmalı:** `swift build -Xswiftc -warnings-as-errors` temiz geçmeli. Swift 6 strict concurrency açık.
- **Kullanıcıya görünen tüm metinler Türkçe.** Kod yorumları da Türkçe ve mevcut üslupla aynı: *ne* yaptığını değil *neden* öyle olduğunu anlatır.
- **Testler Swift Testing ile** (`import Testing`, `@Suite`, `@Test`, `#expect`). Suite ve test adları Türkçe cümlelerdir.
- **Commit mesajları ASCII** (mevcut depo düzeni), Türkçe metin, sonunda:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
  ```
- **Her görev kendi testleriyle birlikte commit edilir.** Testler geçmeden commit yok.

## Mevcut Kod Haritası

Yeni gelen bir mühendisin bilmesi gerekenler:

| Dosya | Sorumluluk |
|---|---|
| `Sources/PlaceTimerCore/Models.swift` | `Place`, `Session`, `PlaceRef`, `SessionEvent`, `SessionEffect`, `EngineConfiguration` |
| `Sources/PlaceTimerCore/SessionEngine.swift` | Oturum durum makinesi. `handle(_:at:) -> [SessionEffect]` |
| `Sources/PlaceTimerCore/PlaceCatalog.swift` | Yer listesi ve SSID eşleme kuralları |
| `Sources/PlaceTimerCore/Coordinate.swift` | `Coordinate` + haversine mesafe |
| `Sources/PlaceTimerCore/Storage/JSONFileStore.swift` | Atomik JSON okuma/yazma, `URL.placeTimerSupportDirectory()` |
| `Sources/PlaceTimerCore/Storage/AppState.swift` | `AppState`, `SessionEngine.restored(from:configuration:now:)` |
| `Sources/PlaceTimerKit/AppCoordinator.swift` | Tek durum sahibi; motoru, servisleri ve diski bağlar |
| `Sources/PlaceTimerKit/UI/PanelView.swift` | Menubar paneli |
| `Sources/PlaceTimerKit/UI/OnboardingView.swift` | Karşılama sihirbazı |
| `Sources/PlaceTimerKit/UI/Formatters.swift` | `DurationFormat` |
| `Sources/PlaceTimerKit/PlaceTimerScene.swift` | `MenuBarExtra` sahnesi + `PlaceTimerAppDelegate` |
| `Scripts/build-app.sh` | `.app` paketleme ve imzalama |

Mevcut testler: `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`, `PlaceCatalogTests.swift`. Toplam 31 test.

## Dosya Yapısı

**Oluşturulacak:**

| Dosya | Sorumluluk |
|---|---|
| `Sources/PlaceTimerCore/Preferences.swift` | `Preferences`, `NotificationInterval` |
| `Sources/PlaceTimerCore/ManualPlaceSelection.swift` | Manuel yer seçiminin ne zaman geçerli olduğu kuralı |
| `Sources/PlaceTimerCore/Statistics.swift` | `PlaceTotal`, `StatsRange`, `placeTotals`, `DaySegment`, `daySegments` |
| `Sources/PlaceTimerKit/UI/SettingsView.swift` | Dört sekmeli ayarlar penceresi kabuğu |
| `Sources/PlaceTimerKit/UI/Settings/GeneralSettingsView.swift` | Genel sekmesi |
| `Sources/PlaceTimerKit/UI/Settings/PlacesSettingsView.swift` | Yerler sekmesi |
| `Sources/PlaceTimerKit/UI/Settings/PermissionsSettingsView.swift` | İzinler sekmesi |
| `Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift` | İstatistik sekmesi |
| `Sources/PlaceTimerKit/UI/DayStripView.swift` | Gün şeridi çizimi |
| `Sources/PlaceTimerKit/UI/PlaceColor.swift` | Yer kimliğinden kararlı renk üretimi |
| `Scripts/make-icon.swift` | Simgeyi Core Graphics ile çizer |
| `Scripts/make-icon.sh` | Tüm boyutları üretir, `iconutil` ile `.icns` yapar |
| `Tests/PlaceTimerCoreTests/PreferencesTests.swift` | |
| `Tests/PlaceTimerCoreTests/ManualPlaceSelectionTests.swift` | |
| `Tests/PlaceTimerCoreTests/StatisticsTests.swift` | |

**Değişecek:** `Package.swift`, `Models.swift`, `SessionEngine.swift`, `PlaceCatalog.swift`, `AppCoordinator.swift`, `PanelView.swift`, `Formatters.swift`, `PlaceTimerScene.swift`, `Notifier.swift`, `Resources/Info.plist`, `Scripts/build-app.sh`, `SessionEngineTests.swift`, `PlaceCatalogTests.swift`.

`PanelView.swift` 9. görevde tamamen yeniden yazılır; şu haliyle başlık, sayaç, liste ve altbilgiyi tek dosyada tutuyor ve gün şeridi eklenince taşacak. Gün şeridi ve renk üretimi ayrı dosyalara çıkar.

---

### Task 1: macOS 26 hedefi ve Preferences

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PlaceTimerCore/Preferences.swift`
- Test: `Tests/PlaceTimerCoreTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: `JSONFileStore<Value>` (mevcut)
- Produces: `Preferences` (tüm alanlar `var`, varsayılanlı `init`), `NotificationInterval` (`.off`, `.every30Minutes`, `.hourly`; `var seconds: TimeInterval?`)

- [ ] **Step 1: Dağıtım hedefini yükselt**

`Package.swift` içinde iki satır — ilk satırdaki tools-version da yükselmeli,
`.v26` sabiti `@available(_PackageDescription 6.2)` ile kilitli:

```swift
// swift-tools-version: 6.2
...
platforms: [.macOS(.v26)],
```

- [ ] **Step 2: Derlemenin hâlâ geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build`
Expected: `Build complete!`

- [ ] **Step 3: Başarısız testi yaz**

`Tests/PlaceTimerCoreTests/PreferencesTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Tercihler")
struct PreferencesTests {

    @Test("Varsayılanlar v1 davranışını korur")
    func defaultsMatchV1() {
        let prefs = Preferences()

        #expect(prefs.showSeconds == false)
        #expect(prefs.showPlaceNameInMenuBar == true)
        #expect(prefs.sessionResetSleepThreshold == 3600)
        #expect(prefs.idleThreshold == 300)
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
        prefs.idleThreshold = 120

        let store = JSONFileStore<Preferences>(url: url)
        try store.save(prefs)

        #expect(try store.load() == prefs)
    }

    @Test("Eksik alanlar varsayılanla dolar")
    func partialJSONDecodes() throws {
        // Ileride yeni bir ayar eklendiginde eski dosya bozulmamali.
        let json = Data(#"{"showSeconds": true}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)

        #expect(decoded.showSeconds == true)
        #expect(decoded.notificationInterval == .hourly)
        #expect(decoded.idleThreshold == 300)
    }
}
```

- [ ] **Step 4: Testin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter Tercihler`
Expected: FAIL — `cannot find 'Preferences' in scope`

- [ ] **Step 5: Preferences'ı yaz**

`Sources/PlaceTimerCore/Preferences.swift`:

```swift
import Foundation

/// Saat başı bildirimin sıklığı.
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
```

- [ ] **Step 6: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter Tercihler`
Expected: PASS — 4 test

- [ ] **Step 7: Tüm testleri ve uyarısız derlemeyi doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors`
Expected: 35 test geçer, derleme uyarısız

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources/PlaceTimerCore/Preferences.swift Tests/PlaceTimerCoreTests/PreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat: Preferences tipi ve macOS 26 hedefi

Esikler ve gorunum secenekleri artik degistirilebilir bir deger tipinde.
Eksik alanlar varsayilana duser; ileride yeni ayar eklendiginde kullanicinin
mevcut dosyasi bozulmaz.

Dagitim hedefi macOS 26: Liquid Glass API'leri bu surumde geldi.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 2: Bildirim aralığının genelleşmesi

Saatlik sabit işaretler yerine ayarlanabilir aralık. `Session.notifiedHourMarks` → `notifiedMarks`, eski JSON anahtarı okunmaya devam eder.

**Files:**
- Modify: `Sources/PlaceTimerCore/Models.swift`
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift:handleTick`
- Modify: `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift:handle(effects:)`
- Modify: `Sources/PlaceTimerKit/Notifier.swift`

**Interfaces:**
- Consumes: `NotificationInterval` (Task 1)
- Produces:
  - `Session.notifiedMarks: Set<Int>`
  - `EngineConfiguration.notificationInterval: TimeInterval?`
  - `SessionEffect.markReached(index: Int, elapsed: TimeInterval, placeID: UUID?)` — `hourMarkReached` yerine geçer
  - `Notifier.notifyMark(elapsed: TimeInterval, placeName: String)`

- [ ] **Step 1: Başarısız testleri yaz**

`Tests/PlaceTimerCoreTests/SessionEngineTests.swift` içindeki `hourMarksFireExactlyOnce`, `hourMarksCatchUpAfterSleep`, `hourMarksResetWithNewSession`, `restoresPersistedSession` testlerinde `.hourMarkReached(hours: N, placeID: p)` yerine `.markReached(index: N, elapsed: TimeInterval(N) * 3600, placeID: p)` yaz ve `notifiedHourMarks:` etiketini `notifiedMarks:` yap. Ardından aşağıdaki yeni suite'i **aynı dosyanın sonuna** ekle:

```swift
@Suite("Bildirim aralığı")
struct NotificationIntervalTests {

    private func engine(interval: TimeInterval?) -> SessionEngine {
        SessionEngine(
            configuration: EngineConfiguration(notificationInterval: interval)
        )
    }

    @Test("Kapalıyken hiç işaret üretilmez")
    func offProducesNothing() {
        var motor = engine(interval: nil)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(60)).isEmpty)
        #expect(motor.handle(.tick(idleSeconds: 0), at: at(180)).isEmpty)
        #expect(motor.currentSession?.notifiedMarks.isEmpty == true)
    }

    @Test("30 dakikalık aralık her yarım saatte bir düşer")
    func halfHourlyMarks() {
        var motor = engine(interval: 30 * 60)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(29)).isEmpty)

        let ilk = motor.handle(.tick(idleSeconds: 0), at: at(30))
        #expect(ilk == [.markReached(index: 1, elapsed: 30 * 60, placeID: kafe)])

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(45)).isEmpty)

        let ikinci = motor.handle(.tick(idleSeconds: 0), at: at(60))
        #expect(ikinci == [.markReached(index: 2, elapsed: 60 * 60, placeID: kafe)])
    }

    @Test("İşaretin bildirdiği süre gerçek geçen süredir")
    func markCarriesElapsed() {
        var motor = engine(interval: 30 * 60)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        // 95. dakikada ilk kez tick geliyor: 3 isaret birikmis.
        let etkiler = motor.handle(.tick(idleSeconds: 0), at: at(95))

        #expect(etkiler.count == 3)
        #expect(etkiler[0] == .markReached(index: 1, elapsed: 30 * 60, placeID: kafe))
        #expect(etkiler[2] == .markReached(index: 3, elapsed: 90 * 60, placeID: kafe))
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Bildirim aralığı"`
Expected: FAIL — derleme hatası, `markReached` ve `notificationInterval` yok

- [ ] **Step 3: Modelleri güncelle**

`Sources/PlaceTimerCore/Models.swift` içinde `Session`:

```swift
public struct Session: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var placeID: UUID?
    public let startedAt: Date
    public var endedAt: Date?
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
```

Aynı dosyada `SessionEffect`:

```swift
public enum SessionEffect: Sendable, Equatable {
    case sessionStarted(Session)
    case sessionEnded(Session)
    /// `index` kaçıncı aralık, `elapsed` o anda yerde geçen toplam süre.
    /// Bildirim metni süreyi yazacağı için ham indeksi tek başına taşımak yetmez.
    case markReached(index: Int, elapsed: TimeInterval, placeID: UUID?)
}
```

Aynı dosyada `EngineConfiguration`:

```swift
public struct EngineConfiguration: Sendable, Equatable {
    public var sessionResetSleepThreshold: TimeInterval
    public var idleThreshold: TimeInterval
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
```

- [ ] **Step 4: Motorun tick işleyicisini güncelle**

`Sources/PlaceTimerCore/SessionEngine.swift` içinde `handleTick`'in işaret üreten bölümünü değiştir:

```swift
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
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 38 test

- [ ] **Step 6: Bildirimciyi ve koordinatörü uyarla**

`Sources/PlaceTimerKit/Notifier.swift` içinde `notifyHourMark` yerine:

```swift
    public func notifyMark(elapsed: TimeInterval, placeName: String) {
        let content = UNMutableNotificationContent()
        content.title = placeName
        content.body = "\(DurationFormat.readable(elapsed)) oldu."
        content.sound = .default

        center.add(
            UNNotificationRequest(
                identifier: "mark-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        )
    }
```

`Sources/PlaceTimerKit/AppCoordinator.swift` içinde `handle(effects:)`:

```swift
            case .markReached(_, let elapsed, let placeID):
                notifier.notifyMark(
                    elapsed: elapsed,
                    placeName: placeName(for: placeID)
                )
```

- [ ] **Step 7: Uyarısız derlemeyi doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors`
Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: bildirim araligi ayarlanabilir oldu

Saatlik sabit isaretler yerine yapilandirilabilir aralik: kapali,
30 dakika veya saatlik. Isaret artik gecen sureyi de tasiyor, boylece
bildirim metni "1sa 30dk oldu" diyebiliyor.

Session.notifiedHourMarks -> notifiedMarks. Eski anahtar ayri bir key
kumesinden okunmaya devam ediyor; mevcut state.json bozulmuyor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 3: Yapılandırmanın çalışırken güncellenmesi

**Files:**
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift`
- Modify: `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`

**Interfaces:**
- Consumes: `EngineConfiguration` (Task 2)
- Produces: `SessionEngine.updateConfiguration(_ configuration: EngineConfiguration, at now: Date)`

- [ ] **Step 1: Başarısız testleri yaz**

`SessionEngineTests.swift` sonuna:

```swift
@Suite("Yapılandırma değişimi")
struct ConfigurationUpdateTests {

    @Test("Açık oturum ve sayaçlar korunur")
    func openSessionSurvives() {
        var motor = SessionEngine()
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))
        advance(&motor, from: at(0), seconds: 30)

        let oturum = motor.currentSession?.id
        let aktif = motor.activeSeconds

        motor.updateConfiguration(
            EngineConfiguration(idleThreshold: 120), at: at(1)
        )

        #expect(motor.currentSession?.id == oturum)
        #expect(motor.activeSeconds == aktif)
        #expect(motor.configuration.idleThreshold == 120)
    }

    @Test("Aralık kısalınca birikmiş bildirimler topluca düşmez")
    func shorteningIntervalDoesNotBurst() {
        var motor = SessionEngine(
            configuration: EngineConfiguration(notificationInterval: 3600)
        )
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))
        motor.handle(.tick(idleSeconds: 0), at: at(90))   // 1. saat isareti dustu

        // Kullanici 30 dakikaliga geciyor. 90 dakikada 3 isaret var ama
        // gecmise donuk 3 bildirim atmak sacma olurdu.
        motor.updateConfiguration(
            EngineConfiguration(notificationInterval: 1800), at: at(90)
        )

        #expect(motor.currentSession?.notifiedMarks == [1, 2, 3])
        #expect(motor.handle(.tick(idleSeconds: 0), at: at(100)).isEmpty)

        // Bir sonraki gercek isaret 120. dakikada.
        let sonraki = motor.handle(.tick(idleSeconds: 0), at: at(120))
        #expect(sonraki == [.markReached(index: 4, elapsed: 4 * 1800, placeID: kafe)])
    }

    @Test("Bildirim kapatılınca işaret üretimi durur")
    func turningOffStopsMarks() {
        var motor = SessionEngine(
            configuration: EngineConfiguration(notificationInterval: 3600)
        )
        motor.handle(.wake, at: at(0))
        motor.updateConfiguration(
            EngineConfiguration(notificationInterval: nil), at: at(10)
        )

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(120)).isEmpty)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Yapılandırma değişimi"`
Expected: FAIL — `value of type 'SessionEngine' has no member 'updateConfiguration'`

- [ ] **Step 3: `configuration`'ı değişebilir yap ve güncelleyiciyi ekle**

`SessionEngine.swift` içinde `public let configuration: EngineConfiguration` satırını değiştir:

```swift
    public private(set) var configuration: EngineConfiguration
```

Ve `elapsed(at:)`'in hemen altına ekle:

```swift
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
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 41 test

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: motor yapilandirmasi calisirken guncellenebiliyor

Ayar degistiginde acik oturum, sayaclar ve gonderilmis isaretler korunuyor.
Bildirim araligi degisirse gecmis isaretler dolu sayiliyor; yoksa saatlikten
30 dakikaliga gecildiginde birikmis bildirimler topluca duserdi.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 4: Oturumu bitirme olayı

**Files:**
- Modify: `Sources/PlaceTimerCore/Models.swift` (`SessionEvent`)
- Modify: `Sources/PlaceTimerCore/SessionEngine.swift`
- Modify: `Tests/PlaceTimerCoreTests/SessionEngineTests.swift`

**Interfaces:**
- Produces: `SessionEvent.endSessionRequested`

- [ ] **Step 1: Başarısız testi yaz**

`SessionEngineTests.swift` sonuna:

```swift
@Suite("Manuel oturum bitirme")
struct EndSessionTests {

    @Test("Oturum kapanır ve aynı yerde yenisi açılır")
    func endStartsFreshSessionSamePlace() {
        var motor = SessionEngine()
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))
        let eski = motor.currentSession?.id

        let etkiler = motor.handle(.endSessionRequested, at: at(45))

        #expect(etkiler.count == 2)
        guard case .sessionEnded(let kapanan) = etkiler[0] else {
            Issue.record("once kapanis beklenir"); return
        }
        #expect(kapanan.id == eski)
        #expect(kapanan.endedAt == at(45))

        guard case .sessionStarted(let yeni) = etkiler[1] else {
            Issue.record("sonra yeni oturum beklenir"); return
        }
        #expect(yeni.startedAt == at(45))
        #expect(yeni.placeID == kafe)
        #expect(motor.elapsed(at: at(45)) == 0)
    }

    @Test("Yeni oturum bildirim işaretlerini sıfırdan sayar")
    func marksResetAfterManualEnd() {
        var motor = SessionEngine()
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))
        motor.handle(.tick(idleSeconds: 0), at: at(70))   // 1. saat dustu

        motor.handle(.endSessionRequested, at: at(70))

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(120)).isEmpty)
        let etkiler = motor.handle(.tick(idleSeconds: 0), at: at(131))
        #expect(etkiler == [.markReached(index: 1, elapsed: 3600, placeID: kafe)])
    }

    @Test("Açık oturum yokken bir şey olmaz")
    func endWithoutSessionIsHarmless() {
        var motor = SessionEngine()
        #expect(motor.handle(.endSessionRequested, at: at(0)).isEmpty)
        #expect(motor.currentSession == nil)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Manuel oturum bitirme"`
Expected: FAIL — `type 'SessionEvent' has no member 'endSessionRequested'`

- [ ] **Step 3: Olayı ekle**

`Models.swift` içinde `SessionEvent`'e:

```swift
    /// Kullanıcı sayacı elle sıfırladı: oturum kapanır, aynı yerde yenisi açılır.
    case endSessionRequested
```

`SessionEngine.swift` içinde `handle(_:at:)`'in `switch`'ine:

```swift
        case .endSessionRequested:
            return handleEndSessionRequested(at: now)
```

Ve olay işleyicileri bölümüne:

```swift
    /// Oturumu kapatıp aynı yerde hemen yenisini açar.
    ///
    /// Takibi büsbütün durdurmuyoruz: otomatik bir takipçinin izlemeyi
    /// bırakması tuhaf olurdu. Amaç yanlış başlamış bir sayacı düzeltmek.
    private mutating func handleEndSessionRequested(at now: Date) -> [SessionEffect] {
        guard currentSession != nil else { return [] }
        var effects = endSession(at: now)
        effects.append(startSession(at: now))
        return effects
    }
```

`startSession(at:placeID:)` yerini `currentPlace`'ten okuduğu için yeni oturum aynı yerde açılır.

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 44 test

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: oturumu elle bitirme olayi

Oturum kapanip ayni yerde hemen yenisi aciliyor: pratikte "sayaci sifirla".
Takibi tamamen durdurmuyoruz, otomatik bir takipcinin izlemeyi birakmasi
tuhaf olurdu.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 5: Manuel yer seçimi kuralı

Manuel seçim koordinatörde tutulacak ama *ne zaman geçerli olduğu* saf bir kuraldır ve testlenmelidir.

**Files:**
- Create: `Sources/PlaceTimerCore/ManualPlaceSelection.swift`
- Test: `Tests/PlaceTimerCoreTests/ManualPlaceSelectionTests.swift`

**Interfaces:**
- Produces: `ManualPlaceSelection(placeID:ssid:)`, `func applies(to observedSSID: String?) -> Bool`

- [ ] **Step 1: Başarısız testi yaz**

`Tests/PlaceTimerCoreTests/ManualPlaceSelectionTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ofis = UUID()

@Suite("Manuel yer seçimi")
struct ManualPlaceSelectionTests {

    @Test("Aynı ağ üzerinde geçerli kalır")
    func staysOnSameNetwork() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: "Kafe-Misafir"))
    }

    @Test("Ağ değişince düşer")
    func dropsWhenNetworkChanges() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: "Baska-Ag") == false)
    }

    @Test("Ağ kesilince düşer")
    func dropsWhenNetworkDisappears() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: nil) == false)
    }

    @Test("Wi-Fi yokken yapılan seçim ağsız kaldıkça geçerlidir")
    func offlineSelectionSurvivesWhileOffline() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: nil)
        #expect(secim.applies(to: nil))
    }

    @Test("Wi-Fi yokken yapılan seçim ilk ağ görülünce düşer")
    func offlineSelectionDropsOnFirstNetwork() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: nil)
        #expect(secim.applies(to: "Herhangi-Ag") == false)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Manuel yer seçimi"`
Expected: FAIL — `cannot find 'ManualPlaceSelection' in scope`

- [ ] **Step 3: Tipi yaz**

`Sources/PlaceTimerCore/ManualPlaceSelection.swift`:

```swift
import Foundation

/// Kullanıcının "burası aslında şurası" düzeltmesi.
///
/// Seçim bir ağa bağlanır: aynı ağda kaldığın sürece otomatik eşleşmeyi
/// bastırır. Böyle bir bağ olmasaydı seçim, 10 saniyelik ağ yoklamasının ilk
/// turunda kendiliğinden geri alınırdı.
public struct ManualPlaceSelection: Sendable, Equatable {
    public let placeID: UUID
    /// Seçimin yapıldığı andaki ağ. `nil`, seçimin Wi-Fi yokken yapıldığını
    /// gösterir; o durumda ilk ağ görülene kadar geçerli kalır.
    public let ssid: String?

    public init(placeID: UUID, ssid: String?) {
        self.placeID = placeID
        self.ssid = ssid
    }

    public func applies(to observedSSID: String?) -> Bool {
        ssid == observedSSID
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 49 test

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: manuel yer secimi kurali

Secim yapildigi andaki aga baglanir ve o agda kalindigi surece otomatik
eslesmeyi bastirir. Bag olmasaydi secim 10 saniyelik ag yoklamasinin ilk
turunda geri alinirdi.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 6: Yer yönetimi mutasyonları ve görünen ad

**Files:**
- Modify: `Sources/PlaceTimerCore/PlaceCatalog.swift`
- Modify: `Tests/PlaceTimerCoreTests/PlaceCatalogTests.swift`
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift:placeName(for:)`

**Interfaces:**
- Produces:
  - `PlaceCatalog.remove(_ placeID: UUID)`
  - `PlaceCatalog.detach(ssid: String, from placeID: UUID)`
  - `PlaceCatalog.displayName(for placeID: UUID?) -> String`

- [ ] **Step 1: Başarısız testleri yaz**

`PlaceCatalogTests.swift` içindeki `@Suite("Yer eşleme")` bloğunun sonuna ekle:

```swift
    @Test("Silinen yer artık eşleşmez")
    func removedPlaceStopsMatching() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.remove(ev.id)

        #expect(catalog.places.isEmpty)
        #expect(
            catalog.resolve(ssid: "TURKSAT-DDBB", coordinate: evKoordinati)
                == .unknownNetwork(nearby: [])
        )
    }

    @Test("SSID ayrılınca o ağ eşleşmez ama yer durur")
    func detachedSSIDStopsMatchingButPlaceRemains() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB", "TURKSAT-DDBB-5G"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.detach(ssid: "TURKSAT-DDBB-5G", from: ev.id)

        #expect(catalog.place(id: ev.id)?.ssids == ["TURKSAT-DDBB"])
        guard case .matched = catalog.resolve(
            ssid: "TURKSAT-DDBB", coordinate: evKoordinati
        ) else {
            Issue.record("kalan SSID hala eslesmeli"); return
        }
        guard case .unknownNetwork = catalog.resolve(
            ssid: "TURKSAT-DDBB-5G", coordinate: evKoordinati
        ) else {
            Issue.record("ayrilan SSID eslesmemeli"); return
        }
    }

    @Test("Son SSID'si ayrılan yer katalogda kalır")
    func placeSurvivesLosingLastSSID() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.detach(ssid: "TURKSAT-DDBB", from: ev.id)

        // Silme ile ayirma farkli islemler: yer duruyor, sadece agsiz kaldi.
        #expect(catalog.place(id: ev.id)?.ssids.isEmpty == true)
        #expect(catalog.places.count == 1)
    }

    @Test("Görünen ad üç durumu ayırır")
    func displayNameDistinguishesThreeCases() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        let catalog = PlaceCatalog(places: [ev])

        #expect(catalog.displayName(for: ev.id) == "Ev")
        #expect(catalog.displayName(for: nil) == "Bilinmeyen yer")
        #expect(catalog.displayName(for: UUID()) == "Silinmiş yer")
    }
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Yer eşleme"`
Expected: FAIL — `remove`, `detach`, `displayName` yok

- [ ] **Step 3: Mutasyonları ve görünen adı ekle**

`PlaceCatalog.swift` içinde `rename`'in altına:

```swift
    public mutating func remove(_ placeID: UUID) {
        places.removeAll { $0.id == placeID }
    }

    /// Bir ağı yerden ayırır. Yerin son SSID'si olsa bile yer silinmez —
    /// silmek ile ayırmak farklı işlemlerdir; kullanıcı hangisini istediğini
    /// kendisi söyler.
    public mutating func detach(ssid: String, from placeID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].ssids.remove(ssid)
    }

    /// Bir oturumun yer adı. Üç durum ayrı ayrı adlandırılır: yer hiç
    /// bilinmiyordu, yer sonradan silindi, ya da yer duruyor. Silinmiş bir yeri
    /// sessizce "Bilinmeyen yer"e karıştırmak geçmişi yanlış anlatırdı.
    public func displayName(for placeID: UUID?) -> String {
        guard let placeID else { return "Bilinmeyen yer" }
        return place(id: placeID)?.displayName ?? "Silinmiş yer"
    }
```

- [ ] **Step 4: Koordinatörü kataloğa devret**

`Sources/PlaceTimerKit/AppCoordinator.swift` içindeki `placeName(for:)` gövdesini değiştir:

```swift
    public func placeName(for placeID: UUID?) -> String {
        catalog.displayName(for: placeID)
    }
```

- [ ] **Step 5: Testlerin geçtiğini ve derlemenin temiz olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors`
Expected: PASS — 53 test, derleme uyarısız

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: yer silme, SSID ayirma ve "Silinmis yer"

Silinen bir yere isaret eden gecmis oturumlar artik "Silinmis yer" olarak
gorunuyor; bunlari sessizce "Bilinmeyen yer"e karistirmak gecmisi yanlis
anlatirdi.

Silmek ile SSID ayirmak farkli islemler: son agi ayrilan bir yer katalogda
kaliyor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 7: İstatistik ve gün şeridi hesaplamaları

**Files:**
- Create: `Sources/PlaceTimerCore/Statistics.swift`
- Test: `Tests/PlaceTimerCoreTests/StatisticsTests.swift`

**Interfaces:**
- Produces:
  - `PlaceTotal(placeID:totalSeconds:activeSeconds:sessionCount:)` — `Identifiable`, `var id: String { placeID?.uuidString ?? "bilinmeyen" }`
  - `StatsRange` (`.today`, `.week`, `.month`)
  - `placeTotals(from:range:now:calendar:) -> [PlaceTotal]`
  - `DaySegment(placeID:start:end:)` — `Identifiable`, `id` = `start`
  - `daySegments(from:on:calendar:) -> [DaySegment]`

- [ ] **Step 1: Başarısız testleri yaz**

`Tests/PlaceTimerCoreTests/StatisticsTests.swift`:

```swift
import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()

/// Testlerin makinenin bölgesel ayarlarından etkilenmemesi için sabit takvim.
private var takvim: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    calendar.firstWeekday = 2   // Pazartesi
    return calendar
}

private func gun(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
    takvim.date(
        from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )
    )!
}

private func oturum(
    _ placeID: UUID?,
    from start: Date,
    to end: Date?,
    active: TimeInterval = 0
) -> Session {
    Session(placeID: placeID, startedAt: start, endedAt: end, activeSeconds: active)
}

@Suite("Yer toplamları")
struct PlaceTotalsTests {

    // 2026-09-09 Carsamba. Hafta pazartesi 7'sinde basliyor.
    private let simdi = gun(9, 15)

    // 9 Eylul 2026 Carsamba; takvim haftasi Pazartesi 7'sinde basliyor.
    private var oturumlar: [Session] {
        [
            oturum(ev, from: gun(9, 9), to: gun(9, 11), active: 3600),    // bugun 2sa
            oturum(kafe, from: gun(9, 12), to: gun(9, 14), active: 5400), // bugun 2sa
            oturum(ev, from: gun(7, 9), to: gun(7, 13), active: 7200),    // Pzt, bu hafta 4sa
            oturum(ev, from: gun(2, 9), to: gun(2, 12), active: 3600),    // gecen hafta, bu ay 3sa
            oturum(kafe, from: gun(28, 9, month: 8), to: gun(28, 12, month: 8)), // gecen ay
        ]
    }

    @Test("Bugün yalnızca bugünün oturumlarını sayar")
    func todayOnly() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.count == 2)
        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 2 * 3600)
        #expect(toplamlar.first { $0.placeID == kafe }?.totalSeconds == 2 * 3600)
    }

    @Test("Hafta takvim haftasıdır, kayan 7 gün değil")
    func weekIsCalendarWeek() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .week, now: simdi, calendar: takvim
        )

        // Pazartesi 7 + Carsamba 9 = 6 saat ev; 2 eylul haftaya girmez.
        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 6 * 3600)
        #expect(toplamlar.first { $0.placeID == ev }?.sessionCount == 2)
    }

    @Test("Ay takvim ayıdır")
    func monthIsCalendarMonth() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .month, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 9 * 3600)
        // 28 agustos eylul ayina girmez.
        #expect(toplamlar.first { $0.placeID == kafe }?.totalSeconds == 2 * 3600)
    }

    @Test("Toplam süreye göre azalan sıralanır")
    func sortedDescending() {
        let uzun = oturum(kafe, from: gun(9, 8), to: gun(9, 14))
        let kisa = oturum(ev, from: gun(9, 15), to: gun(9, 16))

        let toplamlar = placeTotals(
            from: [kisa, uzun], range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.map(\.placeID) == [kafe, ev])
    }

    @Test("Açık oturum şu ana kadar sayılır")
    func openSessionCountsUntilNow() {
        let acik = oturum(kafe, from: gun(9, 14), to: nil)

        let toplamlar = placeTotals(
            from: [acik], range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first?.totalSeconds == 3600)
    }

    @Test("Aktif süre ayrı toplanır")
    func activeSecondsAccumulate() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first { $0.placeID == ev }?.activeSeconds == 3600)
        #expect(toplamlar.first { $0.placeID == kafe }?.activeSeconds == 5400)
    }

    @Test("Oturum yoksa liste boş döner")
    func emptyWhenNoSessions() {
        #expect(
            placeTotals(from: [], range: .today, now: simdi, calendar: takvim).isEmpty
        )
    }
}

@Suite("Gün şeridi")
struct DaySegmentsTests {

    @Test("Segmentler oturumları izler, boşluklar segment üretmez")
    func gapsProduceNoSegments() {
        let oturumlar = [
            oturum(ev, from: gun(9, 9), to: gun(9, 11)),
            oturum(kafe, from: gun(9, 13), to: gun(9, 15)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        // 11:00-13:00 arasi bosluk; ucuncu bir segment olusmaz.
        #expect(segmentler.count == 2)
        #expect(segmentler[0].placeID == ev)
        #expect(segmentler[0].start == gun(9, 9))
        #expect(segmentler[0].end == gun(9, 11))
        #expect(segmentler[1].start == gun(9, 13))
    }

    @Test("Başka günün oturumları girmez")
    func otherDaysExcluded() {
        let oturumlar = [
            oturum(ev, from: gun(8, 9), to: gun(8, 17)),
            oturum(kafe, from: gun(9, 10), to: gun(9, 12)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        #expect(segmentler.count == 1)
        #expect(segmentler[0].placeID == kafe)
    }

    @Test("Açık oturum şu ana kadar uzanır")
    func openSegmentEndsNow() {
        let simdi = gun(9, 16)
        let segmentler = daySegments(
            from: [oturum(kafe, from: gun(9, 14), to: nil)],
            on: simdi,
            calendar: takvim
        )

        #expect(segmentler.first?.end == simdi)
    }

    @Test("Zamana göre sıralı döner")
    func sortedByTime() {
        let oturumlar = [
            oturum(kafe, from: gun(9, 13), to: gun(9, 15)),
            oturum(ev, from: gun(9, 9), to: gun(9, 11)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        #expect(segmentler.map(\.placeID) == [ev, kafe])
    }

    @Test("Boş günde segment yoktur")
    func emptyDay() {
        #expect(daySegments(from: [], on: gun(9, 16), calendar: takvim).isEmpty)
    }
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter "Yer toplamları"`
Expected: FAIL — `cannot find 'placeTotals' in scope`

- [ ] **Step 3: Hesaplamaları yaz**

`Sources/PlaceTimerCore/Statistics.swift`:

```swift
import Foundation

/// Bir yerin belirli bir aralıktaki toplamı.
public struct PlaceTotal: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let totalSeconds: TimeInterval
    public let activeSeconds: TimeInterval
    public let sessionCount: Int

    public var id: String { placeID?.uuidString ?? "bilinmeyen" }

    public init(
        placeID: UUID?,
        totalSeconds: TimeInterval,
        activeSeconds: TimeInterval,
        sessionCount: Int
    ) {
        self.placeID = placeID
        self.totalSeconds = totalSeconds
        self.activeSeconds = activeSeconds
        self.sessionCount = sessionCount
    }
}

/// Takvim tabanlı aralıklar. `week` içinde bulunulan takvim haftası,
/// `month` içinde bulunulan takvim ayıdır — kayan 7/30 günlük pencere değil.
/// "Bu hafta" ifadesi takvim haftasını çağrıştırır.
public enum StatsRange: Sendable, CaseIterable {
    case today, week, month

    public var displayName: String {
        switch self {
        case .today: "Bugün"
        case .week: "Bu hafta"
        case .month: "Bu ay"
        }
    }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .today: calendar.dateInterval(of: .day, for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)
        case .month: calendar.dateInterval(of: .month, for: date)
        }
    }
}

/// Oturumları yere göre toplar. Toplam süreye göre azalan sıralı döner.
///
/// Açık oturumlar (`endedAt == nil`) `now`'a kadar sayılır.
public func placeTotals(
    from sessions: [Session],
    range: StatsRange,
    now: Date,
    calendar: Calendar = .current
) -> [PlaceTotal] {
    guard let interval = range.interval(containing: now, calendar: calendar) else {
        return []
    }

    var accumulator: [UUID?: (total: TimeInterval, active: TimeInterval, count: Int)] = [:]

    for session in sessions where interval.contains(session.startedAt) {
        let elapsed = session.elapsed(at: now)
        var entry = accumulator[session.placeID] ?? (0, 0, 0)
        entry.total += elapsed
        entry.active += session.activeSeconds
        entry.count += 1
        accumulator[session.placeID] = entry
    }

    return accumulator
        .map {
            PlaceTotal(
                placeID: $0.key,
                totalSeconds: $0.value.total,
                activeSeconds: $0.value.active,
                sessionCount: $0.value.count
            )
        }
        .sorted { $0.totalSeconds > $1.totalSeconds }
}

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

/// Bir günün oturumlarını zaman sırasına dizer.
///
/// Oturumlar arası boşluklar segment üretmez; şeritte boş alan olarak
/// görünürler. Böylece "bilgisayar kapalıydı" ile "buradaydım" ayrışır.
///
/// - Parameter day: Hem hangi günün isteneceğini hem de "şimdi"nin ne olduğunu
///   belirler; açık oturum bu ana kadar uzatılır. Bugün için `Date()` geçin.
public func daySegments(
    from sessions: [Session],
    on day: Date,
    calendar: Calendar = .current
) -> [DaySegment] {
    sessions
        .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
        .sorted { $0.startedAt < $1.startedAt }
        .map {
            DaySegment(
                placeID: $0.placeID,
                start: $0.startedAt,
                end: $0.endedAt ?? day
            )
        }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 65 test

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: yer toplamlari ve gun seridi hesaplamalari

Takvim tabanli araliklar: "bu hafta" takvim haftasi, "bu ay" takvim ayi.
Kayan pencere daha kolay olurdu ama kimse "bu hafta" derken onu kastetmiyor.

Gun seridinde oturumlar arasi bosluklar segment uretmiyor; "bilgisayar
kapaliydi" ile "buradaydim" gorsel olarak ayrissin diye.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 8: Ayarların uygulamaya bağlanması ve manuel kontrol

Buraya kadar yazılan saf mantık uygulamaya bağlanır. Bu görevin çıktısı elle doğrulanır; koordinatör `@MainActor` ve sistem servislerine bağlı olduğu için birim testi yoktur — mantığın testlenebilir kısmı zaten 1–7. görevlerde çekirdeğe alındı.

**Files:**
- Modify: `Sources/PlaceTimerKit/AppCoordinator.swift`
- Modify: `Sources/PlaceTimerKit/UI/Formatters.swift`
- Modify: `Sources/PlaceTimerKit/PlaceTimerScene.swift` (`menuBarTitle`)

**Interfaces:**
- Consumes: `Preferences`, `EngineConfiguration(preferences:)`, `SessionEngine.updateConfiguration(_:at:)`, `ManualPlaceSelection`, `SessionEvent.endSessionRequested`, `PlaceCatalog.displayName(for:)`
- Produces:
  - `AppCoordinator.preferences: Preferences` (okunur)
  - `AppCoordinator.updatePreferences(_ preferences: Preferences)`
  - `AppCoordinator.endCurrentSession()`
  - `AppCoordinator.overrideCurrentPlace(_ placeID: UUID)`
  - `AppCoordinator.knownPlaces: [Place]`
  - `AppCoordinator.todaySegments: [DaySegment]`
  - `AppCoordinator.todayHereSeconds: TimeInterval`
  - `AppCoordinator.totals(for range: StatsRange) -> [PlaceTotal]`
  - `AppCoordinator.removePlace(_:)`, `renamePlace(_:to:)`, `detachSSID(_:from:)`
  - `DurationFormat.clock(_ seconds: TimeInterval, showSeconds: Bool) -> String`

- [ ] **Step 1: Biçimlendiriciye saniye desteği ekle**

`Sources/PlaceTimerKit/UI/Formatters.swift` içinde `clock`'u değiştir:

```swift
    /// Menubar ve panel başlığı için: `2:14` veya `2:14:07`.
    public static func clock(_ seconds: TimeInterval, showSeconds: Bool = false) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        guard showSeconds else {
            return String(format: "%d:%02d", hours, minutes)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, total % 60)
    }
```

- [ ] **Step 2: Koordinatöre ayarları ve manuel kontrolü ekle**

`Sources/PlaceTimerKit/AppCoordinator.swift`:

Görünen durum bölümüne ekle:

```swift
    public private(set) var preferences = Preferences()
    public private(set) var todaySegments: [DaySegment] = []
    public private(set) var todayHereSeconds: TimeInterval = 0
```

Depolar bölümüne ekle:

```swift
    private let preferencesStore: JSONFileStore<Preferences>
```

Özel durum bölümüne ekle:

```swift
    private var manualSelection: ManualPlaceSelection?
```

`init(directory:)` içine:

```swift
        preferencesStore = JSONFileStore(url: base.appendingPathComponent("preferences.json"))
```

`start()` içinde katalog yüklemesinin hemen ardına:

```swift
        preferences = (try? preferencesStore.load()) ?? Preferences()
```

ve `SessionEngine.restored` çağrısına yapılandırmayı geçir:

```swift
        let restored = SessionEngine.restored(
            from: state,
            configuration: EngineConfiguration(preferences: preferences),
            now: Date()
        )
```

Yeni genel yöntemler (`renameCurrentPlace`'in altına):

```swift
    // MARK: - Ayarlar

    public func updatePreferences(_ preferences: Preferences) {
        self.preferences = preferences
        try? preferencesStore.save(preferences)
        engine.updateConfiguration(
            EngineConfiguration(preferences: preferences), at: Date()
        )
        refreshDisplay()
    }

    // MARK: - Manuel kontrol

    /// Sayacı sıfırlar: oturumu kapatıp aynı yerde yenisini başlatır.
    public func endCurrentSession() {
        apply(.endSessionRequested)
        refreshDisplay()
    }

    /// "Burası aslında şurası" düzeltmesi. Seçim, o anki ağa bağlanır ve ağ
    /// değişene kadar otomatik eşleşmeyi bastırır.
    public func overrideCurrentPlace(_ placeID: UUID) {
        manualSelection = ManualPlaceSelection(placeID: placeID, ssid: lastWiFi?.ssid)
        prompt = nil
        apply(.placeResolved(.known(placeID)))
        refreshDisplay()
    }

    // MARK: - Yer yönetimi

    public var knownPlaces: [Place] {
        catalog.places.sorted { $0.displayName < $1.displayName }
    }

    public func renamePlace(_ placeID: UUID, to name: String) {
        catalog.rename(placeID, to: name)
        persistCatalog()
        refreshDisplay()
    }

    public func removePlace(_ placeID: UUID) {
        catalog.remove(placeID)
        if manualSelection?.placeID == placeID { manualSelection = nil }
        persistCatalog()
        refreshDisplay()
    }

    public func detachSSID(_ ssid: String, from placeID: UUID) {
        catalog.detach(ssid: ssid, from: placeID)
        persistCatalog()
        refreshDisplay()
    }

    // MARK: - İstatistik

    public func totals(for range: StatsRange) -> [PlaceTotal] {
        placeTotals(from: allSessions, range: range, now: Date())
    }

    /// Geçmiş ve açık oturum birlikte; istatistik ikisini de saymalı.
    private var allSessions: [Session] {
        guard let current = engine.currentSession else { return history }
        return history + [current]
    }
```

`checkNetwork(at:)` içinde `switch`'ten **önce** manuel seçimi devreye sok:

```swift
        let snapshot = WiFiReader.snapshot()
        defer { lastWiFi = snapshot }

        // Manuel duzeltme, gecerli oldugu surece katalog eslesmesini bastirir.
        if let selection = manualSelection {
            if selection.applies(to: snapshot.ssid) {
                apply(.placeResolved(.known(selection.placeID)), at: now)
                return
            }
            manualSelection = nil
        }
```

`refreshDisplay(now:)` sonuna ekle:

```swift
        todaySegments = daySegments(from: allSessions, on: now)
        todayHereSeconds = placeTotals(from: allSessions, range: .today, now: now)
            .first { $0.placeID == engine.currentSession?.placeID }?
            .totalSeconds ?? 0
```

- [ ] **Step 3: Menubar başlığını ayarlara bağla**

`Sources/PlaceTimerKit/PlaceTimerScene.swift` içinde `menuBarTitle`:

```swift
    private var menuBarTitle: String {
        guard !coordinator.needsLocationPermission else { return "◷ İzin gerekli" }
        let time = DurationFormat.clock(
            coordinator.elapsed,
            showSeconds: coordinator.preferences.showSeconds
        )
        guard coordinator.preferences.showPlaceNameInMenuBar else { return time }
        return "\(DurationFormat.truncate(coordinator.placeName)) · \(time)"
    }
```

- [ ] **Step 4: Derlemenin temiz olduğunu doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: derleme uyarısız, 65 test geçer

- [ ] **Step 5: Elle doğrula**

```bash
./Scripts/build-app.sh --install && open /Applications/PlaceTimer.app
```

Doğrulanacaklar:
1. Uygulama açılıyor, menubar'da sayaç görünüyor
2. `~/Library/Application Support/PlaceTimer/preferences.json` oluşuyor ve varsayılanları içeriyor:
   ```bash
   cat ~/Library/Application\ Support/PlaceTimer/preferences.json
   ```
   Beklenen: `"showSeconds" : false`, `"notificationInterval" : "hourly"`
3. Dosyayı elle `"showSeconds": true` yapıp uygulamayı yeniden başlat; menubar'da saniye görünüyor

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: ayarlar ve manuel kontrol uygulamaya baglandi

Tercihler diskten okunuyor, motorun yapilandirmasini besliyor ve menubar
bicimini belirliyor. Manuel yer duzeltmesi ile sayac sifirlama koordinatore
eklendi; gun seridi ve bugunku toplamlar hesaplaniyor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 9: Uygulama simgesi

**Files:**
- Create: `Scripts/make-icon.swift`
- Create: `Scripts/make-icon.sh`
- Modify: `Resources/Info.plist`
- Modify: `Scripts/build-app.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `Resources/AppIcon.icns` (üretilir, depoya girmez)

- [ ] **Step 1: Çizim betiğini yaz**

`Scripts/make-icon.swift`:

```swift
// PlaceTimer simgesi: konum ignesi, basi bir saat kadrani.
//
// Simge ikili dosya olarak depoya girmez; bu betikle uretilir. Rengini ya da
// formunu degistirmek icin asagidaki sabitleri duzenleyip yeniden calistirin.
//
// Kullanim: swift Scripts/make-icon.swift <cikti-klasoru>

import AppKit

let arkaUst = NSColor(srgbRed: 0.42, green: 0.25, blue: 0.72, alpha: 1)    // mor
let arkaAlt = NSColor(srgbRed: 0.11, green: 0.16, blue: 0.45, alpha: 1)    // derin mavi
let kadranRengi = NSColor(srgbRed: 0.09, green: 0.13, blue: 0.36, alpha: 1)

func iconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current else { return image }
    context.imageInterpolation = .high

    // Arka plan: macOS'un yuvarlak kare orani (~22.37%), kenarlarda hafif bosluk.
    let inset = size * 0.06
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let background = NSBezierPath(
        roundedRect: rect,
        xRadius: rect.width * 0.2237,
        yRadius: rect.width * 0.2237
    )
    background.addClip()
    NSGradient(starting: arkaUst, ending: arkaAlt)?
        .draw(in: rect, angle: -90)

    // Igne: merkez daire + asagi bakan ucgen uc. Ikisi ayni beyazla dolduruldugu
    // icin tek bir siluet gibi okunur.
    let merkez = NSPoint(x: size / 2, y: size * 0.58)
    let yaricap = size * 0.23

    let pinPath = NSBezierPath()
    pinPath.appendOval(
        in: NSRect(
            x: merkez.x - yaricap, y: merkez.y - yaricap,
            width: yaricap * 2, height: yaricap * 2
        )
    )
    let ucgen = NSBezierPath()
    ucgen.move(to: NSPoint(x: merkez.x - yaricap * 0.72, y: merkez.y - yaricap * 0.62))
    ucgen.line(to: NSPoint(x: merkez.x + yaricap * 0.72, y: merkez.y - yaricap * 0.62))
    ucgen.line(to: NSPoint(x: merkez.x, y: size * 0.13))
    ucgen.close()
    pinPath.append(ucgen)

    NSColor.white.setFill()
    pinPath.fill()

    // Kadran: ignenin icinde koyu bir daire. 16 pikselde bile beyaz igne
    // uzerinde koyu bir nokta olarak okunur.
    let kadranYaricap = yaricap * 0.62
    kadranRengi.setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: merkez.x - kadranYaricap, y: merkez.y - kadranYaricap,
            width: kadranYaricap * 2, height: kadranYaricap * 2
        )
    ).fill()

    // Akrep ve yelkovan yalnizca buyuk boyutlarda ciziliyor: 32 pikselin
    // altinda birbirine karisip kadrani bulaniklastiriyorlar.
    if size >= 64 {
        NSColor.white.setStroke()
        let kalinlik = max(1, size * 0.022)

        let yelkovan = NSBezierPath()
        yelkovan.move(to: merkez)
        yelkovan.line(to: NSPoint(x: merkez.x, y: merkez.y + kadranYaricap * 0.72))
        yelkovan.lineWidth = kalinlik
        yelkovan.lineCapStyle = .round
        yelkovan.stroke()

        let akrep = NSBezierPath()
        akrep.move(to: merkez)
        akrep.line(
            to: NSPoint(
                x: merkez.x + kadranYaricap * 0.52,
                y: merkez.y + kadranYaricap * 0.18
            )
        )
        akrep.lineWidth = kalinlik
        akrep.lineCapStyle = .round
        akrep.stroke()
    }

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try png.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("kullanim: make-icon.swift <cikti-klasoru>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(
    at: outputDirectory, withIntermediateDirectories: true
)

// iconutil'in bekledigi isimlendirme.
let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let image = iconImage(size: variant.pixels)
    try writePNG(image, to: outputDirectory.appendingPathComponent("\(variant.name).png"))
}

print("\(variants.count) boyut uretildi: \(outputDirectory.path)")
```

- [ ] **Step 2: Paketleme betiğini yaz**

`Scripts/make-icon.sh`:

```bash
#!/bin/bash
# PlaceTimer simgesini uretir: cizim -> tum boyutlar -> .icns
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

ICONSET="build/AppIcon.iconset"
OUTPUT="Resources/AppIcon.icns"

rm -rf "$ICONSET"
mkdir -p "$ICONSET" Resources

echo "==> Simge ciziliyor"
swift Scripts/make-icon.swift "$ICONSET"

echo "==> .icns paketleniyor"
iconutil -c icns "$ICONSET" -o "$OUTPUT"

echo "==> Hazir: $OUTPUT"
```

- [ ] **Step 3: Betiği çalıştırılabilir yap ve üret**

```bash
chmod +x Scripts/make-icon.sh
./Scripts/make-icon.sh
```

Expected: `Hazir: Resources/AppIcon.icns`

- [ ] **Step 4: Simgeyi gözle kontrol et**

```bash
open build/AppIcon.iconset/icon_512x512.png
open build/AppIcon.iconset/icon_32x32.png
```

Doğrulanacak: 512'de kadran ve akrep/yelkovan seçiliyor; 32'de iğne silueti hâlâ okunur. Okunmuyorsa `make-icon.swift` içindeki `yaricap` ve `kadranYaricap` oranlarını ayarla ve yeniden üret.

- [ ] **Step 5: Bundle'a bağla**

`Resources/Info.plist` içine, `CFBundleIdentifier`'ın altına:

```xml
  <key>CFBundleIconFile</key><string>AppIcon</string>
```

`Scripts/build-app.sh` içinde `cp Resources/Info.plist ...` satırının hemen altına:

```bash
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
else
  echo "uyari: Resources/AppIcon.icns yok; once Scripts/make-icon.sh calistirin." >&2
fi
```

`.gitignore` sonuna:

```
Resources/AppIcon.icns
```

Simge üretilen bir çıktıdır; kaynağı `make-icon.swift`, ikili dosya depoya girmez.

- [ ] **Step 6: Elle doğrula**

```bash
./Scripts/build-app.sh --install && open /Applications/PlaceTimer.app
```

Doğrulanacak: Finder'da `/Applications/PlaceTimer.app` yeni simgeyle görünüyor. Görünmüyorsa Finder simge önbelleği inatçıdır; `killall Finder` yeterli.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: uygulama simgesi

Konum ignesi, basi bir saat kadrani: "yer" ve "zaman" tek formda. Akrep ve
yelkovan yalnizca 64 piksel ustunde ciziliyor; kucuk boyutlarda birbirine
karisip kadrani bulanlastiriyorlardi.

Simge ikili dosya olarak depoya girmiyor, Scripts/make-icon.sh ile
uretiliyor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 10: Ayarlar penceresi

**Files:**
- Create: `Sources/PlaceTimerKit/UI/SettingsView.swift`
- Create: `Sources/PlaceTimerKit/UI/Settings/GeneralSettingsView.swift`
- Create: `Sources/PlaceTimerKit/UI/Settings/PlacesSettingsView.swift`
- Create: `Sources/PlaceTimerKit/UI/Settings/PermissionsSettingsView.swift`
- Create: `Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift`
- Modify: `Sources/PlaceTimerKit/PlaceTimerScene.swift` (`PlaceTimerAppDelegate`)

**Interfaces:**
- Consumes: `AppCoordinator.preferences/updatePreferences/knownPlaces/renamePlace/removePlace/detachSSID/totals(for:)`, `LoginItem`, `SystemSettings`, `AppWindow`
- Produces: `SettingsView(coordinator:)`, `PlaceTimerAppDelegate.presentSettings()`

- [ ] **Step 1: Ayar bağlama yardımcısını ve kabuğu yaz**

`Sources/PlaceTimerKit/UI/SettingsView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// `Preferences` alanları için `Binding` üretir.
///
/// Tercihler koordinatörde `private(set)`: her değişiklik `updatePreferences`
/// üzerinden geçmeli ki diske yazılsın ve motorun yapılandırması güncellensin.
/// Doğrudan `@Bindable` kullanmak bu yolu atlardı.
@MainActor
func preferenceBinding<Value>(
    _ coordinator: AppCoordinator,
    _ keyPath: WritableKeyPath<Preferences, Value>
) -> Binding<Value> {
    Binding(
        get: { coordinator.preferences[keyPath: keyPath] },
        set: { newValue in
            var updated = coordinator.preferences
            updated[keyPath: keyPath] = newValue
            coordinator.updatePreferences(updated)
        }
    )
}

public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(coordinator: coordinator)
                .tabItem { Label("Genel", systemImage: "gearshape") }
            PlacesSettingsView(coordinator: coordinator)
                .tabItem { Label("Yerler", systemImage: "mappin.and.ellipse") }
            PermissionsSettingsView(coordinator: coordinator)
                .tabItem { Label("İzinler", systemImage: "lock.shield") }
            StatisticsSettingsView(coordinator: coordinator)
                .tabItem { Label("İstatistik", systemImage: "chart.bar") }
        }
        .frame(width: 520, height: 420)
    }
}
```

- [ ] **Step 2: Genel sekmesini yaz**

`Sources/PlaceTimerKit/UI/Settings/GeneralSettingsView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var launchesAtLogin = LoginItem.isEnabled

    /// Eşikler serbest sayı değil, birkaç makul seçenek. Kullanıcının
    /// "37 dakika" girmesine izin vermek karar yükünü artırır, karşılığı yok.
    private let sleepOptions: [(String, TimeInterval)] = [
        ("30 dakika", 30 * 60), ("1 saat", 60 * 60),
        ("2 saat", 2 * 60 * 60), ("4 saat", 4 * 60 * 60),
    ]
    private let idleOptions: [(String, TimeInterval)] = [
        ("2 dakika", 2 * 60), ("5 dakika", 5 * 60),
        ("10 dakika", 10 * 60), ("15 dakika", 15 * 60),
    ]

    var body: some View {
        Form {
            Section("Görünüm") {
                Toggle(
                    "Saniyeleri göster",
                    isOn: preferenceBinding(coordinator, \.showSeconds)
                )
                Toggle(
                    "Menubar'da yerin adını göster",
                    isOn: preferenceBinding(coordinator, \.showPlaceNameInMenuBar)
                )
            }

            Section("Davranış") {
                Picker(
                    "Oturumu sıfırlayan uyku süresi",
                    selection: preferenceBinding(coordinator, \.sessionResetSleepThreshold)
                ) {
                    ForEach(sleepOptions, id: \.1) { Text($0.0).tag($0.1) }
                }
                Text("Bu süreden kısa uykular oturumu bozmaz — kahve molası gibi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    "Aktif sayacı durduran hareketsizlik",
                    selection: preferenceBinding(coordinator, \.idleThreshold)
                ) {
                    ForEach(idleOptions, id: \.1) { Text($0.0).tag($0.1) }
                }

                Picker(
                    "Bildirim sıklığı",
                    selection: preferenceBinding(coordinator, \.notificationInterval)
                ) {
                    ForEach(NotificationInterval.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            }

            Section("Başlangıç") {
                Toggle("Açılışta başlat", isOn: Binding(
                    get: { launchesAtLogin },
                    set: { yeni in
                        if yeni { LoginItem.enable() } else { LoginItem.disable() }
                        launchesAtLogin = LoginItem.isEnabled
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .onAppear { launchesAtLogin = LoginItem.isEnabled }
    }
}
```

- [ ] **Step 3: Yerler sekmesini yaz**

`Sources/PlaceTimerKit/UI/Settings/PlacesSettingsView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

struct PlacesSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var selection: UUID?
    @State private var silinecek: Place?
    @State private var draftName = ""

    var body: some View {
        HSplitView {
            List(coordinator.knownPlaces, selection: $selection) { place in
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.displayName)
                    Text("\(place.ssids.count) ağ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(place.id)
            }
            .frame(minWidth: 180)

            detay
                .frame(minWidth: 260)
        }
        .confirmationDialog(
            "\(silinecek?.displayName ?? "") silinsin mi?",
            isPresented: Binding(
                get: { silinecek != nil },
                set: { if !$0 { silinecek = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let silinecek { coordinator.removePlace(silinecek.id) }
                selection = nil
                silinecek = nil
            }
            Button("Vazgeç", role: .cancel) { silinecek = nil }
        } message: {
            Text("Bu yerde geçirdiğin süreler geçmişte \"Silinmiş yer\" olarak kalır.")
        }
    }

    private func commitRename(_ place: Place) {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        coordinator.renamePlace(place.id, to: trimmed)
    }

    @ViewBuilder
    private var detay: some View {
        if let place = coordinator.knownPlaces.first(where: { $0.id == selection }) {
            Form {
                Section("Ad") {
                    // Her tus vurusunda kaydetmiyoruz: liste ada gore sirali,
                    // yazarken satir gozunun onunde yer degistirirdi.
                    TextField("Yerin adı", text: $draftName)
                        .onSubmit { commitRename(place) }
                    Button("Kaydet") { commitRename(place) }
                        .disabled(draftName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                }

                Section("Ağlar") {
                    if place.ssids.isEmpty {
                        Text("Bu yere bağlı ağ kalmadı; artık kendiliğinden tanınmaz.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    ForEach(place.ssids.sorted(), id: \.self) { ssid in
                        HStack {
                            Text(ssid).lineLimit(1)
                            Spacer()
                            Button("Ayır") {
                                coordinator.detachSSID(ssid, from: place.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section {
                    Button("Yeri sil", role: .destructive) { silinecek = place }
                }
            }
            .formStyle(.grouped)
            .onChange(of: place.id, initial: true) { draftName = place.displayName }
        } else {
            ContentUnavailableView(
                "Yer seçilmedi",
                systemImage: "mappin.slash",
                description: Text("Soldaki listeden bir yer seç.")
            )
        }
    }
}
```

- [ ] **Step 4: İzinler sekmesini yaz**

`Sources/PlaceTimerKit/UI/Settings/PermissionsSettingsView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Karşılama sihirbazının kalıcı karşılığı. Sihirbaz bir kez akar; bu sekme
/// izin durumunu her zaman gösterir ve düzeltme yolunu açık tutar.
struct PermissionsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var launchesAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                permissionRow(
                    granted: !coordinator.needsLocationPermission,
                    title: "Konum",
                    detail: "macOS ağ adını yalnızca bu izinle veriyor. "
                        + "İzin olmadan yer tespiti hiç çalışmaz.",
                    action: { coordinator.requestLocationPermission() },
                    pane: .locationServices
                )
                permissionRow(
                    granted: !coordinator.needsNotificationPermission,
                    title: "Bildirimler",
                    detail: "Belirlediğin aralıkta haber verir.",
                    action: { Task { await coordinator.requestNotificationPermission() } },
                    pane: .notifications
                )
                permissionRow(
                    granted: launchesAtLogin,
                    title: "Açılışta başlat",
                    detail: "Bilgisayarı açtığın anda sayması için gerekli.",
                    action: {
                        LoginItem.enable()
                        launchesAtLogin = LoginItem.isEnabled
                    },
                    pane: .loginItems
                )
            }
        }
        .formStyle(.grouped)
        .task {
            // Izinler uygulama disinda da degisebilir; sekme acikken izliyoruz.
            while !Task.isCancelled {
                await coordinator.refreshPermissions()
                launchesAtLogin = LoginItem.isEnabled
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func permissionRow(
        granted: Bool,
        title: String,
        detail: String,
        action: @escaping () -> Void,
        pane: SystemSettings.Pane
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !granted {
                VStack(spacing: 4) {
                    Button("İzin ver", action: action)
                    Button("Ayarlar") { SystemSettings.open(pane) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 5: İstatistik sekmesini yaz**

`Sources/PlaceTimerKit/UI/Settings/StatisticsSettingsView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var range: StatsRange = .week

    private var totals: [PlaceTotal] { coordinator.totals(for: range) }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $range) {
                ForEach(StatsRange.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)

            if totals.isEmpty {
                ContentUnavailableView(
                    "Kayıt yok",
                    systemImage: "chart.bar",
                    description: Text("Bu aralıkta henüz bir oturum yok.")
                )
            } else {
                Table(totals) {
                    TableColumn("Yer") { total in
                        Text(coordinator.placeName(for: total.placeID))
                    }
                    TableColumn("Toplam") { total in
                        Text(DurationFormat.readable(total.totalSeconds))
                            .monospacedDigit()
                    }
                    TableColumn("Aktif") { total in
                        Text(DurationFormat.readable(total.activeSeconds))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Oturum") { total in
                        Text("\(total.sessionCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}
```

- [ ] **Step 6: Pencereyi delegate'e bağla**

`Sources/PlaceTimerKit/PlaceTimerScene.swift` içinde `PlaceTimerAppDelegate`'e ekle:

```swift
    private let settingsWindow = AppWindow(title: "PlaceTimer Ayarları")

    public func presentSettings() {
        settingsWindow.present { [weak self] in
            if let self { SettingsView(coordinator: coordinator) }
        }
    }
```

- [ ] **Step 7: Derlemeyi doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors`
Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: dort sekmeli ayarlar penceresi

Genel, Yerler, Izinler ve Istatistik. Izinler sekmesi karsilama sihirbazinin
kalici karsiligi: sihirbaz bir kez akar, bu sekme durumu her zaman gosterir.

Esikler serbest sayi degil birkac makul secenek; kullanicinin "37 dakika"
girmesine izin vermenin karsiligi yok.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

### Task 11: Panel yeniden tasarımı ve Liquid Glass

**Files:**
- Create: `Sources/PlaceTimerKit/UI/PlaceColor.swift`
- Create: `Sources/PlaceTimerKit/UI/DayStripView.swift`
- Rewrite: `Sources/PlaceTimerKit/UI/PanelView.swift`

**Interfaces:**
- Consumes: `AppCoordinator` (Task 8'in tüm yeni üyeleri), `DaySegment`, `PlaceTimerAppDelegate.presentSettings()`
- Produces: `PlaceColor.color(for placeID: UUID?) -> Color`, `DayStripView(segments:now:)`

- [ ] **Step 1: Yer rengini yaz**

`Sources/PlaceTimerKit/UI/PlaceColor.swift`:

```swift
import SwiftUI

/// Yer kimliğinden kararlı bir renk üretir.
///
/// Renkler diske yazılmaz: aynı UUID her zaman aynı tonu verir, dolayısıyla
/// saklamanın anlamı yok. Doygunluk ve parlaklık sabit tutulur ki şeritteki
/// bütün segmentler aynı aileden görünsün.
public enum PlaceColor {
    public static func color(for placeID: UUID?) -> Color {
        guard let placeID else { return .secondary }

        // UUID'nin ilk baytlarindan kararli bir ton. hashValue kullanmiyoruz:
        // Swift'te calismalar arasi kararli degil.
        let bytes = withUnsafeBytes(of: placeID.uuid) { Array($0.prefix(4)) }
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let hue = Double(value % 360) / 360

        return Color(hue: hue, saturation: 0.62, brightness: 0.82)
    }
}
```

- [ ] **Step 2: Gün şeridini yaz**

`Sources/PlaceTimerKit/UI/DayStripView.swift`:

```swift
import PlaceTimerCore
import SwiftUI

/// Günün oturumlarını yatay bir şerit olarak çizer.
///
/// Şerit 24 saatlik değil: günün ilk oturumundan şimdiye uzanır. Sabah 9'da
/// başlanan bir günde şeridin dörtte üçünü boş bırakmanın kimseye faydası yok.
struct DayStripView: View {
    let segments: [DaySegment]
    let now: Date

    private var start: Date? { segments.first?.start }

    private var span: TimeInterval {
        guard let start else { return 0 }
        return max(60, now.timeIntervalSince(start))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    if let start {
                        ForEach(segments) { segment in
                            let offset = segment.start.timeIntervalSince(start) / span
                            let width = max(
                                2,
                                (segment.end.timeIntervalSince(segment.start) / span)
                                    * geometry.size.width
                            )
                            Capsule()
                                .fill(PlaceColor.color(for: segment.placeID))
                                .frame(width: width)
                                .offset(x: offset * geometry.size.width)
                        }
                    }
                }
            }
            .frame(height: 8)

            if let start {
                HStack {
                    Text(saat(start))
                    Spacer()
                    Text(saat(now))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }
        }
    }

    private func saat(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 3: Paneli yeniden yaz**

`Sources/PlaceTimerKit/UI/PanelView.swift` dosyasının tamamını değiştir:

```swift
import AppKit
import PlaceTimerCore
import SwiftUI

public struct PanelView: View {
    @Bindable var coordinator: AppCoordinator
    @Namespace private var glassNamespace
    @State private var showsControls = false

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let prompt = coordinator.prompt {
                PlacePromptView(prompt: prompt, coordinator: coordinator)
            } else {
                header
                counterAndControls
                if !coordinator.todaySegments.isEmpty { stripCard }
            }
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(PlaceColor.color(for: coordinator.currentPlaceID))
                .frame(width: 8, height: 8)
            Text(coordinator.placeName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.snappy) { showsControls.toggle() }
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.glass)
            .help("Oturum kontrolleri")

            Button {
                (NSApp.delegate as? PlaceTimerAppDelegate)?.presentSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.glass)
            .help("Ayarlar")
        }
    }

    /// Sayaç ve kontroller **tek bir** cam kabında; `⋯` açılınca birbirlerine
    /// dönüşürler. `glassEffectID` eşleşmesi yalnızca aynı kap içinde çalışır —
    /// kontrolleri kabın dışında bırakmak morph'u sessizce iptal ederdi.
    ///
    /// Cam yalnızca üstte yüzen bu katmanlara uygulanıyor; arka plana ya da
    /// liste satırlarına değil.
    private var counterAndControls: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        DurationFormat.clock(
                            coordinator.elapsed,
                            showSeconds: coordinator.preferences.showSeconds
                        )
                    )
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                    Text(altSatir)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .glassEffectID("counter", in: glassNamespace)

                if showsControls { controls }
            }
        }
    }

    private var altSatir: String {
        let aktif = DurationFormat.readable(coordinator.activeSeconds)
        let bugun = DurationFormat.readable(coordinator.todayHereSeconds)
        return "Aktif \(aktif) · Bugün burada \(bugun)"
    }

    private var stripCard: some View {
        DayStripView(segments: coordinator.todaySegments, now: Date())
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("Sayacı sıfırla") { coordinator.endCurrentSession() }
                .buttonStyle(.glass)

            Menu("Yeri değiştir") {
                ForEach(coordinator.knownPlaces) { place in
                    Button(place.displayName) {
                        coordinator.overrideCurrentPlace(place.id)
                    }
                }
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .disabled(coordinator.knownPlaces.isEmpty)
        }
        .glassEffectID("controls", in: glassNamespace)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                Button {
                    (NSApp.delegate as? PlaceTimerAppDelegate)?.presentOnboarding()
                } label: {
                    Label(eksikIzin, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Çıkış") { coordinator.quit() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eksikIzin: String {
        coordinator.needsLocationPermission ? "Konum izni gerekli" : "Bildirim izni gerekli"
    }
}
```

Eski panelin "bugünün oturumları" listesi kaldırılıyor: gün şeridi aynı bilgiyi daha az yerde ve daha okunur biçimde veriyor, ikisi birlikte panelin yarısını yiyordu.

- [ ] **Step 4: Derlemeyi doğrula**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors`
Expected: `Build complete!`

Liquid Glass API adları uyuşmazsa (`glassEffect` imzası, `GlassEffectContainer(spacing:)`), SDK arayüzünden doğrula:

```bash
IF=/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-macos.swiftinterface
grep -n "glassEffect\|GlassEffectContainer" "$IF" | head -20
```

- [ ] **Step 5: Tüm testleri koş**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
Expected: PASS — 65 test

- [ ] **Step 6: Elle doğrula**

```bash
./Scripts/make-icon.sh && ./Scripts/build-app.sh --install && open /Applications/PlaceTimer.app
```

Doğrulanacaklar:
1. Menubar'a tıklayınca panel açılıyor; sayaç cam kart içinde
2. `⋯` düğmesi kontrolleri açıyor, animasyon cam yüzeyler arasında akıyor
3. "Sayacı sıfırla" sayacı `0:00`'a çekiyor
4. "Yeri değiştir" menüsü kayıtlı yerleri listeliyor, seçim menubar adını değiştiriyor ve 10 saniye sonra geri alınmıyor
5. `⚙︎` ayarlar penceresini açıyor; dört sekme de çalışıyor
6. Genel → "Saniyeleri göster" açılınca sayaç anında `0:00:07` biçimine geçiyor
7. Genel → bildirim sıklığı `Kapalı` yapılıp `preferences.json` kontrol ediliyor:
   ```bash
   cat ~/Library/Application\ Support/PlaceTimer/preferences.json
   ```
8. Karanlık ve aydınlık modda panel okunur (Sistem Ayarları → Görünüm)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: panel yeniden tasarimi ve Liquid Glass

Sayac cam bir kartta, gun seridi ayri bir kartta; kontroller "..." ile
aciliyor ve sayacla ayni cam kabinda birbirlerine donusuyorlar.

Cam yalnizca ustte yuzen katmanlara ve kontrollere uygulaniyor; arka plana
ve liste satirlarina degil.

Bugunun oturum listesi kaldirildi: gun seridi ayni bilgiyi daha az yerde ve
daha okunur bicimde veriyor, ikisi birlikte panelin yarisini yiyordu.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xMBSLAYvzs8sTck4rCDE4
EOF
)"
```

---

## Son Doğrulama

Tüm görevler bittikten sonra:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -Xswiftc -warnings-as-errors
./Scripts/make-icon.sh
./Scripts/build-app.sh --install
```

`README.md` güncellenir: macOS 26 gereksinimi, ayarlar penceresi, `Scripts/make-icon.sh`.
