# Unsigned iPhone/iPad IPA

[简体中文](IPA.zh-CN.md) · **English**

Latest GitHub release: [v1.0.0](https://github.com/hhhoratioxu/VerseDock/releases/tag/v1.0.0). It includes lyric seeking, an optional Spotify web-lyrics session and bilingual display. Device builds passed and Mac originals have real-account results; the iOS web session, playback controls and physical-device features still await signing and acceptance.

`VerseDock-iOS-unsigned.ipa` is a fully compiled iOS device app from this project. It contains the actual arm64 main executable and `VerseDockActivity.appex` for Dynamic Island/Lock Screen Live Activities. It supports iPhone and iPad with minimum iOS/iPadOS 17. It is a device build, not a simulator executable or renamed source archive.

The IPA has no Apple signature, personal certificate or provisioning profile. Sign it with your own Apple signing identity and profiles before installing it on an authorized device. A local ad hoc signature cannot replace the Apple signature and profiles required by iOS.

## Download and verify

Download these release assets:

- `VerseDock-iOS-unsigned.ipa`: the unsigned package.
- `VerseDock-iOS-unsigned.sha256`: its SHA-256 checksum.
- `VerseDock-iOS-BuildInfo.json`: source commit, build-tool versions, architecture/hash information for both executables, and signing status.

Place the IPA and `.sha256` in one directory and run `shasum -a 256 -c VerseDock-iOS-unsigned.sha256`. Signing changes the IPA, so the signed file will no longer match the original checksum.

## Keep the extension when signing

1. Import the unsigned IPA into your signing tool and use your own Apple account or certificate and profiles. Private keys, Apple passwords and provisioning profiles do not need to be uploaded to GitHub.
2. Retain `PlugIns/VerseDockActivity.appex`. If a tool removes all extensions, the main app may launch but this Dynamic Island/Lock Screen Live Activity will be absent.
3. Use the same Team for app and extension. The extension's bundle ID must preserve the main app ID as its prefix. If you change the app ID, update the extension ID and provide matching signatures for both bundles.
4. After signing and installation, first run the app's clearly marked original demo to check its presentation. Then follow [SETUP.en.md](SETUP.en.md) to configure a Spotify Client ID and your own HTTPS redirect.
5. Dynamic Island requires an iPhone with the corresponding hardware; iPad uses Lock Screen Live Activities.

Lyric seeking requires official Spotify playback-control authorization and Premium. Existing connections need renewed authorization for `user-modify-playback-state`. The optional original-lyrics session requires a separate login on Spotify's official webpage in Settings. It uses a non-public interface, so availability for every account/region cannot be promised. Playback OAuth and the lyric session are separate. Do not provide passwords, cookies or tokens in chat or GitHub.

Personal accounts and signing tools may not retain every capability. Foreground lyrics and local Live Activities do not depend on background APNs. The remote relay does require Push Notifications capability, correct `aps-environment`, server-side APNs keys and the same main app bundle ID. Included implementation does not guarantee background pushes after personal signing.

## Reproducible build

With full Xcode, the iPhoneOS SDK and the required license setup ready, run from the project root:

~~~sh
zsh scripts/build-ios-unsigned.sh
~~~

The script uses standard `xcodebuild` for a Release device build with signing explicitly disabled, then validates and packages through `package-ios.py`. Checks include iPhoneOS platform, arm64 Mach-O, minimum OS, executable permissions, app/extension ID and version relationships, WidgetKit declarations, Live Activity flags, the OAuth URL scheme, ZIP integrity and exclusion of signing material.

Raw build logs remain locally in `build/ios-build.log`; logs containing personal paths are not uploaded. The initial device-build summary is in `Evidence/ios-device-build.json`; 1.0 release checks are in `Evidence/release-1.0.0.json`. Packaging success is separate from physical-device acceptance. No signing certificate was available and no installation on iPhone/iPad was performed. Installation, authorization, actual Dynamic Island layout and background APNs delivery still require signed-device validation.

## Official Apple signing references

- [Create a development provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile)
- [Distribute to registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
