#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
core_sources=("${(@f)$(python3 scripts/source_manifest.py core)}")
shared_sources=("${(@f)$(python3 scripts/source_manifest.py shared)}")
mac_sources=("${(@f)$(python3 scripts/source_manifest.py macOS)}")
mkdir -p build/core "$HOME/Library/Developer/VerseDock/Builds"
mac_build_dir="$(mktemp -d "$HOME/Library/Developer/VerseDock/Builds/mac.XXXXXX")"
mac_app="$mac_build_dir/VerseDock.app"
mkdir -p "$mac_app/Contents/MacOS" "$mac_app/Contents/Resources"
"$compiler" -O -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 \
    -emit-library -static -emit-module -module-name VerseCore "${core_sources[@]}" \
    -emit-module-path build/core/VerseCore.swiftmodule -o build/core/libVerseCore.a
"$compiler" -O -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 -parse-as-library \
    -I build/core -L build/core -lVerseCore "${shared_sources[@]}" "${mac_sources[@]}" \
    -o "$mac_app/Contents/MacOS/VerseDockMac"
/bin/cp -X Config/Mac-Info.plist "$mac_app/Contents/Info.plist"
/bin/cp -X App/Resources/AppIcon.icns App/Resources/BrandMark.png "$mac_app/Contents/Resources/"
/usr/bin/codesign --force --sign - --options runtime --entitlements Config/Mac.entitlements "$mac_app"
/usr/bin/codesign --verify --deep --strict "$mac_app"
# Keep signed output outside cloud/File Provider folders that can reattach Finder metadata.
if [[ -L build/VerseDock.app ]]; then
    /bin/rm build/VerseDock.app
elif [[ -e build/VerseDock.app ]]; then
    /bin/mv build/VerseDock.app "$mac_build_dir/previous-output.app"
fi
/bin/ln -s "$mac_app" build/VerseDock.app
print 'Built: '"$PWD/build/VerseDock.app"
