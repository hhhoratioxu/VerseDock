# VerseDock

[简体中文](README.md) · **English**

<img src="Artwork/VerseDock-Icon-1024.png" alt="VerseDock icon" width="128">

An original native Swift Spotify lyrics companion. macOS offers menu bar lyrics, a draggable lyrics overlay and a full lyrics window. iPhone offers full lyrics, Dynamic Island and Lock Screen Live Activities. iPad offers full lyrics and Lock Screen Live Activities; iPad has no Dynamic Island hardware.

VerseDock is a standalone companion. It reads Spotify playback through local automation or official playback APIs and offers an optional Spotify web-lyrics session. It does not modify the Spotify installation, inject code into its process or depend on an existing lyrics plugin.

## Run the Mac app

Repository: [hhhoratioxu/VerseDock](https://github.com/hhhoratioxu/VerseDock). Download the packaged Mac app from [Releases](https://github.com/hhhoratioxu/VerseDock/releases). Source, the Xcode project and setup instructions are also in this repository.

The current stable release is [v1.0.0](https://github.com/hhhoratioxu/VerseDock/releases/tag/v1.0.0), with a Mac app, DMG installer, unsigned iPhone/iPad IPA and complete source. Mac uses native Apple toolbars, a separate Settings window and a single main lyrics window. Flowing artwork colors, adjustable glass, Spotify-original priority, fallback providers, translation, lyric seeking, Dock and menu bar entries remain available. The iOS package still needs your own signing; device/APNs status is documented in the verification record. See [original icon assets](Artwork/README.en.md).

Version 1.0.0 (100) unifies platform versions and adds Compact/Wide window commands. Explicit source lists define builds, and packaging iOS from a downloaded source archive no longer requires Git metadata. Forty-two core tests, six offline web-bridge tests and nine relay tests passed. The installed Mac app retrieved actual Spotify / Musixmatch originals; iOS app and Live Activity extension device builds passed. The DMG was mounted read-only and its executable/signature verified. See the [verification record](docs/VERIFICATION.en.md) for runtime coverage and limits.

Download `VerseDock-macOS-arm64.dmg` and drag `VerseDock` to `Applications`. Alternatively, extract the ZIP and move `VerseDock.app` to Applications. It has a Dock icon; the Dock entry can reopen the main window, and closing that window leaves menu bar lyrics running. A local build is available at `build/VerseDock.app`:

~~~sh
open build/VerseDock.app
~~~

Open the Spotify desktop app and play a song. New installations search for online lyrics automatically. An existing preference that explicitly disabled networking is preserved. You can also import a UTF-8 `.lrc` file for the current song. Allow the macOS Automation request for Spotify. Click Floating Lyrics (悬浮歌词), then drag the lyrics or an empty part of the window to move it; the position saves automatically. The actual menu bar displays lyrics directly, with a default static width of 18 characters. Width and scrolling are independent, automatically saved choices. Menu bar and floating lyrics remain usable after the main window closes.

Local Mac reading does not require a Spotify Client ID. The package is arm64, requires macOS 14 or later, and uses a local ad hoc signature. Other Macs, Intel, Developer ID signing and notarization have not been accepted.

## Implemented features

| Feature | macOS | iPhone / iPad |
|---|---|---|
| Current Spotify track, progress, pause and track changes | Local AppleScript | Official Web API + PKCE |
| Synchronized LRC, full lyrics and automatic following | Yes | Yes |
| Bilingual lines at one timestamp; repeated timestamps | Yes | Yes |
| Per-song adjustment, ±10 seconds | Yes | Yes |
| Click a synchronized line to seek to its singing time | Real Spotify control and position read-back verified | Official seek API implemented; configuration, authorization and device acceptance pending |
| Local file import and cache clearing | Yes | Yes |
| Online lyrics | Optional Spotify web session first; default fallback LRCLIB → QQ → NetEase → lyrics.ovh | Same code path; web session awaits physical-device validation |
| Current lyric in the menu bar | Static by default; adjustable width and optional looping scroll | Not applicable |
| Optional translation | Original above translation; macOS 15+ | iOS/iPadOS 18+; optional translations in Live Activities |
| Draggable overlay across desktops | Drag lyrics or empty space; position saved | Not applicable |
| Dynamic Island / Lock Screen Live Activities | Sends data to the relay | ActivityKit + WidgetKit |
| Background-update relay | Mac supplies the data | Registers APNs Live Activity tokens |

Lyrics follow the current Spotify song. Fallback providers do not need Spotify accounts or cookies. When LRCLIB has no match, times out, returns an error or only has plain text, the app continues with QQ Music, NetEase Cloud Music and finally lyrics.ovh plain text. A manually selected fallback accesses only that provider; Spotify is still checked first when original-lyrics priority is on. Retry bypasses the cache. Settings show each attempted provider's result. Rate limits respect Retry-After rather than immediately retrying the same provider after a track change.

Matching normalizes simplified/traditional Chinese, punctuation and multiple-artist separators, and removes trailing film/TV descriptions. English/Chinese artist aliases are confirmed from QQ artist profiles or aliases returned by NetEase. Matching favors the same album and close duration, preserves Live, Remix and instrumental distinctions, and rejects different performers or clearly different lengths. An accepted difference over three seconds is shown with timing adjustment; automatic tolerance is at most eight seconds. Services may lack songs or become unavailable. Plain text never receives an invented timeline. See [lyric providers](docs/LYRICS.en.md).

## Liquid Glass and motion

Wide windows place artwork and song information on the left and lyrics on the right; smaller windows use a compact layout. The Mac main window defaults to 900 × 660 and can be resized. Window → Compact / Wide (紧凑窗口 / 舒展窗口), or ⌥⌘1 / ⌥⌘2, switches between 480 × 740 and 900 × 660. The current line stands out, translations use lighter typography, and hover reveals timestamps. When following is enabled, translation batches and size changes recenter the current line. More Actions at the top contains retry and LRC import; source, timing and floating-window controls are at the bottom. Settings have Appearance, Lyrics, Translation and Connection categories, preserving existing preferences.

On macOS / iOS / iPadOS 26 or later, native Liquid Glass is used for top tool groups, bottom source/timing controls and the Mac overlay; the follow button uses lighter feedback. Lyric text stays clear and opaque. Older systems fall back to frosted materials; minimum systems remain macOS 14 / iOS 17. Native materials follow [Apple's Liquid Glass documentation](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views); application layout and interaction code was written independently.

The current line gently brightens, scales slightly and follows, with edge lyrics fading. Artwork transitions, hover and button presses provide subtle feedback. The overlay fades in/out and transitions between lines. The playback indicator represents playback state, not audio analysis. Source/translation details and per-song timing open from the bottom; setup explanations are collapsed in Settings.

The background extracts dominant artwork colors locally and renders slow, soft gradients. New artwork fades into its palette. Missing or failed artwork uses neutral colors. Covers are not uploaded to lyric or analytics services. Rendering affects color only, not lyric timing or playback.

Appearance settings offer a live preview. Liquid Glass Strength (Liquid Glass 强度) ranges from the clearest look to the strongest tint and adjusts native glass variants/tint without reducing text opacity. Background Color Strength (背景色彩浓度) is independent, with separate Album Artwork Background and Soft Background Flow switches. New defaults are 40% glass, 65% background, artwork colors on and flow on; changes save immediately. Glass strength affects custom controls and the Mac overlay without changing global system appearance.

Interface Motion defaults on and saves automatically. Turning it off, or enabling system Reduce Motion, stops custom motion. Reduce Transparency uses a solid background. Menu bar scrolling is a separate existing preference; upgrades preserve static lyrics. See [local verification](docs/VERIFICATION.en.md). The new iPhone/iPad interface has compiled but still needs physical-device checks.

## Spotify originals and translation

Prefer Spotify Original Lyrics (优先使用 Spotify 原词) defaults on. Open the separate login window from Settings and sign in on Spotify's official page. The Mac login uses a normal editable standalone window. This optional integration uses the web player's non-public lyrics interface and can be affected by region, account, session or interface changes. When reading succeeds, synchronized or plain-text Spotify originals take priority. Missing lyrics trigger fallback. Authorization/network errors are explicitly distinguished and temporarily use fallback; failures are not mislabeled as Spotify having no lyrics. Real Mac checks: 《如果呢 / 郑润泽》 returned 42 synchronized Spotify lines and only Spotify was used; 《坏女孩 / 徐良》 returned 404 while the official client also showed no lyrics, then LRCLIB synchronized lyrics were used. YouTube Music and Apple Music lyrics are not connected. See [capabilities and sources](docs/LYRICS.en.md).

Clicking a timestamped line seeks to that singing time, accounting for the song's calibration. Mac uses local Spotify automation. iOS uses official playback-control authorization; existing connections need renewed authorization and Spotify requires Premium for this API. Plain text has no reliable seek points.

Translation defaults off. Enable it and select a target in Settings → Translation (翻译). Originals appear above machine translations in the main window, draggable overlay, Mac menu bar and Live Activities. Menu bar translations use smaller text because height is limited. Compact Dynamic Island shows only an original fragment; expanded and Lock Screen layouts show both. Translation does not change timestamps.

Apple system translation requires no service key and needs macOS 15 / iOS or iPadOS 18 or later. The available-language list is obtained from the device; this Mac returned 21 language/region options including Chinese, English, Japanese, Korean, French, German, Spanish, Portuguese, Russian, Arabic and Hindi. This does not mean all pairs are supported. First use may prompt for language-pack downloads. Unsupported or failed requests are reported while originals remain visible. You can set the source language if detection is inaccurate. Keep the main window open for first use/downloads. Turning translation off hides and clears the current translations.

Bilingual background pushes require both Mac and phone to enable translation with the same target. Changing iOS translation preferences ends the old Live Activity; start a new one so background updates cannot restore disabled translations. Without an online Mac and a configured relay, background state remains at its latest update. Actual system translation and bilingual Mac windows have been checked; iPhone/iPad layout and APNs delivery await signed-device acceptance.

## iPhone/iPad builds and Dynamic Island

An [unsigned iPhone/iPad IPA](https://github.com/hhhoratioxu/VerseDock/releases/tag/v1.0.0) is available. Download `VerseDock-iOS-unsigned.ipa` and sign/install it with your own Apple identity. It retains the Dynamic Island/Lock Screen extension, with minimum iOS/iPadOS 17. A standard Xcode device build passed, but signing and physical-device acceptance are incomplete. See [IPA instructions](docs/IPA.en.md).

Open `VerseDock.xcodeproj`, select the `VerseDock` scheme, then choose your Apple development Team and device. Dynamic Island requires an iPhone with that hardware. Start a Live Activity in the app; the system manages its Dynamic Island and Lock Screen presentation.

Foreground lyrics can update, but ordinary timers are unreliable after the app enters the background. The project includes the optional `relay/` push bridge:

~~~text
Mac Spotify → VerseDock Mac → Your HTTPS relay → Apple APNs → iPhone/iPad Live Activity
~~~

The Mac must stay running and supplies the current song. Without a relay, the background activity keeps its latest lyric and becomes stale while waiting for an update. Pushes are at least five seconds apart, use low APNs priority and expire after 30 seconds. Apple scheduling, connectivity and user settings affect delivery; every line cannot be guaranteed on time. The app does not play silent audio or misuse background audio.

See [setup, redirects, signing and relay deployment](docs/SETUP.en.md).

## Original implementation and dependencies

Lyric parsing, synchronization, both platform UIs, Spotify integration, PKCE, the relay, callback page, project generator and tests were written from scratch for this project. No existing Spotify lyrics plugin, Spicetify extension or similar source was copied, renamed, wrapped or downloaded. Interfaces follow Spotify, Apple and LRCLIB documentation/public service behavior.

The Apple apps have no third-party package dependencies. They use SwiftUI, AppKit, Foundation, CryptoKit, Security, AuthenticationServices, WebKit, ActivityKit, WidgetKit, Translation and NaturalLanguage. The optional relay uses general-purpose `httpx` (HTTP/2) and `cryptography` (ES256), which retain their own licenses and are not claimed as original lyrics-plugin code. Spotify and lyric-content rights belong to their respective owners.

Local data: lyric caches use Application Support; iOS OAuth tokens and pairing keys use Keychain; optional web login uses isolated local WebKit storage. Web-lyrics authorization remains inside Spotify's page execution environment, is not exported through the native bridge, and is not sent to fallback services or the repository. The app does not read other browsers' cookies or ask users to copy cookies, passwords or Client Secrets. APNs private keys remain on your configured server. Only enabled network features send the data needed by their corresponding services.

## Build, check and test

~~~sh
# Build the Mac app locally
zsh scripts/build-mac.sh

# Type-check the iOS app and Live Activity extension
zsh scripts/check-ios.sh

# Build an iPhone/iPad device app and package the unsigned IPA
zsh scripts/build-ios-unsigned.sh

# Run the original core XCTest suite
zsh scripts/test-core.sh

# Offline original web-lyrics bridge tests; Node.js, no real account
node Tests/WebBridge/run-tests.mjs

# Regenerate the deterministic Xcode project
python3 scripts/generate-project.py

# Create and mount-check the Mac DMG
python3 scripts/package-mac-dmg.py

# Optional relay tests, after installing its dependencies as described in SETUP
cd relay
.venv/bin/python -m unittest -v test_server.py
~~~

Build inputs are explicitly listed in `Config/SwiftSources.json`. Signed Mac output lives under local `~/Library/Developer/VerseDock/Builds/`, with `build/VerseDock.app` pointing to that build. This avoids cloud-folder metadata interfering with signatures; source files and original resources are not stripped of extended attributes.

The first delivery on 2026-10-13 completed the Mac build and iOS type checks; standard Xcode builds were then blocked by the environment. On 2026-10-15, the license check passed, and the iOS app and Live Activity extension fully compiled through standard `xcodebuild` and were packaged as an unsigned IPA. No usable Apple signing certificate was available, and the app has not been installed on iPhone/iPad or accepted for real Dynamic Island/APNs behavior.

The [verification record](docs/VERIFICATION.en.md) separates current evidence from outstanding physical-device acceptance.
