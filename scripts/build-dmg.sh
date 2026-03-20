#!/bin/bash
set -euo pipefail

# Build Whispr release binary and package it into a DMG.
# Usage: ./scripts/build-dmg.sh

APP_NAME="Whispr"
BUNDLE_ID="com.whispr.app"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release-app"
DMG_DIR=".build/dmg-staging"
OUTPUT_DMG=".build/${APP_NAME}-${VERSION}.dmg"

echo "🔨 Building ${APP_NAME} (release)..."
swift build -c release 2>&1

BINARY_PATH=".build/release/${APP_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Binary not found at ${BINARY_PATH}"
    exit 1
fi

echo "📦 Creating app bundle..."
rm -rf "$BUILD_DIR"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BINARY_PATH" "$MACOS/${APP_NAME}"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Whispr needs microphone access to record your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Whispr uses accessibility features to type transcribed text into apps.</string>
</dict>
</plist>
EOF

# Copy icon if it exists
ICON_PATH="Resources/AppIcon.icns"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$RESOURCES/AppIcon.icns"
fi

echo "💿 Creating DMG..."
rm -rf "$DMG_DIR" "$OUTPUT_DMG"
mkdir -p "$DMG_DIR"

# Copy app bundle to staging
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create a placeholder background README
cat > "$DMG_DIR/.background-README.txt" << 'EOF'
To add a background image to the DMG:
1. Place a 600x400 PNG at Resources/dmg-background.png
2. This script will pick it up automatically in a future version.
EOF

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg..."
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "$RESOURCES/AppIcon.icns" 2>/dev/null || true \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 80 \
        --icon "${APP_NAME}.app" 175 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 190 \
        --no-internet-enable \
        "$OUTPUT_DMG" \
        "$DMG_DIR" || {
            echo "create-dmg had issues, falling back to hdiutil..."
            hdiutil create -volname "${APP_NAME}" -srcfolder "$DMG_DIR" -ov -format UDZO "$OUTPUT_DMG"
        }
else
    echo "Using hdiutil (install create-dmg for prettier DMGs: brew install create-dmg)..."
    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "$DMG_DIR" \
        -ov \
        -format UDZO \
        "$OUTPUT_DMG"
fi

# Clean up staging
rm -rf "$DMG_DIR"

DMG_SIZE=$(du -h "$OUTPUT_DMG" | cut -f1)
echo ""
echo "✅ DMG created: ${OUTPUT_DMG} (${DMG_SIZE})"
echo "   Version: ${VERSION}"
echo ""
echo "To install: open the DMG and drag Whispr to Applications."
