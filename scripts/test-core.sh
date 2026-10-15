#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
dev=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer
mkdir -p build/test-core build/VerseCoreTests.xctest/Contents/MacOS
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 -enable-testing \
    -emit-library -static -emit-module -module-name VerseCore Sources/VerseCore/*.swift \
    -emit-module-path build/test-core/VerseCore.swiftmodule -o build/test-core/libVerseCore.a
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-macosx14.0 -emit-library \
    -I build/test-core -L build/test-core -lVerseCore \
    -I "$dev/usr/lib" -L "$dev/usr/lib" -F "$dev/Library/Frameworks" \
    -Xlinker -rpath -Xlinker "$dev/Library/Frameworks" -Xlinker -rpath -Xlinker "$dev/usr/lib" \
    Tests/VerseCoreTests/*.swift -o build/VerseCoreTests.xctest/Contents/MacOS/VerseCoreTests
cp Config/Tests-Info.plist build/VerseCoreTests.xctest/Contents/Info.plist
/Applications/Xcode.app/Contents/Developer/usr/bin/xctest build/VerseCoreTests.xctest
