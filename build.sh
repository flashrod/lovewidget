#!/bin/bash
set -euo pipefail

SWIFT=${SWIFT:-swift}
PRODUCT_NAME="LoveWidget"
APP_BUNDLE="${PRODUCT_NAME}.app"
CONFIG_FILE="Config.xcconfig"

echo "==> Reading Supabase configuration..."

SUPABASE_URL=$(grep '^SUPABASE_URL' "$CONFIG_FILE" | sed 's/^SUPABASE_URL *= *//; s/^[[:space:]]*//; s/[[:space:]]*$//')
SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY' "$CONFIG_FILE" | sed 's/^SUPABASE_ANON_KEY *= *//; s/^[[:space:]]*//; s/[[:space:]]*$//')

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "ERROR: Missing SUPABASE_URL or SUPABASE_ANON_KEY in $CONFIG_FILE"
    echo "Copy Config.xcconfig.template -> Config.xcconfig and fill in your values."
    exit 1
fi

echo "  URL:  $SUPABASE_URL"
echo "  Key:  ${SUPABASE_ANON_KEY:0:20}..."

echo ""
echo "==> Building with SwiftPM..."
$SWIFT build -c release

EXECUTABLE_PATH=$($SWIFT build -c release --show-bin-path)/$PRODUCT_NAME
echo "  Executable: $EXECUTABLE_PATH"

echo ""
echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo ""
echo "==> Generating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$PRODUCT_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>com.lovewidget.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>LoveWidget</string>
	<key>CFBundleDisplayName</key>
	<string>LoveWidget</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
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

echo ""
echo "==> Copying executable..."
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"

echo ""
echo "==> Signing with ad-hoc certificate + sandbox entitlements..."
codesign --force --sign - --entitlements LoveWidget.entitlements --options runtime "$APP_BUNDLE" 2>&1

echo ""
echo "============================================"
echo "  Build complete!"
echo "============================================"
echo ""
echo "  Run: open $APP_BUNDLE"
echo ""
echo "  (The app runs in the menu bar."
echo "   Click the heart icon -> Show LoveWidget)"
echo ""
