# Mac App Store'a gonderim

Kodda yapilmasi gerekenler bitti. Kalanlar Apple Developer hesabini gerektiriyor
ve bu depodan yapilamaz.

## Kodda bitenler

- **Sandbox acik.** `Resources/PlaceTimer.entitlements` uc entitlement tasiyor:
  `app-sandbox`, `personal-information.location` (CoreLocation + CoreWLAN),
  `network.client` (`MKLocalSearch`). Baska entitlement yok.
- **Yerel derleme de sandbox'li.** `Scripts/build-app.sh` ayni entitlement
  dosyasiyla imzaliyor ve sandbox'in imzaya girdigini dogruluyor; kirilan bir
  sey magazada degil, gelistirirken goruluyor.
- **`Info.plist` magaza alanlari**: `LSApplicationCategoryType`
  (productivity), `NSHumanReadableCopyright`, `ITSAppUsesNonExemptEncryption`
  (false), `LSMinimumSystemVersion` 26.0.
- **Gizlilik metni duzeltildi.** "Hicbir sunucuya bir sey gonderilmez" dogru
  degildi: taninmayan bir aga baglanildiginda `MKLocalSearch` o anki koordinati
  Apple Haritalar'a gonderiyor. Hem uygulama ici Hakkinda bolmesi hem README
  artik bunu soyluyor.

### Sandbox altinda dogrulananlar

Sandbox'li derleme kurulup calistirildi:

| Ne | Sonuc |
|---|---|
| Uygulama aciliyor, cokme yok | ✅ |
| Surec konteynere kapatilmis (`cwd` = konteyner `Data`) | ✅ |
| Konum izni korunuyor (menubar "Izin gerekli" demiyor) | ✅ |
| CoreWLAN SSID okunuyor, yer eslesiyor | ✅ |
| Yeni ag sorusu ve yer olusturma akisi | ✅ |
| Ayarlar penceresi aciliyor | ✅ |

Denenmeyenler: bildirim izni (`UNUserNotificationCenter`) ve acilista baslatma
(`SMAppService`). Ikisi de sandbox'ta desteklenen API'ler ama sandbox'li
derlemede elle bir kez dogrulanmali — Ayarlar > Izinler bolmesinden.

Veri artik konteynerin icinde:
`~/Library/Containers/com.ardaipek.placetimer/Data/Library/Application Support/PlaceTimer/`.
Eski konumdaki veri tasinmiyor; uygulama sifirdan basliyor.

## Yapilmasi gerekenler

### 1. Apple Developer hesabi

- Apple Developer Program uyeligi (yillik).
- **App ID**: `com.ardaipek.placetimer` — Certificates, Identifiers & Profiles
  altinda kayitli olmali.
- **Sertifikalar** (ikisi de anahtarliga inecek):
  - Apple Distribution (ya da 3rd Party Mac Developer Application)
  - Mac Installer Distribution (3rd Party Mac Developer Installer)
- **Provisioning profile**: App ID icin "Mac App Store" dagitim profili.

### 2. Paketleme

```bash
PROFILE=~/Downloads/PlaceTimer.provisionprofile Scripts/build-appstore.sh
```

`build/appstore/PlaceTimer.pkg` uretir. Betik sertifikalari anahtarlikta kendi
bulur; bulamazsa hangisinin eksik oldugunu soyler.

### 3. App Store Connect

- Uygulama kaydi (ad, birincil dil, paket kimligi, SKU).
- **Gizlilik beyani** — kodun gercekte yaptigiyla ortusmeli:
  - Toplanan veri: yok. Uygulamanin sunucusu yok, analitik yok, hesap yok.
  - Konum: cihazda kaliyor, disari cikmiyor.
  - `MKLocalSearch` cagrisi Apple'a gidiyor; bu bir ucuncu taraf toplama degil
    ama gizlilik metninde ve inceleme notunda anilmasi dogru olur.
- **Gizlilik politikasi URL'i** zorunlu.
- Ekran goruntuleri ve aciklama.
- **Inceleme notu**: uygulama menubar'da yasar, Dock simgesi yoktur
  (`LSUIElement`). Inceleyene menubar'daki sayaca tiklamasi ve konum iznini
  vermesi gerektigi yazilmali — yoksa uygulamanin hicbir sey yapmadigini
  dusunebilir. Konum izninin neden gerektigi de aciklanmali: macOS 14'ten beri
  Wi-Fi ag adi yalnizca bu izinle okunuyor.

### 4. Yukleme

`.pkg` dosyasi **Transporter.app** ile gonderilir. (`xcrun altool` artik
kullanimdan kaldirildi; `notarytool` App Store yuklemesi icin degil,
notarizasyon icindir — Developer ID ile dagitim yapilmadigi surece gerekmez.)

## Gonderim oncesi son gozden gecirme

- [ ] `CFBundleShortVersionString` ve `CFBundleVersion` dogru mu?
      (`Resources/Info.plist`)
- [ ] Bildirim izni ve acilista baslatma sandbox'li derlemede elle denendi mi?
- [ ] Uygulama ilk kez, hic verisi olmayan bir kullanicida denendi mi?
      `Scripts/build-app.sh --fresh` bunu yerelde yapar.
- [ ] `swift test` ve `swift build -Xswiftc -warnings-as-errors` temiz mi?

## Bilinen kirilganlik

`AppCoordinator.init` veri klasorunu olusturamazsa sessizce
`FileManager.default.temporaryDirectory`'ye dusuyor ve butun kayitlar
`try?` ile yazildigi icin hata hicbir yerde gorunmuyor. Sandbox'ta bugun
calisiyor, ama boyle bir durumda kullanici her acilista verisini kaybeder ve
sebebini anlayamaz. Magaza icin engel degil; duzeltilmesi yerinde olur.
