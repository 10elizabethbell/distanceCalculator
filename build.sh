#!/bin/bash
# Builds DistanceCalculator.app: compiles the Swift menu bar app and the C
# launcher, then assembles the bundle with the launcher as its executable.
set -euo pipefail
cd "$(dirname "$0")"

APP="DistanceCalculator.app"

echo "Compiling Swift app..."
swiftc -O -o distancecalc DistanceCalculator.swift \
    -framework AppKit -framework MapKit -framework CoreLocation

echo "Compiling C launcher..."
clang -O2 -Wall -o launcher launcher.c

# Regenerate the app icon when the generator script has changed.
if [[ ! -f AppIcon.icns || makeicon.swift -nt AppIcon.icns ]]; then
    echo "Generating AppIcon.icns..."
    swift makeicon.swift icon_1024.png
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z "$s" "$s" icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z "$((s*2))" "$((s*2))" icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o AppIcon.icns
    rm -rf "$(dirname "$ICONSET")" icon_1024.png
fi

echo "Assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp launcher "$APP/Contents/MacOS/DistanceCalculator"
cp distancecalc "$APP/Contents/MacOS/distancecalc"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DistanceCalculator</string>
    <key>CFBundleDisplayName</key>
    <string>Distance Calculator</string>
    <key>CFBundleIdentifier</key>
    <string>com.ellie.distancecalculator</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>DistanceCalculator</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

echo "Done. Launch with: open ${APP}"
