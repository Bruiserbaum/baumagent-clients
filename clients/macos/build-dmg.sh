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

# 1. Compile with Swift (native arch of the runner)
cd "$PKG_DIR"
swift build -c release 2>&1

BINARY=".build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
  echo "Error: binary not found at $BINARY" >&2
  exit 1
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

# 3. Code sign
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc

if [ "$SIGN_IDENTITY" = "-" ]; then
    # Ad-hoc: skip hardened runtime and timestamp (requires Apple-signed cert)
    codesign --force --deep \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
else
    codesign --force --deep \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$SCRIPT_DIR/build/BaumAgent.entitlements" \
        --options runtime \
        --timestamp \
        "$APP_BUNDLE"
fi

# Verify
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

# Build create-dmg args; --volicon is optional (only added if the icon exists)
ICON_PATH="$PKG_DIR/BaumAgent/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
DMG_ARGS=(
    --volname "$APP_NAME $VERSION"
    --window-pos 200 120
    --window-size 660 400
    --icon-size 100
    --icon "$APP_NAME.app" 170 190
    --hide-extension "$APP_NAME.app"
    --app-drop-link 490 190
    --no-internet-enable
)
if [ -f "$ICON_PATH" ]; then
    DMG_ARGS+=(--volicon "$ICON_PATH")
fi

create-dmg "${DMG_ARGS[@]}" "$DMG_OUT" "$SCRIPT_DIR/build/$APP_NAME.app" || {
    # Fallback: plain hdiutil DMG without background
    hdiutil create -volname "$APP_NAME $VERSION" \
        -srcfolder "$SCRIPT_DIR/build/$APP_NAME.app" \
        -ov -format UDZO "$DMG_OUT"
}

echo "✔ DMG: $DMG_OUT"
