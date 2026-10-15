#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build
print 'Building the iOS device app and Live Activity extension without signing...'
if ! /usr/bin/xcodebuild -project VerseDock.xcodeproj -scheme VerseDock \
    -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath build/ios-derived \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
    build > build/ios-build.log 2>&1; then
    tail -n 35 build/ios-build.log
    exit 1
fi
if [[ -x /Library/Developer/CommandLineTools/usr/bin/python3 ]]; then
    ios_packager_python=/Library/Developer/CommandLineTools/usr/bin/python3
else
    ios_packager_python=python3
fi
"$ios_packager_python" scripts/package-ios.py
print 'Unsigned device IPA created. It needs your Apple signing identity and provisioning before installation.'
