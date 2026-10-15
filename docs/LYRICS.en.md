# Online lyrics and matching

[简体中文](LYRICS.zh-CN.md) · **English**

VerseDock reads the current song and position from Spotify. With original-lyrics priority on and a login in the isolated web session, it tries Spotify web lyrics first, then the configured external fallback. It does not read the Spotify desktop database or another browser's login data.

## Providers and fallback

1. **LRCLIB:** use the official search endpoint with title/artist candidates, then match after normalizing simplified/traditional Chinese. Album differences alone do not reject compilations or reissues.
2. **QQ Music:** use anonymous web services to search songs, check artist profiles and read synchronized lyrics. Chinese/English artist aliases come from service responses. This web interface has no stable third-party API commitment; changes or access rejection are reported as provider unavailability before continuing fallback.
3. **NetEase Cloud Music:** independently adapt anonymous web search and synchronized-lyrics interfaces. Match title, artist and returned aliases, version and duration. These are not stable, promised public developer lyrics APIs; interface, region and rights restrictions can affect availability. A title claiming “original singer” never substitutes for verifying the actual artist, and account cookies are not obtained.
4. **lyrics.ovh:** retrieve plain text by artist/title for full-text display. No synchronization timestamps are invented.

Fallback defaults to Automatic. Users can select LRCLIB, QQ Music, NetEase or lyrics.ovh manually; manual mode accesses only the selected fallback. Spotify remains first when original-lyrics priority is enabled. Preferences save automatically, and changes bypass the old provider's cache to recheck the current song. An explicitly imported local file retains priority so users can correct lyrics themselves.

No result, timeout, HTTP failure or invalid content moves to the next provider. Plain text is retained while synchronized lyrics are still sought; it can be displayed if none of the providers returns a synchronized version. Settings show attempted-provider results; the window footer shows the actual source and its link.

Fallback requests use VerseDock's own User-Agent, do not transmit Spotify authorization, do not download audio and do not depend on another plugin's source. Only current-song metadata is sent to each attempted provider. Networking can be switched off. Imported local files have priority; cached network plain text can be searched again for a synchronized version. External caches do not bypass Spotify checks when original priority is on. Retry bypasses caches. Coverage depends on service/network state and cannot guarantee lyrics for every song.

## Avoiding incorrect matches

Live, Remix, instrumental and unplugged version labels are retained. Artist sets must match; foreign-language aliases require artist-profile confirmation. Duration tolerance varies from three to eight seconds with song length. Differences over three seconds are shown explicitly with calibration controls. Longer edits, other artists and incompatible versions are rejected. Tolerance represents an approximate lyric match, not audio fingerprinting or word-perfect alignment.

Lyric rights belong to their respective rights holders. Commercial song lyrics are not bundled in this repository. Public evidence records metadata, source, line counts, timing ranges and request results without saving complete lyric text.

## Repeatable checks

`scripts/probe-lyrics.swift` uses the same Swift client as the app to query real services and print a summary without lyric text. Arguments are title, artist, album, seconds and an optional provider: `lrclib` / `qqMusic` / `netEase` / `lyricsOVH`. Core tests separately use original lyrics and network doubles for 404, 503, rate limits, cancellation, plain-text fallback, QQ fallback, alias confirmation and the scrolling window. Test doubles do not prove real-service success.

Interface references: [LRCLIB documentation](https://lrclib.net/docs), [lyrics.ovh API documentation](https://lyricsovh.docs.apiary.io/), [QQ Music](https://y.qq.com/). These informed independently written requests and parsing; another app's implementation was not copied.

## Spotify originals, YouTube Music and Apple Music

Version 0.1.3 added an optional Spotify web session. Spotify's public Web API still does not supply lyrics. This integration uses the web player's non-public `color-lyrics` interface and is experimental. Users sign in themselves on the official page through Connect / View Spotify Lyrics Session (连接 / 查看 Spotify 原词会话). Mac uses a separate standard window for keyboard input/focus, with a Go to Spotify Login link. Test text was entered and cleared locally without submitting a test account. A real account was subsequently verified: Spotify returned 42 synchronized lines for 《如果呢 / 郑润泽》, marked Spotify with Musixmatch as lyric provider, and Spotify was the only attempt. 《坏女孩 / 徐良》 returned 404 while the Spotify app also showed no lyrics, then LRCLIB was used. See `Evidence/spotify-original-live.json`; it contains no lyric bodies or credentials.

Original priority defaults on. Valid synchronized or plain-text Spotify lyrics are accepted without querying fallback. Only 404 or an explicitly empty body is recorded as Spotify having no lyrics. 401/403 means authorization unavailable; network errors, malformed responses and 429 are reported separately and temporarily use fallback. With original priority off, only the user's fallback policy is used. Plain text never receives fabricated timestamps.

Login state lives in isolated local WebKit storage, separate from Safari, Chrome and the Spotify desktop app. The original bridge runs only in the main page at `https://open.spotify.com` and uses that page's first-party session requests. Authorization values stay inside the page closure. The native bridge receives only readiness and filtered lyric data. Cookies, passwords, authorization headers and account details are not exported to app logs, fallback services or GitHub. Clearing the lyric session clears only this isolated store.

The interface has no stability guarantee. Account, region, login method or webpage updates may break availability. Original-data parser/fallback tests and the real local present/absent results above do not guarantee other accounts, regions or all songs. The same iOS WebKit path compiled but has no physical-device login acceptance.

YouTube caption downloads require authorization with editing permission on the video, so they cannot serve as a general lyrics provider for arbitrary songs. Apple Music's public `hasLyrics` is an availability boolean; this version has not obtained lyric bodies. Neither is connected or listed as an available working provider.

References: [Spotify's official response](https://community.spotify.com/forum/en/discussion/5355493/update-endpoint-for-lyrics), [Spotify currently-playing response](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track), [YouTube caption downloads](https://developers.google.com/youtube/v3/docs/captions/download), [Apple Music hasLyrics](https://developer.apple.com/documentation/musickit/song/haslyrics).

## Click a lyric to seek

Timestamped lines are clickable; an original line and its translation share the same button. The target equals the line timestamp minus the user's saved calibration, clamped from zero to 0.05 seconds before track end. This avoids treating the last line as a next-track request. The current track is checked before seeking; track changes and cancellation discard stale results.

Mac sets actual Spotify position through a fixed AppleScript subroutine with structured arguments, then reads track and position back. “Seek completed” appears only if the observed position is close to the target. A real click on the 0:38 line of 《愛你但說不出口》 was followed by reading Spotify at 0:39. Changing local UI progress alone is not counted as success.

iOS uses official `PUT /v1/me/player/seek` after checking track identity. OAuth adds `user-modify-playback-state`, so old connections need renewed authorization. Spotify requires Premium; failures are reported. This path has no physical-device account-control acceptance. Plain text has no accurate timestamps and cannot seek. Reference: [Spotify Seek to Position](https://developer.spotify.com/documentation/web-api/reference/seek-to-position-in-currently-playing-track).

## Optional machine translation

Translation defaults off; users choose the switch and target. The Translation framework's live device-supported list does not mean every pair can translate. System language packs are needed on first use. Unsupported pairs, cancellation and translation failures retain originals and show an explanation. Older systems retain lyrics; translation requires macOS 15 / iOS or iPadOS 18.

Original code deduplicates text, verifies response identity with the request ID and original text, and displays translations at the original timestamps. Track, target or switch changes invalidate old tasks. Repeated lines share results, and asynchronous order cannot misassign translations. Extra translations supplied by QQ/NetEase are not mixed into originals while translation defaults off. Machine translations are not official lyric translations and do not guarantee literary or contextual accuracy.

`scripts/probe-translation.swift` can recheck actual system calls and language support. It translates project-original examples with already installed packs and does not approve downloads for the user. See `Evidence/translation-system.json`. Reference: [Apple Translation](https://developer.apple.com/documentation/translation/translating-text-within-your-app).
