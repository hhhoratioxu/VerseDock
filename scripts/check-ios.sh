#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
mkdir -p build/ios-core
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 \
    -emit-module -module-name VerseCore Sources/VerseCore/*.swift \
    -emit-module-path build/ios-core/VerseCore.swiftmodule
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 -parse-as-library -typecheck \
    -I build/ios-core App/Shared/*.swift App/iOS/*.swift App/LiveActivity/LyricsActivityAttributes.swift
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 -parse-as-library -typecheck App/LiveActivity/*.swift
print 'iOS app and Live Activity extension: typecheck passed (not a signed build).'
