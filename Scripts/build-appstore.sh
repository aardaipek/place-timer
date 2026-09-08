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

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
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

if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
else
  echo "hata: Resources/AppIcon.icns yok; once Scripts/make-icon.sh calistirin." >&2
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

echo "==> Uygulama imzalaniyor: $APP_IDENTITY"
codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
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
