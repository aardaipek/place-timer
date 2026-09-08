# PlaceTimer

Nerede ne kadar oturdugunu kendiliginden takip eden bir macOS menubar
uygulamasi. Baslat/durdur dugmesi yok: bilgisayari actiginda bulundugun yeri
Wi-Fi agindan tanir, o yerdeki oturumu baslatir ve gecen sureyi menubar'da
gosterir. Her saat basi bildirim gonderir.

```
Petra Roas… · 2:14
```

Gereksinim: **macOS 26+** (Liquid Glass arayuz).

## Nasil calisir

- **Yer kimligi** bagli olunan SSID kumesidir. Router'lar 2.4 ve 5 GHz
  bantlarini ayri adlarla yayinladigi icin bir yer birden cok SSID tutabilir.
  Ayni SSID kayitli koordinattan 300 m'den uzaktaysa zincir sube olarak sorulur.
- **Oturum**, uyku esigini asan uykuda ya da yer degistiginde kapanir. Esik
  ayarlanabilir: "Hemen" secilirse kapak kapandigi an oturum biter, daha uzun
  bir esikte kisa molalar (kahve almak, tuvalet) oturumu bozmaz.
- **Iki sayac** paralel isler: menubar'daki *yerde gecen sure* duvar saatidir;
  panel ayrica *aktif calisma suresini* gosterir (ekran acik ve son girdiden
  bu yana esik suresinden az gecmisse sayar).
- **Gun seridi** gunun ilk oturumundan simdiye uzanir, yerlere gore renklidir.
  Oturumlar arasi bosluklar bos gorunur.
- **Manuel kontrol**: otomasyon yanilirsa panelden sayaci sifirlayabilir, yeri
  elle degistirebilir ya da yeni bir yer olusturabilirsin. Bilgisayar henuz bir
  aga baglanmamisken de calisir. Manuel secim, o anki agda kalindigi surece
  otomatik eslesmeyi bastirir.
- **Duzeltme**: iki kayit ayni yerse birlestirilebilir (aglari ve gecmisteki
  sureleri hedefe gecer); yanlis acilmis bir oturum tek tek silinebilir.

## Ayarlar

Menubar panelindeki disli dugmesi ayarlar penceresini acar. Pencerenin
solundaki kenar cubugunda dort bolum var:

| Bolum | Icerik |
|---|---|
| Genel | Saniye gosterimi, menubar'da yer adi, esikler, bildirim sikligi, acilista baslat |
| Yerler | Kayitli yerler: ad degistir, SSID ayir, baska yerle birlestir, sil |
| Izinler | Konum / bildirim / giris ogesi durumu ve duzeltme |
| Istatistik | Bugun / bu hafta / bu ay: yer basina toplam ve o araliktaki oturumlar; yanlis oturum silinebilir |
| Hakkinda | Surum, gizlilik, verilerin yeri, tum verileri sil |

Tasarim dokumanlari:
[v1](docs/superpowers/specs/2026-09-04-place-timer-design.md) ·
[v2](docs/superpowers/specs/2026-09-05-place-timer-v2-design.md)

## Izinler

Ikisi de zorunludur:

- **Konum** — macOS 14'ten beri Wi-Fi ag adi yalnizca bu izinle okunabiliyor.
  Izin yoksa yer tespiti hic calismaz. Ayrica yakindaki mekan ismini onermek
  icin kullanilir.
- **Bildirimler** — saat basi uyarilar icin.

Konum verisi cihazdan disari cikmaz; hicbir sunucuya bir sey gonderilmez.
Tum veri `~/Library/Application Support/PlaceTimer/` altinda duz JSON olarak
tutulur.

## Kurulum

```bash
Scripts/make-icon.sh               # simgeyi uretir (bir kez yeterli)
Scripts/build-app.sh --install     # derler, imzalar, /Applications'a kurar
open /Applications/PlaceTimer.app
```

Imza kimligi `.codesign-identity` dosyasinda sabittir. macOS izinleri paket
kimligi + imza ciftine bagladigi icin kimlik degisirse tum izinler sifirlanir.

Sifirdan baslamak icin (mevcut veri yanina `.bak` olarak tasinir, silinmez):

```bash
Scripts/build-app.sh --fresh
```

Uygulamayi kaldirmak icin `/Applications/PlaceTimer.app` silinir; veri
`~/Library/Application Support/PlaceTimer/` altinda kalir.

Betik uygulamayi derler, `.app` paketini kurar ve makinedeki gelistirici
sertifikasiyla imzalar. Izinler imzali bir bundle gerektirdigi icin imza adimi
atlanamaz.

## Gelistirme

```bash
swift test          # cekirdek mantik, ~0.1 sn
swift build         # tum hedefler
```

Kod uc katmana ayrilmistir:

| Hedef | Icerik | Bagimlilik |
|---|---|---|
| `PlaceTimerCore` | Oturum durum makinesi, yer eslesme, tercihler, istatistik, JSON depolama | Yok (saf Foundation) |
| `PlaceTimerKit` | Wi-Fi, konum, uyku, hareketsizlik, bildirim, arayuz | AppKit, CoreLocation, CoreWLAN |
| `PlaceTimerApp` | Yalnizca giris noktasi | PlaceTimerKit |

`PlaceTimerCore` hicbir sistem cercevesine dokunmaz ve zaman her cagriya
disaridan gecilir; "90 dakika uyuyup uyandi" gibi senaryolar bu sayede gercek
zaman beklenmeden test edilir.
