#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./build.sh
root=.build/sandbox-preview
app="$root/Mac-imbox Sandbox.app"
mkdir -p "$root"
ditto 消息板.app "$app"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.xschao.MessageBoard.SandboxPreview' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Mac-imbox Sandbox' "$plist"
cat > "$root/entitlements.plist" <<'PLIST'
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --entitlements "$root/entitlements.plist" "$app"
codesign --verify --strict "$app"
echo "$PWD/$app"
