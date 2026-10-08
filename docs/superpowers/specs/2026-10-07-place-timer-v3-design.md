# PlaceTimer v3 — Doğru Ölçüm, Öneriler ve Liquid Glass Ayarlar

**Tarih:** 2026-10-07
**Durum:** Uygulandı, TestFlight'ta (1.1.0, derleme 5)
**Önceki tasarım:** [v2, 2026-09-05](2026-09-05-place-timer-v2-design.md)

## 1. Neden

PlaceTimer'ın cevapladığı soru şu: **"Laptopla ne kadar vakit geçirdim, nerede?"**
Günlük, haftalık, aylık. İçeride ne yapıldığı önemsiz — Claude'a prompt verip
agent'ı beklemek de, Netflix de süre. Klavye/fare etkinliği artık bir
çalışmanın ölçüsü değil: agent çalışırken kullanıcı mutfağa gidebilir, Mac'i
uyutmaz, iş sürer.

v2'nin motoru başka bir soruyu cevaplıyordu ("bu yerde kesintisiz ne kadar
oturdum, ne kadarı aktifti") ve kullanımda üç yanlış üretiyor:

1. **Oturumlar gereksiz bölünüyor.** En sık şikâyet: Wi-Fi kopup aynı ağa geri
   bağlanınca eski oturum kapanıyor, sayaç sıfırdan başlıyor. Ekran kararması
   uyku sayılıyor. Bant/AP geçişleri yer değişimi sayılıyor.
2. **Süre yanlış sayılıyor.** Uyumadan ekranı kapalı bekleyen bir Mac geceyi
   süreye yazıyor (gözlenen: 22:51–07:30, 8sa 38dk). Geceyi aşan oturum
   tamamen başladığı güne yazılıyor.
3. **Asıl soru hiçbir ekranda cevaplanmıyor.** "Bugün toplam" yok, geçmiş
   haftalara/aylara gidilemiyor, trend yok.

Bunlara ek olarak otomatik takip yanıldığında düzeltme yükü tümüyle
kullanıcıda; ayarlar penceresi de macOS 26'nın görsel dilinin gerisinde.

## 2. Kapsam

| Girer | Girmez |
|---|---|
| Tek "ara eşiği" ile yeni oturum kuralı | 5 saatlik AI kullanım limitleri |
| Aynı yere dönüşte oturumun geri açılması | Uygulama adı / "Focus" konumlandırması |
| Yer değişimine kararlılık süresi | iCloud senkronu |
| Ekran kapalı uyanık Mac'in doğru sayılması | Uygulama bazlı takip |
| Oturumların gün sınırında bölünmesi | Hedef süreler |
| Gün toplamı, geçmiş gezinme, haftalık grafik | |
| Birleştirme önerileri (yer + oturum) | |
| Oturumları elle birleştirme, saat düzeltme | |
| Liquid Glass ayarlar penceresi | |
| Tutarlı saat biçimi, CSV dışa aktarma | |
| Yerel olay günlüğü (teşhis) | |

"v3" bu tasarım belgelerinin sırası; mağazadaki sürüm numarası ayrıdır. Bu iş
**1.1.0** olarak çıkar (`CFBundleShortVersionString` 1.0.0 → 1.1.0).
İncelemedeki derleme 4 bu işten bağımsızdır; v3 onun üstüne gelir.

## 3. Oturum modeli

### 3.1 Tek kavram: ara

Uyku, ekranın kararması, ekran koruyucu, kilit ve hiç dokunmamak aynı şeydir:
**ara**. Aranın nedeni değil, süresi önemlidir.

- Ara **eşikten kısa** → oturum sürer, ara süreye dahildir.
- Ara **eşikten uzun** → oturum **aranın başladığı anda** kapanır. Ara süreye
  girmez. Kullanıcı döndüğünde yeni oturum açılır.

Aranın başlangıcı:

| Olay | Aranın başladığı an |
|---|---|
| Sistem uykusu (`willSleep`) | Uykuya dalma anı |
| Uygulama kapalıydı | Son yaşam belirtisi (`lastHeartbeatAt`) |
| Uyanık ama dokunulmuyor (ekran kapalı, kilitli, screensaver) | Son giriş anı = `now - idleSeconds` |

Son satır yeni: uyanık Mac'te `idleSeconds` eşiği aştığı ilk tick'te oturum
`now - idleSeconds` anında kapanır. Kullanıcı geri dönüp bir tuşa bastığında
(`idleSeconds` eşiğin altına iner) yeni oturum açılır — ya da §3.3 gereği
eskisi geri açılır. Gece ekranı kapalı uyanık kalan Mac böylece geceyi
yazmaz.

`screensDidSleep`/`screensDidWake` artık uyku olayı üretmez. Ekran kapalıyken
de `idleSeconds` artmaya devam ettiği için ayrı bir olaya gerek yoktur; agent
bekleyen kullanıcının oturumu eşiğe kadar sürer.

**Ayar:** Genel → Oturum → **"Ara eşiği"**: 15 dk · **30 dk (varsayılan)** ·
1 saat · 2 saat. Açıklama satırı: "Bilgisayardan bu süreden uzun uzak
kalırsan oturum, ayrıldığın anda biter."

"Uyku eşiği" ve "Hareketsizlik eşiği" kalkar. "Hemen" seçeneği kalkar: ekran
kararmasını da ara saydığımız için "Hemen", kullanıcı her bakışını
kaçırdığında oturumu bölerdi.

### 3.2 Yer değişimine kararlılık süresi

Bilinen bir yerden **başka bir bilinen yere** geçiş anında uygulanmaz. Yeni
yer **3 dakika** boyunca kesintisiz çözülmeye devam ederse geçiş onaylanır;
eski oturum **ilk gözlem anında** kapanır, yenisi o anda başlamış sayılır
(yeni yerdeki 3 dakika kaybolmaz). 3 dakika dolmadan eski yer geri gelirse
hiçbir şey olmamış sayılır.

Bilinmeyen yer (`.unknown`, Wi-Fi yok) oturumu hâlâ kapatmaz ve kararlılık
sayacını sıfırlamaz — bilinmeyen bir anı ne eski ne yeni yerin lehine sayar.

Uykudan uyanıp yer değişmişse (§3.1'deki ilk satır) kararlılık beklenmez:
eski oturum zaten uykuya dalma anında kapanmıştır.

### 3.3 Aynı yere dönüş: oturum geri açılır

**En sık şikâyetin doğrudan çözümü.** Yeni bir oturum açılacağı her anda motor
son kapanan oturuma bakar:

- Aynı yer (`placeID` eşit, ya da biri `nil`) **ve**
- Kapanışından bu yana geçen süre **ara eşiğinden kısa**

ise yeni oturum açılmaz; son oturum geri açılır (`endedAt = nil`). Aradaki
süre §3.1 gereği oturuma dahildir. Sayaç kaldığı yerden devam eder, liste
tek satır kalır, bildirim işaretleri korunur.

Bu kural nedeni sorgulamaz: Wi-Fi kopması, kısa bir başka ağ, yanlış bir
"şube" çözümlemesi, uygulamanın çöküp açılması — hepsi aynı sonuca varır.

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

Kullanıcının "Oturumu bitir" komutuyla kapattığı oturum geri açılmaz
(`recentlyEnded` temizlenir) — kullanıcı açıkça bitirdi.

### 3.4 Gün sınırı

Oturumlar diskte bölünmez (tek kayıt, tek kimlik). İstatistik ve gün şeridi
her oturumu sorgulanan aralığa **kırpar**: 23:00–01:00 oturumu bugüne 1 saat,
yarına 1 saat yazar. `placeTotals`, `sessionsIn` ve hafta/ay toplamları
`startedAt` filtresi yerine aralık kesişimi kullanır.

### 3.5 "Aktif süre"

Arayüzden kalkar (panel, istatistik). `Session.activeSeconds` alanı okumaya
devam eder (eski dosyalar bozulmasın) ama artık yazılmaz ve gösterilmez.
`idleThreshold` ayarı ve `maxTickDelta` yalnızca bunun için vardı; kalkar.

### 3.6 Teşhis: olay günlüğü

`events.log` (uygulama destek dizini, düz metin, en fazla 14 gün, satır
başına bir olay): uyku/uyanma, ekran, Wi-Fi gözlemi (SSID, BSSID, koordinat
doğruluğu), yer çözümü, oturum aç/kapat/geri aç. Ayarlar → Hakkında'da
"Günlüğü göster" (Finder'da açar). Gizlilik: cihazdan çıkmaz, "Tüm verileri
sil" bunu da siler, gizlilik politikasına bir satır eklenir.

Amaç, Wi-Fi bölünmesinin gerçek nedenini (konum kayması mı, kısa ağ geçişi mi)
veriyle görmek ve gerekiyorsa kararlılık süresini ayarlamak.

## 4. İstatistik

### 4.1 Panel

"Bu oturum" sayacı kalır. Altındaki satırlar:

- **Bugün toplam** — bütün yerlerin bugünkü toplamı (asıl soru).
- **Bugün burada** — bu yerin bugünkü toplamı. Yalnızca bugün birden çok yer
  varsa görünür; tek yer varsa toplamla aynı sayıdır.
- **Başlangıç** — oturumun başladığı saat.

### 4.2 İstatistik sayfası

Üstten aşağıya:

1. **Araç çubuğu:** Gün · Hafta · Ay seçici ve `‹ ›` ile önceki/sonraki aralık
   ("Bu hafta", "Geçen hafta", "22–28 Eyl"). Bugünün aralığına dönen "Bugün"
   düğmesi. Pencerenin araç çubuğunda durur (glass, §6).
2. **Özet:** Büyük toplam ("31sa 20dk") ve önceki aynı aralıkla fark
   ("geçen haftadan 2sa 10dk fazla"). Gün görünümünde günün gün şeridi.
3. **Grafik (Swift Charts):** Hafta → 7 gün, ay → günler; her çubuk yerlere
   göre renk yığınlı. Gün görünümünde grafik yerine saatlik zaman çizelgesi
   (mevcut gün şeridinin büyüğü).
4. **Yerler:** Yer başına toplam ve oran. "Oturum sayısı" kalır, "Aktif" kalkar.
5. **Oturumlar, günlere bölünmüş:** Bölüm başlıkları "Bugün", "Dün",
   "Pzt 29 Eyl" ve o günün toplamı. Satırda ana metin saat aralığı, yer adı
   ikincil; yer adı yalnızca o gün birden çok yer varsa görünür. Satır içi
   "Sil" linki kalkar.

Satırdaki işlemler `contextMenu` ve seçim üzerinden: **Düzenle…**,
**Öncekiyle birleştir**, **Sil** (⌫ ile de). Çoklu seçimde **Birleştir**.

### 4.3 Elle düzeltme

- **Birleştir:** Aynı yerdeki iki ya da daha çok oturum tek oturum olur:
  başlangıç en erken, bitiş en geç, aradaki boşluk dahil. Farklı yerlerdeki
  oturumlar birleştirilemez (menü öğesi pasif, nedeni ipucunda). Açık oturum
  birleştirmeye katılabilir; sonuç açık kalır.
- **Düzenle…:** Başlangıç ve bitiş saati, yer. Komşu oturumla çakışma
  engellenir (kaydet pasif, nedeni altta yazar).

Saf fonksiyonlar `SessionHistory`'ye eklenir: `merge(_ ids:in:)`,
`update(_:in:)`, ve geri al için önceki dizi döner. Her düzeltme `⌘Z` ile
geri alınabilir (`UndoManager`).

## 5. Öneriler

Kullanıcının düzeltme yükünü almak için uygulama aday düzeltmeleri kendisi
bulur, kullanıcı tek tıkla onaylar ya da reddeder.

### 5.1 Öneri türleri

| Tür | Ne zaman | Onaylanınca |
|---|---|---|
| **Aynı yer** | İki yerin adı aynı (büyük/küçük harf ve boşluk duyarsız) **ya da** koordinatları 150 m içinde | `catalog.merge` + `SessionHistory.reassign` (mevcut akış) |
| **Bölünmüş oturum** | Aynı yerde, arası ara eşiğinin 3 katından kısa ardışık iki oturum (§3.3'ün yakalamadığı, eşiği biraz aşan aralar) | `SessionHistory.merge` |
| **Boş oturum** | 2 dakikadan kısa kapanmış oturum | `SessionHistory.remove` |

Öneriler saf bir fonksiyondan çıkar: `suggestions(places:sessions:dismissed:gapThreshold:) -> [Suggestion]`.
Her öneri kararlı bir kimlik taşır (ilgili kimliklerden türetilir); reddedilen
kimlikler `suggestions.json`'da saklanır ve o öneri bir daha çıkmaz.

### 5.2 Nerede görünür

- **Panel:** En fazla bir öneri kartı, mevcut yer sorusu kartının yerinde
  (yer sorusu varsa o önce gelir). "Bu iki 'Home' aynı yer mi?" —
  **Birleştir** / **Ayrı kalsın**. Kart birden çok öneri varsa "+3 öneri"
  ile istatistik sayfasına bağlanır.
- **İstatistik sayfası:** Özetin altında, öneri varsa bir "Öneriler" bölümü:
  her satırda tek cümle açıklama, **Uygula** ve **Yoksay**. Üstte
  **Tümünü uygula**.
- Bölünmüş oturum önerisinin ikinci düğmesi: "Eşiği 1 saate çıkar" —
  kullanıcının aynı aralığı tekrar tekrar birleştirdiği görülürse sunulur
  (aynı türden 3 onay sonrası).

Öneriler bildirim üretmez; panel açıldığında görülür.

### 5.3 Var olan veri

İlk açılışta öneri fonksiyonu tüm geçmişe çalışır: kullanıcının bugünkü iki
"Home"u ve bölünmüş oturumları ilk gün öneri olarak gelir. Geriye dönük
otomatik birleştirme yapılmaz — geçmişe dokunmak her zaman onayla olur.

## 6. Ayarlar penceresi: Liquid Glass

macOS 26'da Liquid Glass içerik değil **gezinme ve kontrol katmanı** içindir
(HIG). Ayarlar penceresinde bu şu demek: kenar çubuğu ve araç çubuğu cam,
içerik standart gruplu form. Bugünkü pencere eski görünüyor çünkü bu katmanın
hiçbiri cam değil:

- `AppWindow` `styleMask = [.titled, .closable]` — tam boy içerik yok, araç
  çubuğu yok. Kenar çubuğu bu yüzden pencere kenarına yapışık, düz gri bir
  sütun olarak çiziliyor; macOS 26'nın yüzen cam kenar çubuğu çıkmıyor.

Değişiklikler:

1. **Pencere:** `.fullSizeContentView` + `.titled` + `.closable` +
   `.miniaturizable`, `titlebarAppearsTransparent`, birleşik araç çubuğu
   (`toolbarStyle = .unified`). Kenar çubuğu sistemin yüzen cam paneli olur.
2. **Kenar çubuğu:** `NavigationSplitView` kalır, kenar çubuğu açma/kapama
   düğmesi kalkar (`.toolbar(removing: .sidebarToggle)`); pencere sabit ölçülü,
   kenar çubuğu her zaman görünür. Simgeler SF Symbols, tek renk.
   `backgroundExtensionEffect` kullanılmaz: o, kenar çubuğunun altına uzanacak
   bir görsel (fotoğraf, harita) içindir; gruplu formda yalnızca bulanık bir
   şerit üretir.
3. **Araç çubuğu:** Her bölümün başlığı ve bölüme özgü kontroller
   (İstatistik'te aralık seçici ve `‹ ›`, Yerler'de `+`) `toolbar` içinde.
   Bunlar otomatik olarak cam kapsüllere oturur. Bugün içeriğin tepesinde
   duran segmentli seçici oradan kalkar.
4. **İçerik:** Bütün bölümler `Form` + `.formStyle(.grouped)`; elle yapılmış
   kartlar kalkar. Düğmeler: birincil eylem `.glassProminent`, ikincil
   `.glass`, yıkıcı eylemler `role: .destructive`.
5. **Öneri ve yer sorusu kartları** (panel ve istatistik) `GlassEffectContainer`
   içinde `glassEffect(in: .rect(cornerRadius:))`, kart gelip giderken
   `glassEffectID` ile morph.
6. **Pencere boyu** büyür: İstatistik grafiği ve günlere bölünmüş liste
   430×460'a sığmıyor. Yeni sabit ölçü 720×560 (kenar çubuğu 200). Sabit
   kalma gerekçesi v2'deki gibi geçerli.
7. Panelde `•••` ve ⚙︎ düğmeleri `.glass` kalır ama `GlassEffectContainer`
   içinde tek grup olarak birleşir; bugünkü iki ayrı kapsül görüntüsü gider.

Reduce Transparency açıkken sistem camı kendisi opaklaştırır; ek iş yok.
Erişilebilirlik: araç çubuğuna taşınan her kontrolün metin etiketi olur.

## 7. Cila

- **Saat biçimi:** Arayüz yalnızca Türkçe olduğu için bütün saatler
  `tr_TR` yerel ayarıyla, 24 saat biçiminde yazılır ("12:36", "07:30").
  Panel, gün şeridi ve liste aynı `DurationFormat.time(_:)` yardımcısından
  geçer. Bugünkü karışıklık (panelde ve şeritte "12:36 PM", listede "12:36")
  böylece gider. Arayüz ileride yerelleştirilirse biçim de dille birlikte
  değişir.
- **CSV dışa aktarma:** İstatistik araç çubuğunda "Dışa aktar…" — seçili
  aralığın oturumları: `başlangıç, bitiş, süre_dk, yer`. `NSSavePanel`
  (sandbox: kullanıcı seçtiği konuma yazma yetkisi verir; entitlement
  `com.apple.security.files.user-selected.read-write` eklenir).

## 8. Veri göçü

- `preferences.json`: yeni `gapThreshold`. Yoksa eski
  `sessionResetSleepThreshold`'tan türetilir: en yakın seçeneğe yuvarlanır,
  0 ("Hemen") ve 5 dk → 15 dk; 4 saat → 2 saat. Eski anahtarlar okunur ama
  yazılmaz.
- `state.json`: yeni isteğe bağlı `recentlyEnded: [Session]`.
- `sessions.json`: şema değişmez.
- `suggestions.json`: yeni, `{ dismissed: [String] }`.

Hepsi `decodeIfPresent`; eski dosyalar bozulmaz.

## 9. Bileşenler ve sınırlar

| Birim | Katman | Değişiklik |
|---|---|---|
| `SessionEngine` | Core, saf | §3.1–3.3: `gapThreshold`, uyanık-ara, kararlılık, `recentlyEnded`, `.sessionResumed` |
| `EngineConfiguration`, `Preferences` | Core | `gapThreshold`; eski eşikler kalkar; göç |
| `Statistics` | Core, saf | Kırpma, gün/hafta/ay için `StatsPeriod` (aralık + kaydırma), günlük toplamlar, karşılaştırma |
| `SessionHistory` | Core, saf | `merge`, `update` |
| `Suggestions` (yeni dosya) | Core, saf | `Suggestion` tipi ve üretim fonksiyonu |
| `EventLog` (yeni) | Kit | Döner dosya, 14 gün |
| `PowerMonitor` | Kit | Ekran bildirimleri uyku üretmez |
| `AppCoordinator` | Kit | Yeni etkiler, öneri durumu, undo, dışa aktarma |
| `AppWindow` | Kit/UI | §6.1 pencere stili |
| Ayarlar view'ları | UI | §4.2, §6 |
| Panel view'ları | UI | §4.1, §5.2 |

Core'daki her şey saf kalır ve zamanı dışarıdan alır (v1 ilkesi).

## 10. Test

Core için birim testleri (`swift test`), mevcut stilde:

- **Ara:** 20 dk uyku → oturum sürer; 45 dk uyku → uykuya dalma anında kapanır.
  Uyanık, `idleSeconds` 31 dk → `now - 31dk`'da kapanır; tuşa basınca yeni
  oturum. Ekran kararması tek başına hiçbir şey değiştirmez.
- **Geri açma:** Wi-Fi kopar (`.unknown`) → oturum sürer. A → B (2 dk) → A →
  tek oturum. A'da oturum kapanır, 10 dk sonra A'da yeniden açılış →
  `.sessionResumed`, aynı kimlik. "Oturumu bitir" sonrası → geri açılmaz.
  Uygulama yeniden başlatma `recentlyEnded`'ı korur.
- **Kararlılık:** A → B 3 dk sürer → B'ye geçiş, eski oturum ilk gözlemde
  kapanır. A → B 2 dk → A → bölünme yok. A → unknown → B → sayaç doğru.
- **Kırpma:** 23:00–01:00 oturumu iki güne bölünür; hafta ve ay sınırı.
- **Birleştirme:** Aynı yer birleşir, farklı yer reddedilir, açık oturum açık
  kalır.
- **Öneriler:** Aynı ad farklı büyük harf → öneri; reddedilen kimlik bir daha
  çıkmaz; 3×eşik sınırının iki yanı.
- **Göç:** Her eski eşik değeri doğru yeni seçeneğe düşer.

UI: mevcut `#Preview`'ler güncellenir; ayarlar penceresi açık ve koyu temada,
Reduce Transparency açıkken elle kontrol edilir.

## 11. Uygulama sırası

Bütün adımlar **tek sürümde (1.1.0)** çıkar; sıra yalnızca geliştirme
sırasıdır. Sürüm, beş adım bitip TestFlight'ta denendikten sonra incelemeye
gönderilir.

1. Motor ve göç (§3, §8) — en sık şikâyeti çözer.
2. İstatistik çekirdeği (§3.4, §4 saf kısım) ve elle düzeltme (§4.3).
3. Öneriler (§5).
4. Ayarlar penceresi Liquid Glass ve yeni istatistik sayfası (§4.2, §6).
5. Panel (§4.1, §5.2), cila (§7), olay günlüğü (§3.6).

Her adım kendi başına derlenir ve testleri geçer.
