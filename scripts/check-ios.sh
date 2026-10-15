#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
core_sources=("${(@f)$(python3 scripts/source_manifest.py core)}")
shared_sources=("${(@f)$(python3 scripts/source_manifest.py shared)}")
ios_sources=("${(@f)$(python3 scripts/source_manifest.py iOS)}")
widget_sources=("${(@f)$(python3 scripts/source_manifest.py liveActivity)}")
mkdir -p build/ios-core
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 \
    -emit-module -module-name VerseCore "${core_sources[@]}" \
    -emit-module-path build/ios-core/VerseCore.swiftmodule
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 -parse-as-library -typecheck \
    -I build/ios-core "${shared_sources[@]}" "${ios_sources[@]}" App/LiveActivity/LyricsActivityAttributes.swift
"$compiler" -swift-version 5 -sdk "$sdk" -target arm64-apple-ios17.0 -parse-as-library -typecheck "${widget_sources[@]}"
print 'iOS app and Live Activity extension: typecheck passed (not a signed build).'
