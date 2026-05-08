#!/usr/bin/env bash
# build-dmg.sh — build the BaumAgent.app bundle and package it in a DMG
# Usage: VERSION=1.0.0 ./build-dmg.sh
# Requires: swift, create-dmg (brew install create-dmg), Xcode CLI tools

set -euo pipefail

VERSION="${VERSION:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/BaumAgent"
APP_NAME="BaumAgent"
APP_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
DMG_OUT="$SCRIPT_DIR/build/${APP_NAME}-${VERSION}.dmg"

echo "▶ Building $APP_NAME v$VERSION"

# 1. Compile with Swift
cd "$PKG_DIR"
swift build -c release --arch arm64 --arch x86_64 2>&1

BINARY=".build/apple/Products/Release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
  # Single-arch fallback
  BINARY=".build/release/$APP_NAME"
  swift build -c release
fi

# 2. Assemble .app bundle
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Patch CFBundleShortVersionString in Info.plist
sed "s|1\.0\.0|$VERSION|g" "$PKG_DIR/BaumAgent/Info.plist" \
    > "$APP_BUNDLE/Contents/Info.plist"

# Copy entitlements alongside (for codesign step below)
cp "$PKG_DIR/BaumAgent.entitlements" "$SCRIPT_DIR/build/"

# 3. Code sign (ad-hoc if no identity supplied; CI overrides SIGN_IDENTITY)
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc
codesign --force --deep \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$SCRIPT_DIR/build/BaumAgent.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"

# Verify (skip spctl check for ad-hoc since it won't pass Gatekeeper)
codesign --verify --deep --strict "$APP_BUNDLE"
if [ "$SIGN_IDENTITY" != "-" ]; then
    spctl --assess --type exec --verbose "$APP_BUNDLE" \
        && echo "✔ Gatekeeper check passed" \
        || echo "::warning::Gatekeeper check failed — the app may need notarisation"
fi

echo "✔ Signed: $APP_BUNDLE"

# 4. Create DMG
mkdir -p "$SCRIPT_DIR/build"
rm -f "$DMG_OUT"

create-dmg \
    --volname "$APP_NAME $VERSION" \
    --volicon "$PKG_DIR/BaumAgent/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" 2>/dev/null || true \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 170 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 490 190 \
    --no-internet-enable \
    "$DMG_OUT" \
    "$SCRIPT_DIR/build/$APP_NAME.app" || {
        # Fallback: plain hdiutil DMG without background
        hdiutil create -volname "$APP_NAME $VERSION" \
            -srcfolder "$SCRIPT_DIR/build/$APP_NAME.app" \
            -ov -format UDZO "$DMG_OUT"
    }

echo "✔ DMG: $DMG_OUT"
