# Guideline 2.1 — Information Needed (yanit plani)

Reddedilen bir sey yok: hesabin inceleme gecmisi kisa oldugu icin Apple standart
bilgi paketini istiyor. Yeni derleme yuklenmez; mevcut derleme incelemede kalir.
Yapilacak iki sey var: **ekran kaydi** + **asagidaki metin** (hem Resolution
Center yanitinda hem App Review Information → Notes alaninda).

## 1. Ekran kaydi

Sartlar: gercek bir Mac'te (sanal makine degil), guncel macOS'ta, **uygulamanin
acilisiyla baslayan**, tipik kullanim akisini gosteren tek parca kayit.
Hesap / kullanici icerigi / ucretli icerik olmadigi icin o uc madde bize islemiyor.

Kaydedilecek derleme TestFlight'taki magaza derlemesi olmali (gonderilen ikili).

### Hazirlik

```bash
# izinleri ve veriyi sifirla ki ilk acilis akisi gorunsun
tccutil reset All com.ardaipek.placetimer
rm -rf ~/Library/Containers/com.ardaipek.placetimer
```

Cmd+Shift+5 → tum ekran, "Show Mouse Clicks" acik. Menu cubugu kadraja girmeli.
Hedef sure 2–3 dakika, kesme yok, imlec yavas.

### Cekim listesi

1. Masaustu, Applications klasoru, `PlaceTimer.app` cift tiklanir. (Kayit
   acilisla baslamak zorunda.)
2. Konum izni dialogu → Allow. Imlec menu cubugundaki uygulama ogesine goturulur.
3. Bildirim izni → Allow.
4. "Burasi neresi?" sorusu → onerilen ad secilir ya da elle yazilir → kaydedilir.
5. Menu cubugunda "Yer · 0:01" isler. Tiklanir, panel acilir: yer adi, buyuk
   sayac, aktif calisma suresi, gun seridi.
6. Panelde manuel kontrol: yeri elle degistir, yeni yer olustur, sayaci sifirla.
7. Disli → Ayarlar: Genel, Yerler, Izinler, Istatistik (yer basina cubuklar,
   bir oturumu sil), Hakkinda (surum, gizlilik metni, tum verileri sil).
8. Panelden cikis.

### Gonderme

Dosya Resolution Center'a dogrudan eklenebiliyorsa oradan eklenir. Boyut
tutmazsa H.264'e sikistirilip herkese acik bir baglanti verilir (unlisted
YouTube ya da "anyone with the link" Drive/Dropbox). Apple oturum acamaz,
baglanti giris istemeyecek.

## 2. Resolution Center yaniti / Notes metni (Ingilizce, kopyala-yapistir)

```
Thank you for the review. PlaceTimer has no accounts, no user-generated content,
no in-app purchases and no subscriptions, so account registration/deletion,
content reporting/blocking and paid-content flows do not apply. Answers below.

1. SCREEN RECORDING
A screen recording captured on a physical Mac running the latest macOS is
attached. It starts with launching the app from the Applications folder and
shows the complete typical flow: granting Location and Notification permission,
naming the current place, the running timer in the menu bar, the main panel,
manual place switching, Settings (General, Places, Permissions, Statistics,
About) and deleting all data.

IMPORTANT FOR TESTING: PlaceTimer is a menu bar app with no Dock icon
(LSUIElement is true in Info.plist). After launching it, nothing appears in the
Dock and no window opens. The app appears as a timer item on the right side of
the menu bar. Click that menu bar item to open the main panel; the gear button
in the panel opens Settings.

2. PURPOSE AND TARGET AUDIENCE
PlaceTimer automatically tracks how much time you spend at each place you work
from. There is no start or stop button. When you open your Mac, the app
recognizes where you are from the name of the Wi-Fi network you are connected
to, starts a session for that place, and shows the elapsed time in the menu bar.

Problem it solves: people who work from several locations (home, office, cafes,
coworking spaces) either forget to start a manual timer or stop tracking
altogether. PlaceTimer removes the manual step entirely, so the record is
complete and honest without any effort.

Target audience: freelancers, remote and hybrid workers, students, and anyone
who splits the week between multiple places and wants to know where their time
actually went. The app is rated 4+ and contains no sensitive content.

3. SETUP AND ACCESS INSTRUCTIONS
No login credentials or sample files are needed. There is no account system and
no gated content; every feature is available immediately after launch.

- Launch the app. It lives in the menu bar only (see note above).
- Grant Location permission when asked. This permission is REQUIRED for the
  app's core function: since macOS 14, the name (SSID) of the connected Wi-Fi
  network can only be read when Location Services permission is granted. If it
  is denied, the menu bar shows "Izin gerekli" (= "Permission required") and no
  place can be recognized. Location data never leaves the device.
- Grant Notification permission for the optional hourly reminder.
- If the Mac is connected to a Wi-Fi network, the app asks once where you are.
  Enter any name or pick a suggested nearby venue; the menu bar timer then runs
  with that name and the app never asks again for that network.
- If the Mac is NOT on Wi-Fi (for example on Ethernet), the app still works:
  open the panel from the menu bar and create or select a place manually. All
  other features, including Statistics, work the same way.
- Settings are opened with the gear button in the panel and contain General,
  Places, Permissions, Statistics and About sections.

The app's interface is currently localized in Turkish only. Key terms:
"Yerler" = Places, "Izinler" = Permissions, "Istatistik" = Statistics,
"Hakkinda" = About, "Burasi neresi?" = "Where is this?",
"Yeni yer olustur" = "Create new place", "Tum verileri sil" = "Delete all data".

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
The app has no backend of its own. There is no server, no account system, no
analytics, no advertising, no payment processor, no AI service and no
third-party SDKs of any kind. It uses only Apple frameworks:

- CoreLocation - location permission, required to read the Wi-Fi network name
- CoreWLAN - reads the SSID of the currently connected network
- MapKit (MKLocalSearch) - the only outbound network request in the app: when
  the Mac connects to an unknown network, the current coordinate is sent to
  Apple Maps to suggest nearby venue names so the user does not have to type
  one. Naming the place manually skips this request entirely.
- UserNotifications - the optional hourly reminder
- ServiceManagement (SMAppService) - the optional "launch at login" setting
- SwiftUI and AppKit for the interface

All user data (saved places and session history) is stored as plain JSON files
inside the app's sandbox container and never leaves the device. The user can
delete everything at any time from Settings > About. This matches our App
Privacy declaration of "Data Not Collected".

5. REGIONAL DIFFERENCES
None. The app behaves identically in every region. There is no region-gated
content, no server-side configuration and no regional feature flags, because the
app has no server at all. The interface is localized in Turkish only.

6. REGULATED INDUSTRY / PROTECTED THIRD-PARTY MATERIAL
Not applicable. The app does not operate in a regulated industry and contains no
third-party or licensed material. All interface assets and the app icon are
original work by the developer. There is no user-generated content and no web
content.
```

## 3. Kontrol listesi

- [ ] Kayit gercek Mac'te, guncel macOS'ta, uygulama acilisiyla basliyor
- [ ] Kayitta konum + bildirim izni verilisi ve "Burasi neresi?" akisi var
- [ ] Video Resolution Center'a eklendi ya da girissiz bir baglanti verildi
- [ ] Ayni metin App Review Information → Notes alanina da yapistirildi
- [ ] Ekran goruntuleri gercek arayuzu gosteriyor (2.3.3 icin zaten uygun)
- [ ] Yeni derleme YUKLENMEDI (istenmedi)
