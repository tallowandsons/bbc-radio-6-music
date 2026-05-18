#!/bin/bash
set -euo pipefail

APP_NAME="BBC Radio 6 Music"
BUNDLE_ID="mijewe.bbc-radio-6-music"
SDK=$(xcrun --show-sdk-path)
APP_BUNDLE="${APP_NAME}.app"
EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

SOURCES=(
    "BBC Radio 6/main.swift"
    "BBC Radio 6/AppDelegate.swift"
    "BBC Radio 6/StatusBarController.swift"
    "BBC Radio 6/PlayerController.swift"
    "BBC Radio 6/NowPlayingService.swift"
    "BBC Radio 6/LastFMService.swift"
    "BBC Radio 6/PreferencesWindowController.swift"
    "BBC Radio 6/PreferencesView.swift"
    "BBC Radio 6/KeychainHelper.swift"
)

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

ARCH=$(uname -m)
echo "Compiling Swift (${ARCH})..."
swiftc "${SOURCES[@]}" \
    -sdk "$SDK" \
    -target "${ARCH}-apple-macosx13.0" \
    -swift-version 5 \
    -framework AVFoundation \
    -framework MediaPlayer \
    -framework Security \
    -o "$EXECUTABLE"

echo "Processing Info.plist..."
sed \
    -e 's/$(EXECUTABLE_NAME)/'"${APP_NAME}"'/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/'"${BUNDLE_ID}"'/g' \
    -e 's/$(PRODUCT_NAME)/'"${APP_NAME}"'/g' \
    -e 's/$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/13.0/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    "BBC Radio 6/Info.plist" > "${APP_BUNDLE}/Contents/Info.plist"

echo "Copying resources..."
cp "BBC Radio 6/radio6.svg" "${APP_BUNDLE}/Contents/Resources/radio6.svg"
cp "BBC Radio 6/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Run:   open '${APP_BUNDLE}'"
