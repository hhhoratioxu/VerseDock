#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
mkdir -p build/core build/VerseDock.app/Contents/MacOS build/VerseDock.app/Contents/Resources
"$compiler" -O -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 \
    -emit-library -static -emit-module -module-name VerseCore Sources/VerseCore/*.swift \
    -emit-module-path build/core/VerseCore.swiftmodule -o build/core/libVerseCore.a
"$compiler" -O -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 -parse-as-library \
    -I build/core -L build/core -lVerseCore App/Shared/*.swift App/macOS/*.swift \
    -o build/VerseDock.app/Contents/MacOS/VerseDockMac
cp Config/Mac-Info.plist build/VerseDock.app/Contents/Info.plist
cp App/Resources/AppIcon.icns App/Resources/BrandMark.png build/VerseDock.app/Contents/Resources/
/usr/bin/xattr -cr build/VerseDock.app
/usr/bin/codesign --force --sign - --options runtime --entitlements Config/Mac.entitlements build/VerseDock.app
print 'Built: '"$PWD/build/VerseDock.app"
