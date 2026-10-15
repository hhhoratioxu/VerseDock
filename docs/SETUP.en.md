# VerseDock installation and setup

[简体中文](SETUP.zh-CN.md) · **English**

## Mac

1. Download and extract the Mac ZIP, move `VerseDock.app` to Applications and open it. For local builds, run `build/VerseDock.app`. A Dock icon is present; its entry can reopen the main window.
2. Open the Spotify desktop app and start playback. VerseDock reads the local track/playback state every second and updates its own synchronization timeline every 0.1 seconds.
3. Allow macOS Automation. If previously denied, go to System Settings → Privacy & Security → Automation and allow VerseDock to read Spotify.
4. Automatic fallback searches LRCLIB, QQ Music, NetEase Cloud Music and lyrics.ovh, switching after failure. An older preference that disabled networking is preserved and can be enabled in Settings. You can import UTF-8 `.lrc` / `.txt` files, bound to the current Spotify track ID. Retry bypasses caches. The footer shows the actual source and duration difference.
5. Click Floating Lyrics (悬浮歌词). Drag the lyrics or empty window space to move it; position/size save automatically. Right-click to hide it or change font size. The top menu bar defaults to static 18-character lyrics. Adjust width and scrolling independently in its menu or Settings; preferences save automatically. Closing the main window leaves lyrics running, and Dock/menu bar entries can reopen it. Positive calibration advances lyrics; negative calibration delays them, saved per song. Timestamped lines seek actual playback.
6. Prefer Spotify Original Lyrics (优先使用 Spotify 原词) defaults on. Open Connect / View Spotify Lyrics Session (连接 / 查看 Spotify 原词会话) and sign in on the official page in the separate window; use Go to Spotify Login if needed. This non-public web integration may stop working. Local real-service checks confirmed original priority and fallback after absence. Available originals win; absence or temporary failure uses fallback, with distinct reasons. Fallback can be Automatic or a single provider; manual mode accesses only the selected fallback. YouTube Music and Apple Music lyrics are not connected. The actual source is always identified.
7. Translation defaults off. Enable Lyric Translation (歌词翻译) and choose a target; download system language packs when prompted. It requires macOS 15 / iOS 18 or later. Originals appear above translations, and switching off removes translations. Set a source language if detection is inaccurate; unsupported language pairs are reported.

The original demo is clearly marked and only checks UI/synchronization. It is not evidence of real Spotify integration.

The current app uses a local ad hoc signature for development acceptance. Distribution to other Macs needs Apple developer signing/notarization, which have not been completed. Direct build scripts target Apple Silicon. Other architectures can be configured in Xcode; Intel is untested.

## Interface and Liquid Glass

Version 0.1.9 uses the system toolbar. The gear and ⌘, open a separate Mac Settings window; iPhone/iPad use native category lists with back navigation. Categories are Appearance, Lyrics, Translation and Connection. Appearance contains glass, artwork-background and Mac display options; Lyrics manages providers and the original-lyrics session; Translation selects languages; Connection manages phone OAuth and the relay. More Actions contains retry, LRC import and the original demo. Wide windows use cover/lyrics columns, while small windows use the compact layout. New Mac windows default to 900 × 660.

Liquid Glass Strength ranges from the clearest look to the strongest tint; Background Color Strength is independent. Both preview immediately and save automatically. Colors are extracted locally from real artwork and transition softly. Album Artwork Background and Soft Background Flow have separate switches. New defaults are 40% glass and 65% background. Missing artwork uses neutral colors; text remains opaque. The system controls the native main-window toolbar's appearance. App strength controls affect the small footer group, floating window and Settings preview without overriding system toolbar glass preferences. Middle values use lighter tint; 100% retains the full tint. Settings follow system appearance, while the listening window stays dark.

Appearance & Interaction offers Interface Motion, on by default. OS 26 or later uses native Liquid Glass; older systems retain frosted materials. System Reduce Motion/Reduce Transparency are respected without changing those settings for the user. Source details, translation status and timing open from the footer. Existing source, language, menu bar width and scrolling preferences are preserved.

Building this version needs Xcode with macOS 26 / iPhoneOS 26 or newer SDKs. Runtime compatibility remains macOS 14 / iOS 17. The local builds used Xcode 27.

## Xcode license and development environment

At initial delivery on 2026-10-13, local `xcodebuild` reported an unaccepted license. On 2026-10-15, license and first-launch checks passed and full device builds became available. If another computer prompts for a license, read and accept Xcode's terms yourself. Build scripts do not accept terms, change the system developer directory or install runtimes for you.

Open `VerseDock.xcodeproj`:

- Mac scheme: `VerseDockMac`.
- iPhone/iPad scheme: `VerseDock`, also building `VerseCore` and `VerseDockActivity`.
- Choose the same Apple Team in Signing & Capabilities for app and extension.
- Bundle IDs can change, but the extension ID must begin with the main app ID, and server `APNS_BUNDLE_ID` must exactly match the main app ID.
- Current IDs: `com.horatio.versedock` and `com.horatio.versedock.activity`.
- Development signing uses `APNS_ENVIRONMENT=development` with server `APNS_ENV=sandbox`. TestFlight/production distribution needs the production environment and matching provisioning profiles.
- APNs capabilities generally require an entitled Apple Developer Team, certificates and profiles. Without valid signing, the device IPA is not directly installable.

## Official Spotify authorization

Local Mac integration does not need these steps; iOS account playback does.

1. Configure an app in your Spotify Developer Dashboard and copy the Client ID. The development-mode rules recorded for this release require the owner to have Premium and actual login accounts to be allowlisted, with a five-user limit for new apps.
2. Host `web/callback.html`, `callback.js` and `callback.css` on your own HTTPS site, retaining relative paths. Example final address: `https://your-own-domain.example/callback.html`.
3. Register that exact HTTPS URL as Spotify's Redirect URI. Spotify requires exact matching; ordinary HTTP domains and `localhost` do not meet the documented requirements.
4. Enter the Client ID and identical redirect in VerseDock iOS Settings, then choose Connect Spotify (连接 Spotify).
5. After browser authorization, click Return to VerseDock on the callback page. It hands the code back through `versedock://oauth`. The app validates random state and exchanges the code with the PKCE verifier. Register the HTTPS redirect with Spotify, not the custom scheme.
6. Avoid analytics scripts on the callback site. Disable access-log query strings or mask them to avoid recording short-lived codes. The page disables referrers, promptly removes address-bar parameters, and does not exchange or store Spotify tokens server-side.

Scopes are `user-read-currently-playing` and `user-modify-playback-state`; the latter supports lyric seeking, so old connections need renewed authorization. Spotify requires Premium for seeking. Playlist modification and passwords are not requested. Foreground polling runs every three seconds, respects Retry-After on 429, refreshes once on 401 and explicitly reports account/developer-permission errors on 403. OAuth uses a system browser session and stores tokens in local Keychain. This official playback authorization is independent of optional web-lyrics login and cannot replace it.

## Dynamic Island and the iPad Lock Screen

On an iPhone with Dynamic Island, choose Enable Dynamic Island (开启灵动岛). The compact area shows about six characters; long-press to expand for current/next lyrics and song title. Other iPhones and iPad use Lock Screen Live Activities. iPad has no Dynamic Island. Actual device support and system permission determine availability.

Foreground Live Activities share the full lyrics window's state. With translation on, expanded/Lock Screen layouts show originals above translations; compact Dynamic Island retains only short original text. Background operation requires pushes. Without a relay, the latest lyric remains and becomes stale after 30 seconds. This does not constitute background line-by-line synchronization.

## Deploy the optional APNs relay

The relay implementation exists but has not been deployed to your server, and no ECS, DNS or network configuration was changed. Choose an HTTPS endpoint and prepare the Apple APNs `.p8` key, Key ID and Team ID on the server. Do not paste private keys into chat, app settings or the source repository.

With Python 3.9 or later, create an isolated environment in `relay/`:

~~~sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
~~~

Set process environment variables. Keep real values in protected service configuration files outside version control:

| Variable | Purpose |
|---|---|
| RELAY_KEY | Random pairing key, at least 32 characters; identical on Mac and iOS |
| APNS_TEAM_ID | Apple Developer Team ID |
| APNS_KEY_ID | APNs signing Key ID |
| APNS_KEY_PATH | Absolute path to the server's .p8 private key; restrict read permissions |
| APNS_BUNDLE_ID | Main iOS app bundle ID, currently com.horatio.versedock |
| APNS_ENV | sandbox or production, matching app signing |
| RELAY_PORT | Local listening port, default 8787 |
| RELAY_DB | Registration database path, default activities.sqlite |

Run `.venv/bin/python server.py`. The service listens only on `127.0.0.1` and needs your HTTPS reverse proxy. Forward `/register`, `/unregister` and `/update` unchanged, preserving Authorization. The service also provides `/callback.html`, `/callback.js` and `/callback.css` for the Spotify redirect. Enter the root HTTPS service URL on both devices.

Bilingual pushes require both Mac and iOS to enable translation and choose the same target. Changing iOS translation preferences ends the old activity; start another. Phones with translation off or a different target do not receive translated text. Update the relay when upgrading this version.

Pairing:

1. Enter the service URL and the same RELAY_KEY on Mac/iOS, enable Background Push Relay (后台推送桥), and save.
2. End the old iOS Live Activity and start a new one to request a push token.
3. Confirm iOS reports background push registration and Mac Settings report successful lyric sending.
4. Keep Mac Spotify playing and VerseDock running, then background or lock the iPhone and inspect delivery.
5. Activity end unregisters it; APNs expired-token responses remove server registrations. A service supports one paired household/user group with at most eight activities. Do not share one key across tenants.

Mac supplies playback and lyrics in this mode. Independent phone playback with the Mac shut down would need a separate server-side Spotify OAuth/polling implementation; this version does not provide it.

APNs `200` means Apple accepted the request, not that a device displayed it. Low-priority pushes and 30-second expiry avoid a backlog of old lyrics; sends are at least five seconds apart. Apple may delay, merge or limit updates. Precise karaoke-style background timing is not guaranteed; actual arrival/display requires device checks.

## References

- [Spotify currently-playing API](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track)
- [Spotify PKCE flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- [Spotify redirect URI rules](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri)
- [Spotify 2026 development-mode changes](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)
- [ActivityKit APNs updates](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [Apple background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
- [LRCLIB documentation](https://lrclib.net/docs)

These references establish API/platform behavior; plugin implementations were not copied.
