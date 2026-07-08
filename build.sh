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

echo "Assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp launcher "$APP/Contents/MacOS/DistanceCalculator"
cp distancecalc "$APP/Contents/MacOS/distancecalc"

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
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

echo "Done. Launch with: open ${APP}"
