#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="Tiler"
APP_BUNDLE="${APP_NAME}.app"
BINARY_NAME="Tiler"
INSTALL_PATH="/Applications/${APP_BUNDLE}"
DMG_NAME="${APP_NAME}.dmg"

echo "==> Building ${APP_NAME}..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
cp "Resources/Info.plist"          "${APP_BUNDLE}/Contents/Info.plist"
if [ ! -f "Resources/AppIcon.icns" ]; then
  echo "ERROR: Resources/AppIcon.icns not found"
  exit 1
fi
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "==> Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Installing to ${INSTALL_PATH}..."
rm -rf "${INSTALL_PATH}"
cp -r "${APP_BUNDLE}" "${INSTALL_PATH}"

echo "==> Creating DMG..."
rm -f "${DMG_NAME}"

create-dmg \
  --volname "${APP_NAME}" \
  --background "Resources/dmg-background.jpg" \
  --window-size 600 400 \
  --icon-size 96 \
  --icon "${APP_BUNDLE}" 170 190 \
  --app-drop-link 430 190 \
  --hide-extension "${APP_BUNDLE}" \
  --no-internet-enable \
  "${DMG_NAME}" \
  "${APP_BUNDLE}"

echo ""
echo "Done! Installed to ${INSTALL_PATH}"
echo ""
echo "NOTE: Grant Accessibility in:"
echo "      System Settings → Privacy & Security → Accessibility → enable Tiler."
