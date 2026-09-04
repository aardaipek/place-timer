# PlaceTimer

Nerede ne kadar oturdugunu kendiliginden takip eden bir macOS menubar
uygulamasi. Baslat/durdur dugmesi yok: bilgisayari actiginda bulundugun yeri
Wi-Fi agindan tanir, o yerdeki oturumu baslatir ve gecen sureyi menubar'da
gosterir. Her saat basi bildirim gonderir.

```
Petra Roas… · 2:14
```

## Nasil calisir

- **Yer kimligi** bagli olunan SSID kumesidir. Router'lar 2.4 ve 5 GHz
  bantlarini ayri adlarla yayinladigi icin bir yer birden cok SSID tutabilir.
  Ayni SSID kayitli koordinattan 300 m'den uzaktaysa zincir sube olarak sorulur.
- **Oturum**, 60 dakikayi asan uykuda ya da yer degistiginde kapanir. Kisa
  molalar (kahve almak, tuvalet) oturumu bozmaz.
- **Iki sayac** paralel isler: menubar'daki *yerde gecen sure* duvar saatidir;
  panel ayrica *aktif calisma suresini* gosterir (ekran acik ve son girdiden
  bu yana 5 dakikadan az gecmisse sayar).

Tasarimin tamami: [`docs/superpowers/specs/2026-09-04-place-timer-design.md`](docs/superpowers/specs/2026-09-04-place-timer-design.md)

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
Scripts/build-app.sh --install
open /Applications/PlaceTimer.app
```

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
| `PlaceTimerCore` | Oturum durum makinesi, yer eslesme, JSON depolama | Yok (saf Foundation) |
| `PlaceTimerKit` | Wi-Fi, konum, uyku, hareketsizlik, bildirim, arayuz | AppKit, CoreLocation, CoreWLAN |
| `PlaceTimerApp` | Yalnizca giris noktasi | PlaceTimerKit |

`PlaceTimerCore` hicbir sistem cercevesine dokunmaz ve zaman her cagriya
disaridan gecilir; "90 dakika uyuyup uyandi" gibi senaryolar bu sayede gercek
zaman beklenmeden test edilir.
