# PlaceTimer — Tasarım Dokümanı

**Tarih:** 2026-09-04
**Durum:** Onaylandı, implementasyona hazır
**Platform:** macOS 27+, Swift + SwiftUI (`MenuBarExtra`)

## 1. Problem

Laptop'la farklı yerlerde çalışan biri, bulunduğu yerde ne kadar zaman
geçirdiğini bilmiyor. Mevcut araçlar (Screen Time, Toggl) ya sadece
uygulama kullanımını ölçüyor ya da elle başlat/durdur gerektiriyor —
ikisi de "bu kafede iki saattir oturuyorum" sorusunu cevaplamıyor.

## 2. Çözüm

Menubar'da yaşayan, hiçbir düğmeye basılmadan çalışan bir sayaç.
Bilgisayar uyandığında bulunulan yeri Wi-Fi ağından tanır, o yerdeki
oturumu otomatik başlatır ve geçen süreyi menubar'da gösterir. Her
saat başı bildirim gönderir.

**Başarı ölçütü:** Kullanıcı sabah kafede laptop'unu açar, hiçbir
etkileşim yapmadan menubar'da kafenin adını ve akan süreyi görür.

## 3. Kapsam Dışı

Bilinçli olarak MVP dışında bırakılanlar: hedef süreler, grafik ve
raporlar, haftalık istatistik, iCloud senkronu, uygulama bazlı takip,
harita üzerinde geofence, Screen Time entegrasyonu, ayarlar ekranı.

## 4. Yer Kimliği

Bir yerin kimliği bağlı olunan **SSID kümesidir**. Yanında o yerde
görülmüş BSSID'ler (access point MAC adresleri) ve ilk onay anındaki
koordinat saklanır.

**Neden tek SSID değil (spike bulgusu):** Router'lar 2.4 GHz ve 5 GHz
bantlarını çoğu zaman ayrı adlarla yayınlar (`Ev` ve `Ev-5G`). Mac bant
değiştirdiğinde SSID değişir; tek SSID anahtar olsaydı bu, yer değişimi
sanılıp oturumu boş yere sıfırlardı. Bu yüzden bir yer birden çok
SSID'ye sahip olabilir.

Tanınmayan bir SSID görüldüğünde, kayıtlı bir yerin 300 m çevresindeysek
isim önerilerinin başına o yer gelir ("Burası *Ev* mi?"); kullanıcı
onaylarsa SSID mevcut yere eklenir, yeni yer açılmaz.

**Neden sadece BSSID değil:** Kafelerin ve ev mesh sistemlerinin
birden fazla access point'i olur. Masa değiştirince BSSID değişir;
BSSID anahtar olsaydı aynı kafe birden fazla yer sanılırdı.

**Neden sadece SSID değil:** Zincir mekanlarda SSID her şubede aynıdır
("Starbucks WiFi").

**Kural:** Anahtar SSID'dir. SSID eşleşiyor fakat mevcut koordinat
kayıtlı koordinattan **300 m'den uzaksa**, uygulama bunu yeni bir yer
adayı sayar ve kullanıcıya "Burası farklı bir şube mi?" diye sorar.

**Wi-Fi yokken** (ethernet, tethering): oturum yine başlar, yer
`Bilinmeyen yer` olur, kullanıcı panelden isim verebilir.

### Yeni yer akışı

Tanınmayan bir SSID'ye bağlanıldığında panel açılır ve `MKLocalPointsOfInterestRequest` ile bulunan **en yakın 3 mekân** isim önerisi olarak
listelenir. Kullanıcı birini seçer, kendi ismini yazar veya "Şimdilik
atla" der. Bu bir kereliktir; aynı ağa tekrar bağlanıldığında hiçbir
şey sorulmaz.

## 5. Oturum Durum Makinesi

Üç durum: **Boşta → Aktif → Askıda**.

| Olay | Sonuç |
|---|---|
| Uyanma / uygulama açılışı, aktif oturum yok | Yeni oturum başlar |
| Uyku | Oturum askıya alınır, uyku anı diske yazılır |
| Uyanma, uyku ≤ 60 dk, yer aynı | Aynı oturum devam eder |
| Uyanma, uyku > 60 dk | Oturum kapanır, yenisi başlar |
| SSID değişti → farklı yer | Oturum kapanır, yeni yerde yenisi başlar |
| Uyku sırasında yer değişmiş | Eski oturum **uyku anında** kapanır |

Gece yarısı sınırı yoktur; gece boyu uyku zaten 60 dk kuralına takılır.

### İki sayaç

**Yerde geçen süre** = `şimdi − oturum başlangıcı`. Duvar saati; 60
dk'nın altındaki uyku aralarını içine alır. Menubar bunu gösterir.

**Aktif çalışma süresi** = saniyede bir örneklenerek biriken sayaç.
Yalnızca şu üç şart birlikte sağlanıyorsa artar:
- sistem uyanık
- ekran kilitli değil
- son kullanıcı girdisinden bu yana **5 dakikadan az** geçmiş

Hareketsizlik `CGEventSourceSecondsSinceLastEventType`
(`.combinedSessionState`, `.anyInputEventType`) ile ölçülür. Bu API Input Monitoring izni
istemez ve tuş vuruşlarını görmez; yalnızca son girdiden bu yana geçen
saniyeyi verir.

### Bildirim

Yerde geçen süre 1:00, 2:00, 3:00 ... sınırlarını geçtiğinde bir
bildirim gönderilir. Timer durmaz, oturum kapanmaz. Her sınır için
tam olarak bir bildirim üretilir.

## 6. Arayüz

### Menubar

`Petra Roas… · 2:14` — yer adı 12 karakterde kesilir, yanında yerde
geçen süre. Hata durumları: `◷ İzin gerekli`, `◷ Bilinmeyen yer`.

### Panel (`menuBarExtraStyle(.window)`)

Yukarıdan aşağı:
1. Yer adı + kalem ikonu (yerinde düzenleme)
2. **2:14** büyük punto, altında `Aktif çalışma 1sa 47dk`
3. Bugünün oturumları: `Ev 09:10–11:30 · Petra Roasting 12:40–…`
4. İzin durumu (sorun varsa kırmızı) ve Çıkış

Ayarlar ekranı yoktur.

## 7. İzinler ve Açılışta Başlatma

İzinler opsiyonel değildir; uygulamanın çalışma şartıdır.

İlk açılışta karşılama penceresi sırayla ister:
- **Konum (When In Use)** — SSID/BSSID okumanın ön şartı ve mekân
  ismi önerisi için gerekli
- **Bildirimler** — saatlik uyarı için

İzin verilmeden takip başlamaz; pencere "Sistem Ayarları'nı aç"
düğmesiyle bekler. İzin sonradan geri alınırsa menubar `İzin gerekli`
durumuna düşer ve tıklanınca aynı ekrana götürür.

Karşılama akışının son adımı **`SMAppService.mainApp.register()`** ile
login item kaydıdır. Bu olmadan "bilgisayarı açtığım anda başlasın"
gereksinimi hiç çalışmaz.

## 8. Veri Saklama

`~/Library/Application Support/PlaceTimer/` altında üç JSON dosyası,
atomik yazımla:

| Dosya | İçerik |
|---|---|
| `places.json` | `[{id, ssids[], bssids[], displayName, lat, lon, createdAt}]` |
| `sessions.json` | `[{id, placeId, startedAt, endedAt, activeSeconds}]` |
| `state.json` | Açık oturum + son uyku anı + gönderilmiş bildirim sınırları |

SwiftData/CoreData yerine JSON: yılda birkaç yüz kayıt, şema göçü
gereksiz, dosya `cat` ile okunabilir. `state.json` sayesinde uygulama
çökse veya güncellense bile açık oturum kaldığı yerden devam eder.

## 9. Kod Yapısı

```
PlaceTimer/
  Core/        SessionEngine.swift, Models.swift, Clock.swift
  Services/    WiFiMonitor, LocationService, PowerMonitor,
               IdleMonitor, Notifier
  Storage/     PlaceStore, SessionStore, AppStateStore
  UI/          MenuBarLabel, PanelView, PlaceNamingView,
               OnboardingView
  Tests/       SessionEngineTests
```

**Temel karar:** `SessionEngine` hiçbir sistem API'sine dokunmaz.
Girdileri sade olaylardır (`.wake`, `.sleep`, `.placeChanged(id)`,
`.idleSeconds(n)`) ve saat dışarıdan enjekte edilir. Wi-Fi, konum,
uyku ve hareketsizlik okuyan modüller bu çekirdeğin etrafında ince
sarmalayıcılardır.

### Modül sorumlulukları

| Modül | Ne yapar | Neye bağlı |
|---|---|---|
| `SessionEngine` | Durum makinesi, iki sayaç, bildirim sınırları | Yalnız `Clock` |
| `WiFiMonitor` | SSID/BSSID okur, değişimi bildirir | CoreWLAN |
| `LocationService` | Koordinat + en yakın 3 POI önerisi | CoreLocation, MapKit |
| `PowerMonitor` | Uyku/uyanma, kilit/kilit açma olayları | NSWorkspace, DistributedNotificationCenter |
| `IdleMonitor` | Son girdiden bu yana saniye | CoreGraphics |
| `Notifier` | Saatlik bildirim | UserNotifications |
| `*Store` | JSON okuma/yazma | Foundation |

## 10. Test Stratejisi

Test ağırlığının tamamı `SessionEngine`'dedir. Saat enjekte edildiği
için senaryolar beklemeden koşar:

- 45 dk uyku → aynı oturum devam eder
- 90 dk uyku → yeni oturum başlar
- Uyku sırasında SSID değişti → eski oturum uyku anında kapanır
- Ekran kilitliyken aktif sayaç durur, yerde geçen süre akar
- 5 dk hareketsizlik → aktif sayaç durur, girdi gelince devam eder
- 2:00 sınırı geçildi → tam olarak bir bildirim
- Wi-Fi kesildi → `Bilinmeyen yer`, oturum kapanmaz

Servis katmanı ince sarmalayıcı olduğundan elle doğrulanır.

## 11. Riskler ve İnşa Sırası

**Ana risk (çözüldü — 2026-09-04):** macOS 14'ten beri SSID okuma
Konum Servisleri iznine bağlı; macOS 27'de de öyle olduğu ölçüldü.
İmzalı bir bundle'da izinden önce `ssid` ve `bssid` `nil` dönüyor,
izin verildiği anda ikisi de okunabiliyor. Tasarım geçerli.

`requestWhenInUseAuthorization()` macOS'ta `authorizedAlways`
statüsünü veriyor; `authorizedWhenInUse` bu platformda yok.
TCC kararı ile CoreWLAN'ın onu görmesi arasında kısa bir gecikme
olabiliyor — okuma yeniden denenebilir olmalı.

İnşa sırası:

1. ~~SSID doğrulama denemesi~~ — tamamlandı
2. `SessionEngine` + testleri
3. Depolama katmanı
4. Servis katmanı
5. Arayüz ve karşılama akışı

## 12. Ortam Notu

Makinede yalnızca Xcode 27.0 **beta** kurulu
(`/Applications/Xcode-beta.app`) ve `xcode-select` hâlâ Command Line
Tools'u gösteriyor. Build komutları
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`
öneki ile çalıştırılır; `sudo xcode-select -s` gerekmez.
