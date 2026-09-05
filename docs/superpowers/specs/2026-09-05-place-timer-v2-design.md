# PlaceTimer v2 — Görünüm, Ayarlar ve Kontrol

**Tarih:** 2026-09-05
**Durum:** Onaylandı, implementasyona hazır
**Önceki tasarım:** [2026-09-04](2026-09-04-place-timer-design.md)

## 1. Neden

v1 çalışıyor: yeri tanıyor, sayıyor, saat başı haber veriyor. Eksik olan,
kullanıcının **gördüğü** ve **müdahale edebildiği** taraf. Şu an bir yere
yanlış isim verilirse düzeltilemiyor, otomasyon yanılırsa karşı çıkılamıyor,
toplanan veri hiç gösterilmiyor ve eşiklerin tamamı kodda sabit.

v2 bu dört boşluğu kapatır ve arayüzü macOS 26'nın Liquid Glass diline taşır.

## 2. Kapsam

| Girer | Girmez |
|---|---|
| Uygulama simgesi | Oturum geçmişini düzenleme |
| Liquid Glass arayüz | CSV dışa aktarma |
| Ayarlar penceresi (4 sekme) | Hedef süreler |
| Panel yeniden tasarımı | iCloud senkronu |
| Saniye gösterimi (ayarlanabilir) | Uygulama bazlı takip |
| Yer yönetimi | |
| Manuel kontrol | |
| Gün şeridi + istatistik | |
| Ayarlanabilir eşikler | |

**Minimum macOS 26.** Liquid Glass (`glassEffect`, `GlassEffectContainer`,
`.buttonStyle(.glass)`) bu sürümde geldi ve başka yolu yok. `Package.swift`
`.macOS(.v14)` → `.macOS(.v26)`. Eski sürümler için ikinci bir tasarım hattı
tutmanın bu uygulamada karşılığı yok.

## 3. Preferences

Çekirdeğe saf bir değer tipi girer, `preferences.json`'a yazılır.

```swift
public enum NotificationInterval: String, Codable, Sendable, CaseIterable {
    case off, every30Minutes, hourly

    var seconds: TimeInterval?   // off için nil
}

public struct Preferences: Codable, Sendable, Equatable {
    public var showSeconds: Bool = false
    public var showPlaceNameInMenuBar: Bool = true
    public var sessionResetSleepThreshold: TimeInterval = 60 * 60
    public var idleThreshold: TimeInterval = 5 * 60
    public var notificationInterval: NotificationInterval = .hourly
}
```

`EngineConfiguration` bundan türetilir. Bunun bir sonucu var:
`SessionEngine.configuration` şu an `let`; ayar değişince motorun durumunu
kaybetmeden güncellenebilmesi gerekir.

```swift
public mutating func updateConfiguration(_ configuration: EngineConfiguration)
```

Açık oturum, sayaçlar ve gönderilmiş işaretler korunur.

### Bildirim aralığının genelleşmesi

`Session.notifiedHourMarks` → `notifiedMarks`. İşaret artık
`Int(elapsed / aralık)`. `.off` seçiliyse hiç işaret üretilmez.

**Aralık oturum ortasında değişirse** geçmiş işaretler dolu sayılır:

```swift
session.notifiedMarks = Set(1...Int(elapsed / yeniAralık))
```

Yoksa saatlikten 30 dakikalığa geçildiğinde birikmiş bildirimler topluca
düşerdi.

Eski `notifiedHourMarks` anahtarı `Codable` tarafında okunmaya devam eder
(saatlik varsayımıyla), böylece mevcut `state.json` bozulmaz.

## 4. Manuel Kontrol

İki eylem, panelde `⋯` düğmesinin altında.

### Yeri değiştir

Motora dokunmaz. Koordinatör bir manuel seçim tutar:

```swift
private var manualPlace: (ssid: String, placeID: UUID)?
```

`checkNetwork` mevcut SSID bu kayıttakiyle aynı olduğu sürece katalog
eşleşmesini değil bu seçimi kullanır. SSID değişince seçim düşer.

Wi-Fi yokken (`ssid == nil`) manuel seçim yapılırsa bağlanacak bir ağ adı
olmadığından seçim **oturum kapanana kadar** geçerli kalır; ilk SSID
görüldüğünde düşer.

Bu şart: aksi halde manuel seçim, 10 saniyelik ağ yoklamasının ilk turunda
kendiliğinden geri alınırdı.

### Oturumu bitir

Yeni motor olayı:

```swift
case endSessionRequested
```

Oturumu **şu anda** kapatır ve aynı yerde hemen yenisini başlatır — pratikte
"sayacı sıfırla". Otomatik bir takipçinin takibi tamamen bırakması tuhaf
olurdu; amaç yanlış başlamış bir sayacı düzeltmek, izlemeyi durdurmak değil.

## 5. Yer Yönetimi

`PlaceCatalog`'a iki mutasyon eklenir:

```swift
public mutating func remove(_ placeID: UUID)
public mutating func detach(ssid: String, from placeID: UUID)
```

Silinen bir yere işaret eden geçmiş oturumlar **"Silinmiş yer"** olarak
görünür. `placeName(for:)` üç durumu ayırır:

| Durum | Görünen |
|---|---|
| `placeID == nil` | Bilinmeyen yer |
| `placeID` var, katalogda yok | Silinmiş yer |
| `placeID` var, katalogda var | Yerin adı |

Geçmişi sessizce "Bilinmeyen yer"e karıştırmak yanlış olurdu; bu ayrı bir
durum ve kullanıcı ne olduğunu görebilmeli.

Son SSID'si çıkarılan bir yer katalogda kalır ama artık hiçbir ağla
eşleşmez — silme ile ayırma farklı işlemlerdir.

## 6. İstatistik ve Gün Şeridi

İkisi de `PlaceTimerCore` içinde saf fonksiyon, ikisi de testli.

```swift
public struct PlaceTotal: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let totalSeconds: TimeInterval
    public let activeSeconds: TimeInterval
    public let sessionCount: Int
}

/// Takvim tabanlı: `week` içinde bulunulan takvim haftası (kullanıcının
/// bölgesel ilk gününe göre), `month` içinde bulunulan takvim ayı. Kayan
/// 7/30 günlük pencere değil — "bu hafta" ifadesi takvim haftasını çağrıştırır.
public enum StatsRange: Sendable { case today, week, month }

public func placeTotals(
    from sessions: [Session], range: StatsRange, now: Date
) -> [PlaceTotal]      // toplam süreye göre azalan

public struct DaySegment: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let start: Date
    public let end: Date
}

public func daySegments(from sessions: [Session], on day: Date) -> [DaySegment]
```

Gün şeridi 24 saatlik değildir: günün **ilk oturumundan şimdiye** uzanır.
Sabah 9'da başlanan bir günde şeridin dörtte üçü boş durmamalı.

Oturumlar arası boşluklar segment üretmez; şeritte boş alan olarak görünür.
Böylece "bilgisayar kapalıydı" ile "buradaydım" görsel olarak ayrışır.

Açık oturum da şeride ve toplamlara dahildir; `endedAt` yoksa `now` kullanılır.

Panelin `Bugün burada` satırı, `placeTotals(range: .today)` sonucundan mevcut
oturumun yerine ait kaydın okunmasıyla elde edilir — ayrı bir hesap değildir.

## 7. Arayüz

### Panel (~320pt)

Yukarıdan aşağı:

1. Yer adı · sağda iki cam düğme: `⚙︎` ayarlar, `⋯` manuel kontrol
2. Büyük sayaç — `2:14:07` veya `2:14` (ayara göre), yuvarlak, sabit genişlikli rakam
3. Tek satır: `Aktif 1sa 47dk · Bugün burada 3sa 20dk`
4. Gün şeridi — yerlere göre renkli segmentler
5. Bugünün oturumları, kompakt liste
6. İzin sorunu varsa uyarı satırı

### Ayarlar penceresi — `TabView`, dört sekme

| Sekme | İçerik |
|---|---|
| **Genel** | Saniye göster · menubar'da yer adını göster · açılışta başlat · oturum sıfırlama eşiği · hareketsizlik eşiği · bildirim sıklığı |
| **Yerler** | Kayıtlı yerler; ad düzenle, SSID görüntüle/çıkar, sil |
| **İzinler** | Konum / bildirim / giriş öğesi durumu ve düzeltme düğmeleri — karşılama ekranının kalıcı hali |
| **İstatistik** | Bu hafta / bu ay, yer başına toplam |

Karşılama sihirbazı ilk açılışta kalır; İzinler sekmesi onun sürekli erişilen
karşılığıdır, ikisi aynı durum kaynağını okur.

### Liquid Glass kullanımı

Cam **süs değil kural**: üstte yüzen katmanlara ve kontrollere uygulanır.

| Uygulanır | Uygulanmaz |
|---|---|
| Sayaç kartı | Ayarlardaki metin yoğun listeler |
| Gün şeridi kartı | Panel arka planı (menubar penceresinin kendi materyali) |
| Manuel kontrol düğmeleri (`.glass`) | Oturum listesi satırları |
| Karşılama ekranının birincil düğmesi (`.glassProminent`) | |

Sayaç ile manuel kontroller tek bir `GlassEffectContainer` içinde
`glassEffectID` ile eşleşir; `⋯` açılınca birbirlerine dönüşürler.

## 8. Simge

Konum iğnesi, başı bir saat kadranı. Derin mavi → mor gradyan, beyaz kadran.
"Yer" ve "zaman" tek formda; 16 pikselde iğne silueti okunur kalır.

Core Graphics ile çizilir, tüm boyutlar (16–1024, @1x/@2x) üretilir,
`iconutil -c icns` ile paketlenir. Çizim kodu `Scripts/make-icon.sh` olarak
depoda durur — simge yeniden üretilebilir kalır, ikili dosya olarak gömülmez.

macOS 26'nın Icon Composer katmanlı formatı yerine düz `.icns`: çok daha basit
ve Dock'ta farkı görünmüyor.

`Info.plist`'e `CFBundleIconFile` eklenir, betik `.icns`'i bundle'a kopyalar.

## 9. Testler

Yeni saf mantığın tamamı `PlaceTimerCoreTests` altında:

- `Preferences` gidiş-dönüş ve varsayılanlar
- Bildirim aralığı işaretleri: `.off`, 30 dakika, saatlik
- Aralık oturum ortasında değişince birikmiş bildirim patlamaması
- Eski `notifiedHourMarks` anahtarının okunabilmesi
- `updateConfiguration` açık oturumu ve sayaçları bozmuyor
- `endSessionRequested` oturumu kapatıp aynı yerde yenisini açıyor
- `placeTotals` — bugün / hafta / ay, açık oturum dahil
- `daySegments` — ilk oturumdan şimdiye, açık oturum dahil, boş gün
- `remove` sonrası "Silinmiş yer", `detach` sonrası eşleşmeme

Arayüz elle doğrulanır.

## 10. İnşa Sırası

1. `Preferences` + depolama + `updateConfiguration` + bildirim aralığı
2. Manuel kontrol (`endSessionRequested`, koordinatörde manuel yer seçimi)
3. Yer yönetimi mutasyonları + "Silinmiş yer"
4. İstatistik ve gün şeridi hesaplamaları
5. Simge üretimi ve paketlemeye bağlanması
6. Ayarlar penceresi
7. Panel yeniden tasarımı ve Liquid Glass geçişi

1–4 saf mantık ve testlerle birlikte gider; 5–7 arayüz. Dağıtım hedefi
`.macOS(.v26)`'ya ilk adımda çıkarılır.
