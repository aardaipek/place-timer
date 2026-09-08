#!/bin/bash
# PlaceTimer.app paketini uretir ve imzalar.
#
# Xcode projesi yerine bu betik kullaniliyor: uygulama SwiftPM urunu olarak
# derleniyor, bundle elle kuruluyor ve gercek gelistirici sertifikasiyla
# imzalaniyor. Konum ve bildirim izinleri imzali bir bundle gerektirdigi icin
# imza adimi opsiyonel degil.
#
# Kullanim:
#   Scripts/build-app.sh            paketi build/ altinda uretir
#   Scripts/build-app.sh --install  /Applications'a kurar ve calistirir
#   Scripts/build-app.sh --fresh    once tum uygulama verisini siler, sonra kurar
set -euo pipefail

cd "$(dirname "$0")/.."

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPER_DIR

CONFIGURATION="release"
APP_NAME="PlaceTimer"
BUNDLE="build/${APP_NAME}.app"

# Imza kimligi SABIT olmalidir.
#
# macOS, verilen izinleri paket kimligi + imza ciftine bagliyor. Makinede
# birden fazla sertifika varsa ve her derlemede rastgele biri secilirse, ayni
# uygulama farkli takimlarla imzalanir; macOS bunu bambaska bir uygulama sayar
# ve konum/bildirim izinleri sessizce sifirlanir. Bu yuzden kimlik
# .codesign-identity dosyasinda tutulur.
IDENTITY_FILE=".codesign-identity"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  IDENTITY="$CODESIGN_IDENTITY"
elif [[ -f "$IDENTITY_FILE" ]]; then
  IDENTITY="$(tr -d '\n' < "$IDENTITY_FILE")"
else
  IDENTITY="$(security find-identity -v -p codesigning \
    | grep -m1 '"' | sed 's/.*"\(.*\)"/\1/')"
  if [[ -n "$IDENTITY" ]]; then
    echo "$IDENTITY" > "$IDENTITY_FILE"
    echo "==> Imza kimligi sabitlendi: $IDENTITY"
    echo "    ($IDENTITY_FILE dosyasindan degistirebilirsiniz)"
  fi
fi

if [[ -z "$IDENTITY" ]]; then
  echo "hata: kod imzalama kimligi bulunamadi." >&2
  echo "Xcode > Settings > Accounts uzerinden bir Apple hesabi ekleyin." >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
  echo "hata: sabitlenmis imza kimligi bu makinede yok:" >&2
  echo "  $IDENTITY" >&2
  echo "Mevcut kimlikler:" >&2
  security find-identity -v -p codesigning | grep '"' >&2
  exit 1
fi

# Kurulu surum baska bir kimlikle imzalandiysa izinler sifirlanacak demektir.
INSTALLED="/Applications/PlaceTimer.app"
if [[ -d "$INSTALLED" ]]; then
  PREVIOUS="$(codesign -dvvv "$INSTALLED" 2>&1 \
    | sed -n 's/^Authority=\(Apple Development.*\)$/\1/p' | head -1)"
  if [[ -n "$PREVIOUS" && "$PREVIOUS" != "$IDENTITY" ]]; then
    echo "UYARI: kurulu surum farkli bir kimlikle imzalanmis." >&2
    echo "  onceki: $PREVIOUS" >&2
    echo "  simdi : $IDENTITY" >&2
    echo "  Konum ve bildirim izinleri yeniden istenecek." >&2
  fi
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
  echo "uyari: Resources/AppIcon.icns yok; once Scripts/make-icon.sh calistirin." >&2
fi

# Sandbox entitlement'lari yerel derlemeye de uygulaniyor. App Store sandbox'i
# zorunlu kiliyor; yerelde sandbox'siz calisip magazaya sandbox'li gondermek,
# kirilan seyi ilk kez inceleme kuyrugunda gormek demek olurdu.
ENTITLEMENTS="Resources/PlaceTimer.entitlements"

echo "==> Imzalaniyor: $IDENTITY"
codesign --force --options runtime --timestamp=none \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" "$BUNDLE"
codesign --verify --strict "$BUNDLE"

# Sandbox gercekten acildi mi? Entitlement dosyasi yanlis yolda olsaydi
# codesign sessizce imzalar, uygulama da sandbox'siz calisirdi.
if ! codesign -d --entitlements - --xml "$BUNDLE" 2>/dev/null \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | grep -q "com.apple.security.app-sandbox"; then
  echo "hata: sandbox entitlement'i imzaya girmedi." >&2
  exit 1
fi

echo "==> Hazir: $BUNDLE"

MODE="${1:-}"

if [[ "$MODE" == "--fresh" ]]; then
  DATA_DIR="$HOME/Library/Application Support/PlaceTimer"
  if [[ -d "$DATA_DIR" ]]; then
    BACKUP="${DATA_DIR}.$(date +%Y%m%d-%H%M%S).bak"
    echo "==> Mevcut veri yedekleniyor: $BACKUP"
    mv "$DATA_DIR" "$BACKUP"
  fi
fi

if [[ "$MODE" == "--install" || "$MODE" == "--fresh" ]]; then
  # Acilista baslatma (SMAppService) uygulamanin sabit bir konumda
  # bulunmasini gerektirir; bu yuzden /Applications'a kopyalaniyor.
  echo "==> /Applications'a kuruluyor"
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$BUNDLE" "/Applications/${APP_NAME}.app"
  echo "==> Kuruldu: /Applications/${APP_NAME}.app"
fi
