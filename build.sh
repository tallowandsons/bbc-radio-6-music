#!/bin/bash
set -euo pipefail

APP_NAME="BBC Radio 6 Music"
BUNDLE_ID="tallowandsons.bbc-radio-6-music"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null)
VERSION=${VERSION:-1.0}
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

if [ "${UNIVERSAL:-0}" = "1" ]; then
    echo "Compiling Swift (universal)..."
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target "arm64-apple-macosx13.0" \
        -swift-version 5 \
        -framework AVFoundation \
        -framework MediaPlayer \
        -framework Security \
        -o "${EXECUTABLE}-arm64"
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target "x86_64-apple-macosx13.0" \
        -swift-version 5 \
        -framework AVFoundation \
        -framework MediaPlayer \
        -framework Security \
        -o "${EXECUTABLE}-x86_64"
    lipo -create "${EXECUTABLE}-arm64" "${EXECUTABLE}-x86_64" -output "$EXECUTABLE"
    rm "${EXECUTABLE}-arm64" "${EXECUTABLE}-x86_64"
else
    echo "Compiling Swift (${ARCH})..."
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target "${ARCH}-apple-macosx13.0" \
        -swift-version 5 \
        -framework AVFoundation \
        -framework MediaPlayer \
        -framework Security \
        -o "$EXECUTABLE"
fi

echo "Processing Info.plist..."
sed \
    -e 's/$(EXECUTABLE_NAME)/'"${APP_NAME}"'/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/'"${BUNDLE_ID}"'/g' \
    -e 's/$(PRODUCT_NAME)/'"${APP_NAME}"'/g' \
    -e 's/$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/13.0/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    -e 's/$(MARKETING_VERSION)/'"${VERSION}"'/g' \
    "BBC Radio 6/Info.plist" > "${APP_BUNDLE}/Contents/Info.plist"

echo "Copying resources..."
cp "BBC Radio 6/radio6.svg" "${APP_BUNDLE}/Contents/Resources/radio6.svg"
cp "BBC Radio 6/lastfm.svg" "${APP_BUNDLE}/Contents/Resources/lastfm.svg"
cp "BBC Radio 6/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Run:   open '${APP_BUNDLE}'"
