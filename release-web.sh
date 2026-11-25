#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${DEVELOPER_ID_APPLICATION:?Set the full Developer ID Application identity from Keychain}"
: "${NOTARY_PROFILE:?Set the notarytool Keychain profile name}"
case "$DEVELOPER_ID_APPLICATION" in
  "Developer ID Application: "*) ;;
  *) echo "A Developer ID Application certificate is required." >&2; exit 1 ;;
esac
security find-identity -v -p codesigning | grep -Fq "\"$DEVELOPER_ID_APPLICATION\"" || { echo "Signing identity unavailable" >&2; exit 1; }
./build.sh
swift build -c release --arch arm64 --arch x86_64
bin=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
mkdir -p releases
stage=$(mktemp -d .build/web-release.XXXXXX)
mkdir "$stage/volume"
app="$stage/volume/消息板.app"
ditto 消息板.app "$app"
cp "$bin/MessageBoard" "$app/Contents/MacOS/MessageBoard"
for arch in arm64 x86_64; do
    xcrun lipo -archs "$app/Contents/MacOS/MessageBoard" | tr ' ' '\n' | grep -Fx "$arch" >/dev/null
done
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app"
codesign --verify --strict "$app"
ln -s /Applications "$stage/volume/Applications"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
dmg="$stage/MessageBoard-$version-universal.dmg"
hdiutil create -quiet -format UDZO -volname "消息板 $version" -srcfolder "$stage/volume" "$dmg"
codesign --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist > "$stage/notary.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :status' "$stage/notary.plist")" = Accepted
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature "$dmg"
hdiutil verify "$dmg"
mv "$dmg" releases/
