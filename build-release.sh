#!/bin/bash
set -euo pipefail

APP_NAME="LoveWidget"
BUNDLE_ID="com.lovewidget.app"
VERSION="${1:-${VERSION:-1.0.0}}"
CONFIG_FILE="Config.xcconfig"
ENTITLEMENTS="LoveWidget.entitlements"
ICON_FILE="App/Resources/AppIcon.icns"

ARCH=$(uname -m)
BUILD_DIR=".build/${ARCH}-apple-macosx/release"
RELEASE_DIR=".release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$RELEASE_DIR/staging"

echo "==> Reading Supabase configuration..."
SUPABASE_URL=$(grep '^SUPABASE_URL' "$CONFIG_FILE" | sed 's/^SUPABASE_URL *= *//; s/^[[:space:]]*//; s/[[:space:]]*$//')
SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY' "$CONFIG_FILE" | sed 's/^SUPABASE_ANON_KEY *= *//; s/^[[:space:]]*//; s/[[:space:]]*$//')

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "ERROR: Missing SUPABASE_URL or SUPABASE_ANON_KEY in $CONFIG_FILE"
    exit 1
fi

echo "==> Building binary (release)..."
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "$RELEASE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>LoveWidget</string>
	<key>CFBundleDisplayName</key>
	<string>LoveWidget</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSSupportsAutomaticTermination</key>
	<false/>
	<key>SUPABASE_URL</key>
	<string>$SUPABASE_URL</string>
	<key>SUPABASE_ANON_KEY</key>
	<string>$SUPABASE_ANON_KEY</string>
</dict>
</plist>
EOF

BIN_PATH="$BUILD_DIR/$APP_NAME"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "$ICON_FILE" ]; then
	echo "==> Copying app icon..."
	cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
	echo "==> App icon not found at $ICON_FILE (skipping)"
fi

echo "==> Signing (ad-hoc)..."
codesign --force --sign - --entitlements "$ENTITLEMENTS" --options runtime "$APP_BUNDLE"

echo "==> Creating DMG..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "LoveWidget $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo ""
echo "============================================"
echo "  Done: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"
echo "============================================"
echo ""
echo "  Upload DMG to GitHub release, then your partner can install:"
echo ""
echo "  brew tap YOUR_USERNAME/tap"
echo "  brew install --cask lovewidget"
echo ""
echo "  First launch: right-click LoveWidget.app > Open"
