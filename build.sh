#!/bin/bash
set -eu
cd "$(dirname "$0")"
swift build -c release
bundle="消息板.app/Contents"
mkdir -p "$bundle/MacOS" "$bundle/Resources"
cp Assets/AppIcon.icns Assets/PrivacyInfo.xcprivacy "$bundle/Resources/"
cp "$(swift build -c release --show-bin-path)/MessageBoard" "$bundle/MacOS/"
cat > "$bundle/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleName</key><string>消息板</string>
<key>CFBundleIdentifier</key><string>com.xschao.MessageBoard</string>
<key>CFBundleExecutable</key><string>MessageBoard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleVersion</key><string>16</string>
<key>CFBundleShortVersionString</key><string>1.15</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "消息板.app"
codesign --verify --strict "消息板.app"
