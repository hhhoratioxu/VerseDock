# Verification record

[简体中文](VERIFICATION.zh-CN.md) · **English**

Latest inspection: 2026-10-15, Asia/Shanghai. New records appear first; delivery evidence follows in historical order. Final settings and unavailable integrations in historical entries describe their state at that time.

## 2026-10-15: 1.0.0 stable-release checks

| Item | Result and evidence |
|---|---|
| Version and scope | Mac, iOS app and Live Activity extension are unified at 1.0.0 (100). GitHub uses a regular Release for the Mac app, DMG, unsigned IPA and complete source. iOS signing/device limits remain explicit. |
| Main window | Mac uses a single SwiftUI Window, restored through the app entry. Window → Compact / Wide (紧凑窗口 / 舒展窗口), or ⌥⌘1 / ⌥⌘2, selects layouts. Its native ID is main, replacing multiple main-lyrics WindowGroup instances. After closing and reacquiring the app, main and its native toolbar were visible. The tool activates the app automatically; this does not establish a literal Dock click or observation of a zero-window state. |
| Completed runtime checks | Installed/launched local 1.0.0 and observed actual Spotify / Musixmatch originals, with real playback paused at 0:04 / 4:53. The explicitly marked original demo was then used without controlling real Spotify audio. ⌥⌘1 actually produced a 480 × 740 compact window, captured at 960 × 1480 pixels. ⌘, opened the separate Settings window and Appearance page. |
| Preferences and this run's limits | Observed preferences were 0% glass, 100% background, flow/motion on, static 18-character menu bar and overlay font 28. They were not reset to defaults. When continuing to Translation settings, the tool reported a locked Mac. Final wide-window switching, Translation/Connection pages and returning from the original demo to real playback still await unlocking. Earlier-version checks are not represented as repeated passes. |
| Automated tests | Actually ran 42 core XCTest cases, six offline web-bridge tests and nine relay tests; all passed. The bridge uses no real credentials. Relay tests exercise real local HTTP with APNs doubles, not actual Apple delivery. |
| Online fallback | The same 1.0 Swift client actually retrieved 80 synchronized QQ Music lines. Public evidence records only provider/count/result, not commercial lyric text. Original priority and existing error distinctions are preserved. |
| Mac build/signature | Final optimized build passed. Signed output now lives outside cloud-synchronized folders, with build/VerseDock.app pointing to it; source-resource attributes are no longer recursively stripped. Build, install candidate and installed app passed strict signature validation. Installed/build executable SHA-256 values match. The previous installed app is retained. |
| Mac DMG | Adds the app, Applications drag target and bilingual instructions. Image integrity, read-only mounting, embedded strict signature and executable-identity checks passed. The image was detached after inspection. |
| iOS/source packaging | Standard iPhone/iPad app and Live Activity extension Release device builds passed with matching versions. Packaging actually ran in a separate non-Git temporary directory and produced an identical IPA; unavailable commits are reported as null. SwiftPM, direct scripts and Xcode use explicit source lists, excluding temporary Swift copies. |
| Outstanding platform acceptance | Zero valid Apple signing identities are available locally. Mac is locally/ad hoc signed without Developer ID notarization. IPA has no Apple signature/personal profile; iPhone/iPad installation, Dynamic Island, iOS authorization and actual APNs delivery remain unaccepted. Older materials, accessibility, other Macs and Intel have not been independently exercised. |

Public summary: `Evidence/release-1.0.0.json`. Signing/hash information accompanies downloads. Release notes and usage documents retain complete Chinese/English versions. Historical entries below retain their release-time states.

## 2026-10-15: 0.1.9 runtime follow-up and sharp default artwork

| Item | Result and evidence |
|---|---|
| Installation and launch | After the user unlocked the Mac, 0.1.8 was installed/launched. The default artwork was then corrected and final 0.1.9 (10) installed/launched. Both older copies were retained. Installed and packaged executables match and passed strict signature validation. |
| Real Spotify originals and final state | Both versions restored the original-lyrics session after launch, with Spotify / Musixmatch shown. The initial snapshot was paused at 0:42 / 4:23. After the user closed the system menu, the original demo was exited and real originals appeared again. The current track/state subsequently changed; the final window was paused at 0:59 / 4:06 using QQ fallback lyrics. The agent did not play, pause, change tracks or seek real playback during inspection. The earlier 0:42 snapshot is not the final playback state. |
| Main window and bilingual lyrics | Final 0.1.9's 900 × 660 window actually displayed the native title bar/toolbar, two columns, white progress, compact footer tools and sharp default artwork. Actual system English translations appeared below original demo lyrics, and current-line centering was observed. A real 0:13 bilingual screenshot was saved. |
| Settings | In final 0.1.9, ⌘, opened the separate system Settings window; Appearance, Lyrics, Translation and Connection were opened individually. Version 0.1.9 was visible. The glass slider was set to 0% and 100%, preview changes inspected, then restored to 40%. Other preferences remained: 65% background, flow/motion on, English translation, static 18-character menu bar, overlay font 28 and relay off. System appearance/accessibility preferences were not changed. |
| Additional interaction checks | In 0.1.8, real checks covered source details opening Lyrics settings, the native More menu, original-demo seeking to 0:10/0:05, following, and bilingual glass floating lyrics with right-click hiding. Version 0.1.9 only changes artwork, version and delivery records; layout/interaction logic is unchanged. These earlier checks are not reported as repeated final-version tests. |
| Default artwork clarity | The previous 128 × 128 image visibly blurred when enlarged. Mac/iOS now reuse the repository's original 1024 × 1024 image byte-for-byte, without redrawing the icon, changing the brand or copying external artwork. Sharp edges were observed in the final runtime. |
| Window sizing and restoration limits | Final 0.1.9 used the native zoom action exposed by the system window button: 900 × 660 → 1728 × 1021 → 900 × 660. Cover, lyrics, progress and toolbar remained visible when enlarged. A final check through the installed app entry showed the complete normal window with real lyrics and native toolbar. Closing one main window exposed another, so this does not prove creation after closing the last window. The 0.1.8 checks of 480 × 740 and app-entry window creation remain separate. |
| Builds | Final optimized Mac arm64 build and installed/packaged strict signature checks passed. iOS app and Live Activity extension Release device builds passed, both 0.1.9 (10). The resource change does not alter lyric, authorization, translation or relay policy; extra implementation-mirroring tests were not added for it. |
| Unverified scope | Final 0.1.9 did not independently recheck 480 × 740, creation after closing the last main window, or a literal Dock icon click. Ineffective resize dragging, the close-all shortcut and previous-version checks are not counted as passes. iOS still needs signing; physical-device layout, Dynamic Island and APNs delivery are unaccepted. Older materials, system light appearance and accessibility paths have not been independently run. |

Public runtime summary: `Evidence/ui-apple-runtime-0.1.9.json`. Saved delivery screenshots contain only original demo lyrics and ordinary settings, without commercial lyrics, account details or credentials. Follow-up checks update this summary/documentation only; packages were not rebuilt and the tag was not moved. Release assets/source remain at `fc01dd69e12143d7bb1d67905e0d2129007b06e8`. The locked-Mac state under 0.1.8 below is its initial publication record.

## 2026-10-15: 0.1.8 native Apple style

| Item | Result and evidence |
|---|---|
| Native navigation/settings | Original SwiftUI code adopts the system toolbar and standard Mac title bar. Mac uses a separate Settings scene with native four-tab TabView and the system Settings menu/⌘,. iPhone/iPad use NavigationStack and category lists with contextual entry points. Settings no longer force dark appearance; previews no longer modify their host window's material/appearance. |
| Content hierarchy | Removed the duplicate brand header and full-width bottom glass strip, leaving a compact footer group. Progress, follow and playback use neutral colors; background colors still come from artwork. Wide columns, compact layout, originals above translations and current-line centering remain. Cover hover now scales slightly without 3D tilt. |
| User control | Glass/background strength, soft flow, motion, original priority/fallback, translation and menu bar width/scrolling remain. Middle glass values have less tint, while 100% retains the prior maximum. Strength affects only custom tool groups, overlay and preview; the native toolbar follows system materials. User settings were not rewritten while locked. |
| Window restoration | Reopening from Dock/menu bar after closing the main window prefers the same SwiftUI WindowGroup to preserve the native toolbar; the legacy native fallback remains. This path was built but had not completed the new version's interaction acceptance at publication. |
| Builds | Final optimized Mac arm64 build and candidate strict signature checks passed. iPhone/iPad app and Live Activity extension standard Release device builds passed, version 0.1.8 (9). Minimum systems: Mac 14 / iOS 17; Liquid Glass needs OS 26+. |
| Runtime block at publication | The native tool again reported a locked Mac requiring manual unlocking. Version 0.1.8 had neither replaced the installed older copy nor launched locally; no actual new-app screenshots were produced. Pending: toolbar, four Settings tabs/shortcut/contextual entry, light/dark appearance, close/reopen, compact/wide layouts, final centering and original-demo clicks. Earlier 0.1.7-initial/0.1.6 results below are not proof of 0.1.8 runtime. |
| Other limits | iOS is unsigned, with no physical-device, Dynamic Island or APNs acceptance. Older materials and accessibility paths have not been independently exercised. Lyrics/authorization policies are unchanged; existing core/web-bridge evidence carries forward. Code was written independently without copying an open-source interface or adding a UI package. |

Design references are Apple's [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) and [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass). Only system APIs/design principles are used. Public summary: `Evidence/ui-apple-style-0.1.8.json`.

## 2026-10-15: 0.1.7 interface refinements

| Item | Result and evidence |
|---|---|
| Actual compact window | The installed initial 0.1.7 runtime was checked at 480 × 740: clearer artwork hierarchy, refined original/translation typography, one glass tool group and footer source/timing/overlay controls. |
| Actual wide window | Native File → New VerseDock Window created a 900 × 660 window with large artwork/song details left and lyrics right. Real artwork/colors, Spotify originals and system English translations appeared. Real Spotify playback was not controlled for design inspection. |
| Settings structure | The initial Appearance page was opened. Four categories and a preview using current artwork/material were visible. Existing preferences remained: 40% glass, 65% background, flow/motion on, English translation and static 18-character menu bar. |
| Final patches | Runtime observations led to recentering after translation batches/size changes, simpler/corrected preview corners, source details opening Lyrics, and disconnected iOS opening Connection. These patches built but had not completed independent manual interaction checks. |
| Runtime acceptance block | The Mac was locked during final checking, and the native tool explicitly required manual unlocking. Final candidate and inspected initial runtime were retained separately. Initial checks do not establish full acceptance/relaunch of the final candidate. Pending: four categories, contextual entries, final preview, More menu and original-demo clicks. |
| Builds/limits | Final optimized Mac arm64 build and candidate strict signature passed. iPhone/iPad app and Live Activity extension standard Release device builds passed, version 0.1.7 (8). iOS remains unsigned without physical-device/APNs evidence. Lyric policy is unchanged, carrying forward existing core/bridge tests. |

Public summary: `Evidence/ui-design-0.1.7.json`. Final small patches, iOS compilation and earlier-version results are not reported as a new complete runtime acceptance.

## 2026-10-15: 0.1.6 flowing artwork background and adjustable glass

| Item | Result and evidence |
|---|---|
| Artwork palette | Real Spotify artwork colors for 《那页夏天 / 王俊凱》 were extracted locally, and Settings reported colors from current artwork. Entering the coverless original demo returned to neutral colors; leaving restored the real palette. Real playback was not controlled for UI inspection. |
| Palette probes | The same extraction implementation processed locally generated red, green, blue and gray PNGs, preserving their main colors. Gray gained no extra hue; corrupt images were rejected. Original-icon greens were also checked. Local color-space conversion does not require output bytes to equal input device color values. This is not a two-real-album runtime test. |
| Soft flow | Separate frames with flow on showed changing gradient positions; frames with flow off showed a static preview. Flow and interface motion retain separate switches. Code stops background animation for inactive scenes, Reduce Motion or Reduce Transparency. System accessibility preferences were not changed for testing. |
| Live strength preview | Glass strength was set to 0%/100% and preview changes observed. Background strength separately reached 0%/100% without changing glass. The final continuous sliders were inspected without duplicate labels/discrete ticks. Native glass uses clear/regular variants and tint without reducing text opacity. |
| Restart persistence | Set glass to 73%, background to 81% and flow off, saved/quit, and relaunched the final installed app; all three restored. Afterwards, restored new defaults: glass 40%, background 65%, artwork background/flow on, motion on. |
| Existing behavior/preferences | Opened the overlay under the new appearance and hid it through its context menu. Leaving the original demo restored real synchronized QQ lyrics. Spotify-original priority, automatic fallback, English translation, static 18-character menu bar, overlay font 28 and hidden state remained. Settings were open for user adjustment. No lyric-policy changes or external plugin code were introduced. |
| Builds | Optimized Mac arm64 build and installed strict signature passed. iPhone/iPad app and Live Activity extension standard Release device builds passed, version 0.1.6 (7). Native Liquid Glass still needs OS 26+; minimum Mac 14 / iOS 17 remains. |
| Limits | iPhone/iPad are unsigned and unaccepted on devices. Older materials, system accessibility switches, HTTP failure injection and slow-cover races were not independently run. Code includes cover-request cancellation/URL rechecks, a 12-entry palette cache and decode-failure fallback. The 42 core tests/six offline bridge tests carry forward from 0.1.3; builds/palette probes do not prove device behavior. |

Public summary: `Evidence/ui-ambient-glass-0.1.6.json`. Screenshots remain local. The summary contains no commercial lyric bodies, artwork files, account details or credentials.

## 2026-10-15: 0.1.5 Liquid Glass and motion

| Item | Result and evidence |
|---|---|
| Native materials | Original SwiftUI integrates Apple `glassEffect` and `GlassEffectContainer`. The actual installed app reported native Liquid Glass in Settings. Toolbar, source, timing, follow controls and overlay were visually checked; title bar and main background matched. No other lyrics plugin/UI package was copied or added. |
| Lyric transitions | The clearly marked original demo actually ran. Current-line changes at 0:00, 0:05, 0:15 and 0:30, progress, following and bilingual layout were observed. Replay was used and a real 0:07 screenshot saved locally. The demo does not play/control real Spotify audio. |
| Floating lyrics | The native glass overlay was opened. Originals and actual system English translations changed with demo lines, then the context menu hid it. Dragging/persistence code remained; earlier passed drag acceptance was not repeated this round. |
| Switches/preferences | Interface Motion stayed off after quitting/reopening, then stayed on after enabling/reopening; final state is on. Source/timing popovers opened; calibration remained zero. Ordinary settings saving did not show the unrelated pairing-key error. Existing original priority, automatic fallback, English translation, static 18-character menu bar, font 28 and hidden overlay were preserved. |
| Real playback restored | Leaving the demo restored 《那页夏天 / 王俊凱》 paused at 1:14 / 4:06 with QQ synchronized lyrics. Settings showed Spotify absent, LRCLIB unmatched and QQ synchronized. Real playback was not changed for the preview. The 0.1.4 original-success/404-fallback evidence remains; demo results do not replace it. |
| Builds/signatures | Optimized Mac arm64 build and installed strict signature passed. iPhone/iPad app and Live Activity extension standard Release device builds passed, version 0.1.5 (6). No new lyric-policy tests were added; 42 core/six offline bridge execution results carry forward from 0.1.3. |
| Compatibility/limits | Native Liquid Glass needs macOS / iOS / iPadOS 26. Older systems use frosted fallback, minimum Mac 14 / iOS 17. Code respects Reduce Motion/Transparency without changing system preferences. Older fallback/accessibility paths are not independently accepted. iPhone/iPad use unsigned IPA, without real-device visual, interaction or APNs acceptance. |

Public summary: `Evidence/ui-liquid-glass-0.1.5.json`, without commercial lyric text, account details or credentials. Mac screenshots show the actual original demo runtime.

## 2026-10-15: 0.1.4 real Spotify-original verification

| Item | Result and evidence |
|---|---|
| User login | The user signed in directly in the separate official window, without sending passwords, codes or cookies through chat. |
| Originals take priority | Playback naturally moved to 《如果呢 / 郑润泽》. Spotify returned 42 synchronized lines spanning 6.22–235.03 seconds. The window identified Spotify / Musixmatch, Settings reported originals taking priority, and the attempt log contained only Spotify. |
| Fallback after absence | The real Spotify request for 《坏女孩 / 徐良》 returned 404 while the official desktop client also showed no lyrics. VerseDock then retrieved synchronized LRCLIB lyrics. Matching results did not confuse authorization failure with absence. |
| Session restoration fix | The restoration marker is retained even if the first post-login song has no lyrics. Both 404 and valid 200 responses can confirm restoration. The installed 0.1.4 was actually quit/relaunched: without another login or connection window, the session restored and originals returned, with Spotify as the only attempt. |
| Ordinary settings saving | An empty, unconfigured relay key is no longer written to Keychain, avoiding an unrelated pairing-key error during ordinary saving. Existing nonempty keys still use Keychain. A real save confirmed the error was absent. |
| Builds/limits | Mac and iOS app/Live Activity extension rebuilt successfully, version 0.1.4 (5). The installed Mac passed strict signature validation. Core/bridge policy evidence carries forward 42 XCTest cases and six offline tests from 0.1.3. Local results do not validate other accounts, regions or iOS devices; the non-public interface can change. |

Present/absent summaries are in `Evidence/spotify-original-live.json`, without lyric bodies, cookies, authorization headers, account details or signing material. The following 0.1.3 entry retains its historical pre-login state.

## 2026-10-15: 0.1.3 Dock, login input and lyric seeking

| Item | Result and evidence |
|---|---|
| Regular Mac entry | `LSUIElement=false` and regular activation mode add a Dock entry; reopen events show the main window, while closing it retains menu bar lyrics. The new app was installed in the user's Applications folder and passed strict signature validation. An actual Dock click still awaited independent manual confirmation. |
| Spotify login input | Settings closes before opening a separate standard Mac window, replacing nested settings presentation. The official Email field was clicked, original test text entered and confirmed through accessibility, then cleared. No test account was submitted or real password entered. |
| Real seeking | A real click on the 0:38 line of 《愛你但說不出口 / Karencici》 was followed by a local Spotify read-back of 0:39 / 2:53; the app reported seeking to 0:38. Both original/translation are clickable; plain text has no seek button. |
| Original-priority policy | On by default. Valid synchronized/plain originals stop fallback. Absence, 401/403, 429 and network errors are separate results; temporary failure uses the selected fallback. External cache does not skip originals; explicitly imported local files remain first. |
| Real Spotify originals | Isolated WebKit/non-public lyrics integration, login window and input were implemented/checked. No successful real-account lyric response had yet been obtained at this release. User login was needed; parsing, doubles and fallback were not described as a real Spotify-original connection. |
| Core XCTest | 42 passed, zero failures: `Evidence/core-tests-0.1.3.txt`. Added parsing, original priority, manual-fallback isolation, error distinctions, cancellation, inverse calibration, end clamping and official seek-request checks. |
| Offline web bridge | Six passed without real networking/credentials. Checks cover isolated origin, expired authorization/recovery, HTTP statuses, lyric-only exports, first-party request observation and keeping client-token in the page: `Evidence/spotify-bridge-tests-0.1.3.json`. |
| Latest builds | Standard Mac arm64 and iOS app/Live Activity extension Release device builds passed, version 0.1.3 (4). iOS remains unsigned without device login, seeking, layout or APNs checks. |
| User preferences | Existing English translation, automatic fallback and static 18-character menu bar were preserved. Detection reduces opening production-credit interference; actual system translations continued displaying locally. |

Runtime summary: `Evidence/mac-spotify-runtime-0.1.3.json`. The experimental web interface has no public Spotify API stability guarantee.

## 2026-10-15: 0.1.2 lyrics, preferences and translation

| Item | Result and evidence |
|---|---|
| Real online lyrics | The same Swift client actually queried LRCLIB, QQ, NetEase and lyrics.ovh and received synchronized or plain lyrics. NetEase checks returned 48 synchronized lines for 《十年 / Eason Chan》 and 54 for 《Yellow / Coldplay》. `Evidence/lyrics-live-services.json` excludes lyric text. |
| Real app fallback | Actual Settings showed QQ synchronized lyrics for 《十年》 after LRCLIB rate limiting; another run showed QQ retrieving 《幸福在歌唱》 after HTTP 503. Fallback was not established only with doubles. |
| Matching/source selection | Original title, Chinese-script, version, duration and alias matching rejects other performers. Selecting NetEase actually retrieved synchronized lyrics, then Automatic was restored. Choices save automatically; manual mode accesses only that service. Source/link were visible. |
| Actual menu bar lyrics | Uses native NSStatusBar button text. The user explicitly confirmed visible, scrolling lyrics. Afterwards, width was adjusted and scrolling disabled as requested; final value was static 18 characters. Users can choose 8–40 characters and scrolling independently. |
| Floating drag | A real drag changed saved bounds from `538 72 760 145` to `54 874 760 145`. Offscreen recovery/persistence logic exists. Earlier failed attempts are not counted, and no separate manual restart-position check was performed. |
| Actual system translation | Translation returned 21 language/region options locally. After language packs were installed, original English examples actually translated to Chinese: `Evidence/translation-system.json`. Not every pair was checked. |
| Mac bilingual display | With real Spotify playback and QQ lyrics, a system English batch for 39 deduplicated texts completed. Original-above-translation appeared in main/floating windows; switching off removed translations. Two-line menu bar rendering built but lacked independent visual acceptance. |
| Core XCTest | 31 passed, zero failures. Added source errors, 404, retained rate limits, cancellation, manual isolation, QQ/NetEase aliases, excluding default-off translations, absence not mislabeled instrumental, Unicode scrolling and translation identity: `Evidence/core-tests-0.1.2.txt`. |
| Relay tests | Nine passed, zero failures. Added optional translation-field validation and device switch/target matching before sending translations. HTTP used a real local service; APNs remained a double: `Evidence/relay-tests-0.1.2.txt`. |
| Builds | Local Mac arm64 and standard iOS app/Live Activity extension Release device builds passed, version 0.1.2 (3). Minimum Mac 14 / iOS 17; translation needs Mac 15 / iOS or iPadOS 18. IPA unsigned, without device installation/layout acceptance. |
| Final settings | Automatic source, static 18-character menu bar, translation off and overlay hidden. Runtime summary: `Evidence/mac-lyrics-runtime.json`. |
| Platform limits | Official Spotify lyrics were unconnected at this release; playback API data could not determine lyric presence/absence for original priority. YouTube/Apple Music lyrics were also unconnected. UI and `docs/LYRICS.zh-CN.md` disclosed this without fabricated providers/results. |

## 2026-10-15: 0.1.1 icon update

| Item | Result and evidence |
|---|---|
| Origin | Built-in imagegen created the V/lyric-line artwork; prompt/export details are in `Artwork/README.md`. No Spotify logo was downloaded/reused. |
| Master/iOS resources | Opaque 1024 × 1024 PNG. Xcode device builds compiled AppIcon/BrandMark; iPhone/iPad Info.plist references AppIcon. |
| Mac resources/UI | .icns and BrandMark entered Resources. The rebuilt Mac app was opened and its new top V image observed. |
| Mac download | Strict signature validation passed after extracting to a temporary directory. Icons match source resources; local Finder extended metadata was excluded. |
| iOS download | Full device build passed. IPA includes Assets.car, iPhone/iPad icons and Live Activity extension; app/extension are 0.1.1 (2). |
| Limits | IPA remains unsigned with no new device-installation/Dynamic Island evidence. Lyrics, OAuth and relay logic were unchanged. Resource summary: `Evidence/icon-assets.json`. |

## 2026-10-15: full iOS device build and unsigned IPA

| Item | Result and evidence |
|---|---|
| Environment recheck | Xcode 27.0, Build 27A266a; license/first-launch checks passed. No command accepted terms on the user's behalf. |
| Apple signing identities | Local inspection found zero valid code-signing identities. No personal signing materials were requested, imported or published. |
| Main iOS app | Standard xcodebuild Release device build passed, producing an actual arm64 iPhoneOS executable, minimum OS 17.0. |
| Dynamic Island/Lock Screen extension | The same build produced VerseDockActivity.appex and embedded it in PlugIns. Platform, device families, bundle-ID prefix and version relationships were checked. |
| Unsigned IPA | Standard Payload/VerseDock.app layout contains app/extension. ZIP integrity, Mach-O platform, permissions and binary hashes were verified. No Apple signature or embedded.mobileprovision. |
| Public build information | `Evidence/ios-device-build.json`. Raw logs remain locally at `build/ios-build.log`, excluding personal directory paths from publication. |
| Device installation/runtime | Unaccepted. The user chose an unsigned IPA to sign/install later. Compilation/packaging is not proof of real-device operation. |
| Spotify OAuth / APNs | No real account authorization, signed-device or APNs delivery evidence at this point; see setup requirements. |

## 2026-10-13: initial delivery

These results/environment limits describe initial delivery, not continued Xcode blockage on October 15.

| Item | Result and evidence |
|---|---|
| Mac arm64 compilation | Passed: `Evidence/mac-build.txt`; output `build/VerseDock.app`. Minimum macOS 14, local ad hoc signature. |
| Main window | Actually opened and checked for track card, lyrics, progress, timing, import and Settings access. |
| Original demo sync | Original test lyrics actually ran, with highlight, progress and following observed. The demo clearly indicates no real playback connection. |
| Desktop overlay | Actually opened and remained after the main window closed, displaying the current Spotify song/state. |
| Real Spotify reading | Passed. Tracks including 《有没有 / 張靚穎》 and 《說好不哭 / 周杰倫》, artwork, duration and position were read and updated with track changes. Local integration evidence only; no account data exported. |
| Online lyrics | Enabled and LRCLIB queries sent. Tested songs had no match, and the app explicitly offered LRC import. No match was not reported as synchronized-lyric success. |
| LRC/OAuth core | 13 XCTest cases passed, zero failures: repeated timestamps, bilingual lines, offset, invalid input, calibration, pause, seek bounds, PKCE vectors, state/duplicate-parameter rejection, form encoding and 429. See `Evidence/core-tests.txt`. |
| Relay | Seven tests passed, zero failures: real local HTTP authorization, content state, input bounds, throttling, no activities, APNs failure and expired-token cleanup. APNs used doubles, not real Apple delivery: `Evidence/relay-tests.txt`. |
| iOS source | Type-checked with installed iPhoneOS SDK/Swift: `Evidence/ios-typecheck.txt`. |
| Live Activity source | Also type-checked, including compact/minimal/expanded Dynamic Island and Lock Screen layouts. This does not accept WidgetKit device layout. |
| Project structure | project.pbxproj and Info.plist passed plutil -lint. The project includes shared static core, Mac app, iOS app and embedded Live Activity extension. |
| Standard Xcode build | Incomplete: local Xcode reported an unaccepted Apple license. Terms were not accepted on the user's behalf. |
| iOS simulator | Not run: the required CoreSimulator executable was missing. No runtime was installed or development environment changed. |
| iPhone/iPad | Not run: the user selected Mac app and both platforms' source. Apple Team signing, device installation, Spotify Client ID, HTTPS redirect and APNs key configuration were unavailable. |
| Background Live Activity delivery | Unaccepted. Server/client registration/sending code exists, but signed devices and APNs configuration are needed. Mac must stay online; Apple may delay/merge pushes. |
| Intel Mac, formal distribution, notarization | Unaccepted. Only the local Apple Silicon executable was verified. |

## Commands for checking evidence

~~~sh
zsh scripts/test-core.sh
zsh scripts/check-ios.sh
zsh scripts/build-mac.sh
plutil -lint VerseDock.xcodeproj/project.pbxproj Config/Mac-Info.plist Config/iOS-Info.plist Config/Widget-Info.plist
cd relay
.venv/bin/python -m unittest -v test_server.py
~~~

Core tests use actual XCTest execution, not compilation as a substitute. Relay tests using APNs doubles establish local protocol/error handling, not real delivery. Unmatched online lyrics are accurately reported service results; coverage depends on providers.
