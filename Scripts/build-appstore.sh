#!/bin/bash
# Mac App Store icin imzali .pkg uretir.
#
# Gunluk gelistirme icin build-app.sh yeterli; bu betik yalnizca magazaya
# yollamadan once calistirilir. Ikisi ayni entitlement dosyasini kullanir,
# yani sandbox davranisi yerelde de magazadaki gibidir.
#
# Gereken ucu de Apple Developer hesabindan gelir:
#   - "Apple Distribution" ya da "3rd Party Mac Developer Application" sertifikasi
#   - "3rd Party Mac Developer Installer" sertifikasi
#   - App Store dagitimi icin provisioning profile (embedded.provisionprofile)
#
# Kullanim:
#   Scripts/build-appstore.sh                    # kimlikleri anahtarlikta arar
#   APP_IDENTITY="..." PKG_IDENTITY="..." Scripts/build-appstore.sh
#   PROFILE=~/Downloads/PlaceTimer.provisionprofile Scripts/build-appstore.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# Kurulu Xcode aranir: once beta, sonra kararli surum, en son xcode-select
# ayari. Sabit bir yol yazilmiyor; beta kaldirildiginda betik sessizce yanlis
# arac zincirine dusmesin diye.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  for candidate in /Applications/Xcode-beta.app/Contents/Developer \
                   /Applications/Xcode.app/Contents/Developer; do
    if [[ -d "$candidate" ]]; then
      DEVELOPER_DIR="$candidate"
      break
    fi
  done
fi
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR

APP_NAME="PlaceTimer"
CONFIGURATION="release"
BUNDLE="build/appstore/${APP_NAME}.app"
PKG="build/appstore/${APP_NAME}.pkg"
ENTITLEMENTS="Resources/PlaceTimer.entitlements"

# grep eslesme bulamazsa 1 doner; `set -e` altinda bu, betigin hicbir sey
# yazmadan olmesi demek olurdu. Kimlik yokken bos string donmesi gerekiyor ki
# asagidaki kontrol devreye girip ne eksik oldugunu soyleyebilsin.
find_identity() {
  security find-identity -v | grep -m1 "$1" | sed 's/.*"\(.*\)"/\1/' || true
}

APP_IDENTITY="${APP_IDENTITY:-$(find_identity "Apple Distribution")}"
if [[ -z "$APP_IDENTITY" ]]; then
  APP_IDENTITY="$(find_identity "3rd Party Mac Developer Application")"
fi
PKG_IDENTITY="${PKG_IDENTITY:-$(find_identity "3rd Party Mac Developer Installer")}"

if [[ -z "$APP_IDENTITY" || -z "$PKG_IDENTITY" ]]; then
  echo "hata: App Store dagitim sertifikalari bulunamadi." >&2
  echo "  uygulama : ${APP_IDENTITY:-YOK}" >&2
  echo "  yukleyici: ${PKG_IDENTITY:-YOK}" >&2
  echo >&2
  echo "developer.apple.com > Certificates uzerinden asagidakiler olusturulup" >&2
  echo "anahtarliga eklenmeli:" >&2
  echo "  - Apple Distribution (ya da 3rd Party Mac Developer Application)" >&2
  echo "  - Mac Installer Distribution (3rd Party Mac Developer Installer)" >&2
  echo >&2
  echo "Anahtarliktaki mevcut kimlikler:" >&2
  security find-identity -v | grep '"' >&2
  exit 1
fi

echo "==> Derleniyor ($CONFIGURATION)"
swift build -c "$CONFIGURATION" --product PlaceTimerApp

echo "==> Bundle kuruluyor"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$(swift build -c "$CONFIGURATION" --show-bin-path)/PlaceTimerApp" \
   "$BUNDLE/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

# Simge, Icon Composer belgesinden derleniyor. actool tek gecisde iki cikti
# birden verir: Assets.car (macOS 26'nin cam efekti ile koyu ve tonlu
# varyantlari buradan okunur) ve geriye donuk AppIcon.icns. Info.plist'teki
# CFBundleIconName ilkini, CFBundleIconFile ikincisini isaret eder.
ICON="Resources/AppIcon.icon"
if [[ -d "$ICON" ]]; then
  echo "==> Simge derleniyor: $ICON"
  xcrun actool "$ICON" \
    --compile "$BUNDLE/Contents/Resources" \
    --app-icon AppIcon \
    --output-partial-info-plist "build/appstore/icon-partial.plist" \
    --platform macosx \
    --minimum-deployment-target 26.0 > /dev/null
else
  echo "hata: $ICON yok." >&2
  exit 1
fi

# Provisioning profile: App Store dagitiminda zorunlu. Bundle'in icine
# embedded.provisionprofile adiyla girer; adi yanlis olursa magaza paketi
# kabul etmez.
PROFILE="${PROFILE:-}"
if [[ -n "$PROFILE" ]]; then
  echo "==> Provisioning profile gomuluyor: $PROFILE"
  cp "$PROFILE" "$BUNDLE/Contents/embedded.provisionprofile"
else
  echo "uyari: PROFILE verilmedi; paket App Store tarafindan reddedilecektir." >&2
  echo "       PROFILE=/yol/PlaceTimer.provisionprofile ile tekrar calistirin." >&2
fi

# Magaza imzasi iki entitlement daha istiyor: application-identifier ve
# team-identifier. Xcode bunlari imzalarken kendisi ekliyor; codesign elle
# cagrildiginda eklemiyor ve App Store Connect "signature ... is missing an
# application identifier" (90886) uyarisi verip build'i TestFlight'a
# kapatiyor.
#
# Degerler profilden okunuyor, betige gomulmuyor: takim ya da paket kimligi
# degistiginde profil zaten degisecek, imza da kendiliginden ona uyacak.
# Yerel derleme (build-app.sh) bu iki anahtari almiyor — orada imza baska bir
# takimin gelistirme sertifikasiyla atiliyor ve uyusmayan bir
# application-identifier uygulamanin hic acilmamasina yol acardi.
GENERATED_ENTITLEMENTS="build/appstore/PlaceTimer.generated.entitlements"
PROFILE_PLIST="build/appstore/profile.plist"

if [[ -n "$PROFILE" ]]; then
  security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
  APP_ID="$(/usr/libexec/PlistBuddy -c \
    "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST")"
  TEAM_ID="$(/usr/libexec/PlistBuddy -c \
    "Print :Entitlements:com.apple.developer.team-identifier" "$PROFILE_PLIST")"

  if [[ -z "$APP_ID" || -z "$TEAM_ID" ]]; then
    echo "hata: profilden kimlikler okunamadi." >&2
    exit 1
  fi

  echo "==> Imza kimlikleri profilden: $APP_ID"
  cp "$ENTITLEMENTS" "$GENERATED_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c \
    "Add :com.apple.application-identifier string $APP_ID" \
    "$GENERATED_ENTITLEMENTS" >/dev/null
  /usr/libexec/PlistBuddy -c \
    "Add :com.apple.developer.team-identifier string $TEAM_ID" \
    "$GENERATED_ENTITLEMENTS" >/dev/null
  SIGN_ENTITLEMENTS="$GENERATED_ENTITLEMENTS"
else
  SIGN_ENTITLEMENTS="$ENTITLEMENTS"
fi

# Genisletilmis oznitelikler temizleniyor. Provisioning profile tarayiciyla
# indirildigi icin uzerinde com.apple.quarantine tasiyor ve bundle'a oyle
# giriyordu; App Store Connect bunu reddediyor:
#   "The package contains one or more files with the com.apple.quarantine
#    extended file attribute ... embedded.provisionprofile" (91109)
# Imzadan once yapiliyor: sonra yapilsaydi muhurlenmis kaynaklar bozulurdu.
echo "==> Genisletilmis oznitelikler temizleniyor"
xattr -cr "$BUNDLE"

echo "==> Uygulama imzalaniyor: $APP_IDENTITY"
codesign --force --timestamp --options runtime \
  --entitlements "$SIGN_ENTITLEMENTS" \
  --sign "$APP_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

if ! codesign -d --entitlements - --xml "$BUNDLE" 2>/dev/null \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | grep -q "com.apple.security.app-sandbox"; then
  echo "hata: sandbox entitlement'i imzaya girmedi." >&2
  exit 1
fi

echo "==> Paket uretiliyor: $PKG"
rm -f "$PKG"
productbuild --component "$BUNDLE" /Applications \
  --sign "$PKG_IDENTITY" "$PKG"

echo
echo "==> Hazir: $PKG"
echo
echo "Yukleme: Transporter.app ile bu .pkg dosyasini gonder"
echo "(App Store Connect'te uygulama kaydi ve surum onceden olusturulmus olmali)."
