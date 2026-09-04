#!/bin/bash
# PlaceTimer.app paketini uretir ve imzalar.
#
# Xcode projesi yerine bu betik kullaniliyor: uygulama SwiftPM urunu olarak
# derleniyor, bundle elle kuruluyor ve gercek gelistirici sertifikasiyla
# imzalaniyor. Konum ve bildirim izinleri imzali bir bundle gerektirdigi icin
# imza adimi opsiyonel degil.
#
# Kullanim:  Scripts/build-app.sh [--install]
set -euo pipefail

cd "$(dirname "$0")/.."

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPER_DIR

CONFIGURATION="release"
APP_NAME="PlaceTimer"
BUNDLE="build/${APP_NAME}.app"

# Ilk kod imzalama kimligini kullan; --sign ile degistirilebilir.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | grep -m1 '"' | sed 's/.*"\(.*\)"/\1/')}"

if [[ -z "$IDENTITY" ]]; then
  echo "hata: kod imzalama kimligi bulunamadi." >&2
  echo "Xcode > Settings > Accounts uzerinden bir Apple hesabi ekleyin." >&2
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

echo "==> Imzalaniyor: $IDENTITY"
codesign --force --options runtime --timestamp=none \
  --sign "$IDENTITY" "$BUNDLE"
codesign --verify --strict "$BUNDLE"

echo "==> Hazir: $BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
  # Acilista baslatma (SMAppService) uygulamanin sabit bir konumda
  # bulunmasini gerektirir; bu yuzden /Applications'a kopyalaniyor.
  echo "==> /Applications'a kuruluyor"
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$BUNDLE" "/Applications/${APP_NAME}.app"
  echo "==> Kuruldu: /Applications/${APP_NAME}.app"
fi
