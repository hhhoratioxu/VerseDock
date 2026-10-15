import SwiftUI
import VerseCore
#if os(macOS)
import AppKit
#endif

@MainActor final class VerseModel: ObservableObject {
    static let shared = VerseModel()
    @Published var snapshot: PlaybackSnapshot?
    @Published var lyrics: LyricDocument? { didSet { resetTranslation() } }
    @Published var progress: Double = 0
    @Published var activeIndex: Int?
    @Published var status = "等待 Spotify"
    @Published var lyricsStatus = "播放歌曲后自动查找歌词"
    @Published var lyricsAttempts: [LyricsAttempt] = []
    @Published var notice = ""
    @Published var isDemo = false
    @Published var loadingLyrics = false
    @Published private(set) var seeking = false
    @Published private(set) var seekStatus = ""
    func seek(to line: LyricLine) async {
        guard !seeking, let track = snapshot?.track, let document = lyrics else { return }
        do {
            let position = try PlaybackSeeking.position(for: line, document: document, duration: track.duration, adjustment: adjustment)
            if isDemo { demoSeek(position); seekStatus = "演示跳转"; return }
            seeking = true; seekStatus = "正在跳转…"; generation += 1
            defer { seeking = false; nextPoll = .distantPast }
            let confirmed: PlaybackSnapshot?
            #if os(macOS)
            confirmed = try await reader.seek(to: position, track: track)
            #else
            guard var credential = tokens else { throw VerseError.message("请先连接 Spotify") }
            if credential.expiresAt <= Date().addingTimeInterval(30) {
                credential = try await spotify.refresh(credential, clientID: clientID)
                try persist(credential)
            }
            try await spotify.seek(to: position, track: track, accessToken: credential.accessToken)
            confirmed = try await spotify.currentlyPlaying(accessToken: credential.accessToken)
            #endif
            guard snapshot?.track.id == track.id else { seekStatus = "歌曲已变化"; return }
            if let confirmed, confirmed.track.id == track.id {
                apply(confirmed)
                seekStatus = abs(confirmed.position - position) < 2.5 ?
                    String(format: "已跳转至 %d:%02d", Int(position) / 60, Int(position) % 60) : "指令已发送，等待 Spotify 确认进度"
            } else { seekStatus = "指令已发送，等待 Spotify 更新" }
        } catch {
            #if os(iOS)
            if case VerseError.http(403) = error { seekStatus = "请重新连接 Spotify 并允许控制播放进度；此接口需要 Premium"; return }
            #endif
            seekStatus = error.localizedDescription
        }
    }
    @Published var translationEnabled = UserDefaults.standard.bool(forKey: "translationEnabled") {
        didSet { UserDefaults.standard.set(translationEnabled, forKey: "translationEnabled"); translationPreferenceChanged() }
    }
    @Published var translationTarget = Locale.Language(identifier: UserDefaults.standard.string(forKey: "translationTarget") ?? "zh-Hans").minimalIdentifier {
        didSet { UserDefaults.standard.set(translationTarget, forKey: "translationTarget"); translationPreferenceChanged() }
    }
    @Published var translationSource = UserDefaults.standard.string(forKey: "translationSource") ?? "auto" {
        didSet { UserDefaults.standard.set(translationSource, forKey: "translationSource"); translationPreferenceChanged() }
    }
    @Published private(set) var translationRevision = UUID()
    @Published var translatedLines: [String: String] = [:]
    @Published var translationLanguages: [TranslationLanguage] = [.init(id: "zh-Hans", name: "简体中文")]
    @Published var translationStatus = "歌词翻译已关闭"
    var translationAvailable: Bool {
        if #available(macOS 15.0, iOS 18.0, *) { return true }
        return false
    }
    var currentTranslation: String { translatedLine(currentLine) }
    func translatedLine(_ original: String) -> String { translationEnabled ? translatedLines[original] ?? "" : "" }
    func retryTranslation() { resetTranslation() }
    private func translationPreferenceChanged() {
        resetTranslation()
        #if os(iOS)
        // A remote APNs update must never restore a translation the phone's user has switched off.
        if liveActivity.isRunning { liveActivity.stop() }
        #endif
    }
    private func resetTranslation() {
        translatedLines = [:]; translationRevision = UUID()
        translationStatus = !translationEnabled ? "歌词翻译已关闭" :
            (!translationAvailable ? "歌词翻译需要 macOS 15 或 iOS/iPadOS 18 及以上" : "等待翻译 · 首次使用请打开歌词窗口")
    }
    @Published var adjustment: Double = 0 { didSet { saveAdjustment(); tick() } }
    @Published var onlineLyrics = UserDefaults.standard.object(forKey: "onlineLyrics") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(onlineLyrics, forKey: "onlineLyrics")
            if onlineLyrics, preferSpotifyLyrics { SpotifyLyricsSession.shared.restoreIfNeeded() }
            lookupTask?.cancel()
            if let track = snapshot?.track { loadLyrics(track) }
        }
    }
    @Published var preferSpotifyLyrics = UserDefaults.standard.object(forKey: "preferSpotifyLyrics") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(preferSpotifyLyrics, forKey: "preferSpotifyLyrics")
            if preferSpotifyLyrics, onlineLyrics { SpotifyLyricsSession.shared.restoreIfNeeded() }
            if let track = snapshot?.track { loadLyrics(track, useCache: false) }
        }
    }
    @Published var lyricsProviderChoice = LyricsProviderChoice(rawValue: UserDefaults.standard.string(forKey: "lyricsProviderChoice") ?? "") ?? .automatic {
        didSet {
            UserDefaults.standard.set(lyricsProviderChoice.rawValue, forKey: "lyricsProviderChoice")
            if oldValue != lyricsProviderChoice, let track = snapshot?.track { loadLyrics(track, useCache: false) }
        }
    }
    @Published var clientID = UserDefaults.standard.string(forKey: "clientID") ?? ""
    @Published var redirectURI = UserDefaults.standard.string(forKey: "redirectURI") ?? ""
    @Published var relayURL = UserDefaults.standard.string(forKey: "relayURL") ?? ""
    @Published var relayEnabled = UserDefaults.standard.bool(forKey: "relayEnabled")
    @Published var relayKey = String(data: KeychainStore.read("relayKey") ?? Data(), encoding: .utf8) ?? ""
    @Published var relayStatus = "未连接推送桥"
    @Published var menuLength = UserDefaults.standard.integer(forKey: "menuLength") == 0 ? 18 : UserDefaults.standard.integer(forKey: "menuLength") {
        didSet { UserDefaults.standard.set(menuLength, forKey: "menuLength") }
    }
    @Published var menuScrolling = UserDefaults.standard.object(forKey: "menuScrolling") as? Bool ?? false {
        didSet { UserDefaults.standard.set(menuScrolling, forKey: "menuScrolling") }
    }
    @Published var interfaceMotionEnabled = UserDefaults.standard.object(forKey: "interfaceMotionEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(interfaceMotionEnabled, forKey: "interfaceMotionEnabled") }
    }
    @Published private(set) var menuText = "VerseDock"
    @Published private(set) var menuTranslation = ""
    @Published var overlayFont: Double = UserDefaults.standard.double(forKey: "overlayFont") == 0 ? 26 : UserDefaults.standard.double(forKey: "overlayFont")
    @Published var overlayVisible = UserDefaults.standard.bool(forKey: "overlayVisible")
    private let store = LyricStore()
    private let lyricsClient = LyricsClient()
    private var menuLine = ""
    private var menuLineStartedAt = Date()
    private let spotify = SpotifyAPI()
    private var tokens: SpotifyTokens?
    private var timer: Timer?
    private var polling = false
    private var generation = 0
    private var nextPoll = Date.distantPast
    private var lookupTask: Task<Void, Never>?
    private var relayTask: Task<Void, Never>?
    private var lastRelay: Date = .distantPast
    private var lastRelaySignature = ""
    private var refreshRetried = false
    private var foreground = true
    #if os(macOS)
    private let reader = SpotifyReader()
    #else
    let authentication = SpotifyAuthentication()
    let liveActivity = LiveActivityController()
    #endif

    var currentLine: String {
        if let activeIndex, let lyrics, lyrics.lines.indices.contains(activeIndex) {
            return lyrics.lines[activeIndex].text.isEmpty ? "♪" : lyrics.lines[activeIndex].text
        }
        if lyrics?.instrumental == true { return "纯音乐 · Instrumental" }
        if let lyrics, !lyrics.lines.isEmpty { return "前奏 ♪" }
        return snapshot?.track.title ?? "VerseDock"
    }
    var nextLine: String {
        guard let lyrics, !lyrics.lines.isEmpty else { return "" }
        let index = (activeIndex ?? -1) + 1
        return lyrics.lines.indices.contains(index) ? lyrics.lines[index].text : ""
    }
    var menuTitle: String {
        menuText
    }
    func start() {
        guard timer == nil else { return }
        SpotifyLyricsSession.shared.onReady = { [weak self] in
            guard let self, self.onlineLyrics, self.preferSpotifyLyrics else { return }
            self.retryLyrics()
        }
        if onlineLyrics, preferSpotifyLyrics { SpotifyLyricsSession.shared.restoreIfNeeded() }
        #if os(macOS)
        if overlayVisible { OverlayController.shared.setVisible(true, model: self) }
        #endif
        if let data = KeychainStore.read("spotifyTokens") { tokens = try? JSONDecoder().decode(SpotifyTokens.self, from: data) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.foreground else { return }
                self.tick()
                if !self.isDemo, !self.polling, Date() >= self.nextPoll { await self.poll() }
            }
        }
    }
    func setForeground(_ value: Bool) {
        foreground = value
        if value { nextPoll = .distantPast }
        #if os(iOS)
        if !value { liveActivity.markBackground() }
        #endif
    }
    private func tick() {
        let nextProgress = snapshot?.progress(at: Date()) ?? 0
        if progress != nextProgress { progress = nextProgress }
        let index = lyrics?.activeIndex(at: progress, adjustment: adjustment)
        if index != activeIndex { activeIndex = index }
        let line = currentLine
        if line != menuLine { menuLine = line; menuLineStartedAt = Date() }
        let title = LyricMarquee.text(line, width: menuLength,
            elapsed: Date().timeIntervalSince(menuLineStartedAt), enabled: menuScrolling)
        if title != menuText { menuText = title }
        let translatedTitle = LyricMarquee.text(currentTranslation, width: menuLength,
            elapsed: Date().timeIntervalSince(menuLineStartedAt), enabled: menuScrolling)
        if translatedTitle != menuTranslation { menuTranslation = translatedTitle }
        #if os(iOS)
        liveActivity.update(state: relayState())
        #else
        pushRelayIfNeeded()
        #endif
    }
    func relayState() -> RelayState {
        RelayState(title: snapshot?.track.title ?? "等待 Spotify", artist: snapshot?.track.artist ?? "",
            line: currentLine, nextLine: nextLine, isPlaying: snapshot?.isPlaying ?? false,
            source: isDemo ? "原创演示" : (lyrics?.source ?? "暂无歌词"), updatedAt: Date().timeIntervalSince1970,
            position: progress, duration: snapshot?.track.duration ?? 0,
            translation: currentTranslation.isEmpty ? nil : currentTranslation,
            translationLanguage: translationEnabled ? translationTarget : nil)
    }
    private func poll() async {
        polling = true
        defer { polling = false }
        #if os(macOS)
        nextPoll = Date().addingTimeInterval(1)
        #else
        nextPoll = Date().addingTimeInterval(3)
        #endif
        let requestGeneration = generation
        do {
            let value: PlaybackSnapshot?
            #if os(macOS)
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty else {
                apply(nil); status = "请先打开 Spotify 桌面 App"; return
            }
            value = try await reader.snapshot()
            #else
            guard var credential = tokens else { status = "请在设置里连接 Spotify"; return }
            if credential.expiresAt <= Date().addingTimeInterval(30) {
                credential = try await spotify.refresh(credential, clientID: clientID)
                guard generation == requestGeneration, foreground, !isDemo else { return }
                try persist(credential)
            }
            value = try await spotify.currentlyPlaying(accessToken: credential.accessToken)
            #endif
            guard generation == requestGeneration, foreground, !isDemo else { return }
            refreshRetried = false
            apply(value)
            status = value == nil ? "暂无歌曲，广告或播客不提供歌词" : (value!.isPlaying ? "Spotify · 正在播放" : "Spotify · 已暂停")
        } catch {
            guard generation == requestGeneration else { return }
            // Freeze interpolation after a failed observation; never keep an unconfirmed song moving forever.
            if let old = snapshot {
                snapshot = PlaybackSnapshot(track: old.track, position: old.progress(at: Date()), isPlaying: false)
            }
            status = error.localizedDescription
            if case VerseError.rateLimited(let seconds) = error { nextPoll = Date().addingTimeInterval(seconds) }
            else { nextPoll = Date().addingTimeInterval(8) }
            #if os(iOS)
            if case VerseError.http(401) = error {
                if !refreshRetried, let credential = tokens {
                    refreshRetried = true
                    tokens = SpotifyTokens(accessToken: credential.accessToken, refreshToken: credential.refreshToken, expiresAt: .distantPast)
                    nextPoll = .distantPast
                } else { disconnect(); status = "Spotify 授权已失效，请重新连接" }
            }
            if case VerseError.http(403) = error { status = "Spotify 拒绝访问，请检查 Premium、应用用户白名单和开发者权限" }
            #endif
        }
    }
    private func apply(_ value: PlaybackSnapshot?) {
        let changed = value?.track.id != snapshot?.track.id
        snapshot = value
        if changed {
            seekStatus = ""
            lookupTask?.cancel(); lyrics = nil; activeIndex = nil; loadingLyrics = false
            if let track = value?.track {
                adjustment = UserDefaults.standard.double(forKey: "offset.\(track.id)")
                loadLyrics(track)
            } else { lyricsStatus = "等待下一首歌曲" }
        }
        tick()
    }
    private func loadLyrics(_ track: Track, useCache: Bool = true) {
        lookupTask?.cancel()
        lyrics = nil; activeIndex = nil; loadingLyrics = true; lyricsAttempts = []; lyricsStatus = "正在查找歌词"
        lookupTask = Task {
            if useCache, let cached = await store.load(track.id), !Task.isCancelled, snapshot?.track.id == track.id,
               cached.source == "本地 LRC" || lyricsProviderChoice.providers.map(\.name).contains(cached.source) || (preferSpotifyLyrics && cached.source == "Spotify") {
                lyrics = cached; lyricsStatus = describe(cached, cached: true); tick()
                // Imported files remain authoritative; plain online caches may be upgraded to synchronized lyrics.
                if !onlineLyrics || cached.source == "本地 LRC" || (!preferSpotifyLyrics && (!cached.lines.isEmpty || cached.instrumental)) {
                    loadingLyrics = false; return
                }
            }
            guard !Task.isCancelled else { return }
            guard onlineLyrics else {
                loadingLyrics = false; lyricsStatus = "请导入这首歌的 LRC，或在设置中开启在线歌词"; return
            }
            do {
                let primary: (@Sendable (Track) async throws -> LyricDocument?)?
                if preferSpotifyLyrics {
                    primary = { @Sendable track in try await SpotifyLyricsSession.shared.lyrics(for: track) }
                } else { primary = nil }
                let result = try await lyricsClient.lookup(for: track, providers: lyricsProviderChoice.providers, spotify: primary) { [self] message in
                    await self.lookupProgress(message, trackID: track.id)
                }
                guard !Task.isCancelled, snapshot?.track.id == track.id else { return }
                lyricsAttempts = result.attempts; loadingLyrics = false
                if let value = result.document {
                    lyrics = value; lyricsStatus = describe(value)
                    do { try await store.save(value, id: track.id) }
                    catch { notice = "歌词已显示，缓存写入失败：\(error.localizedDescription)" }
                } else if let lyrics { lyricsStatus = describe(lyrics, cached: true) + " · 暂无新的同步歌词" }
                else {
                    let failed = result.attempts.contains { $0.outcome == "unavailable" }
                    if lyricsProviderChoice == .automatic {
                        lyricsStatus = failed ? "已尝试多个来源，部分服务暂不可用；可重试或导入 LRC" : "多个来源均未找到匹配歌词，可重试或导入 LRC"
                    } else {
                        lyricsStatus = "\(lyricsProviderChoice.name)" + (failed ? " 暂不可用" : " 未找到匹配歌词") + "；可重试或改选自动"
                    }
                }
                tick()
            } catch {
                guard !Task.isCancelled, snapshot?.track.id == track.id else { return }
                loadingLyrics = false; lyricsStatus = "歌词读取失败：\(error.localizedDescription)"
            }
        }
    }
    private func lookupProgress(_ message: String, trackID: String) {
        guard !Task.isCancelled, snapshot?.track.id == trackID else { return }
        lyricsStatus = message
    }
    private func describe(_ value: LyricDocument, cached: Bool = false) -> String {
        "来源：\(value.source)" + (cached ? " · 本地缓存" : "") +
            (value.lines.isEmpty && !value.instrumental ? " · 纯文本，无同步时间轴" : "") +
            (value.matchNote.map { " · " + $0 } ?? "")
    }
    func retryLyrics() { if let track = snapshot?.track { loadLyrics(track, useCache: false) } }
    func importLyrics(_ url: URL) {
        guard let track = snapshot?.track else { notice = "请先播放歌曲，导入文件会绑定当前歌曲"; return }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 2_000_000, let text = String(data: data, encoding: .utf8) else {
                throw VerseError.message("请使用小于 2 MB 的 UTF-8 LRC 或文本文件")
            }
            let document = LRCParser.parse(text)
            guard !document.lines.isEmpty || !document.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw VerseError.message("文件中没有可显示的歌词") }
            lookupTask?.cancel(); lyrics = document; loadingLyrics = false; lyricsAttempts = []; lyricsStatus = "来源：本地导入"
            Task { do { try await store.save(document, id: track.id) } catch { notice = error.localizedDescription } }
            tick()
        } catch { notice = error.localizedDescription }
    }
    func demo() {
        generation += 1; lookupTask?.cancel(); isDemo = true; loadingLyrics = false; lyricsAttempts = []
        let track = Track(id: "demo-original", title: "在此刻，听见", artist: "VerseDock 原创示例", album: "交互演示", duration: 36)
        snapshot = PlaybackSnapshot(track: track, position: 0, isPlaying: true)
        lyrics = LRCParser.parse("""
        [00:00.00]把城市的声音调低
        [00:05.00]留一行光，陪着你
        [00:10.00]风从窗外慢慢经过
        [00:15.00]每个字，都落在此刻
        [00:20.00]不必赶路，不必着急
        [00:25.00]让旋律把夜色拾起
        [00:30.00]下一首歌，我们再相遇
        [00:35.00]
        """, source: "VerseDock 原创演示")
        adjustment = 0; status = "演示模式 · 未连接真实播放"; lyricsStatus = "原创测试歌词"; tick()
    }
    func endDemo() { generation += 1; isDemo = false; apply(nil); nextPoll = .distantPast }
    func demoSeek(_ position: Double) {
        guard isDemo, let old = snapshot else { return }
        snapshot = PlaybackSnapshot(track: old.track, position: position, isPlaying: old.isPlaying); tick()
    }
    func saveSettings() {
        UserDefaults.standard.set(clientID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "clientID")
        UserDefaults.standard.set(redirectURI, forKey: "redirectURI")
        UserDefaults.standard.set(relayURL, forKey: "relayURL")
        UserDefaults.standard.set(relayEnabled, forKey: "relayEnabled")
        UserDefaults.standard.set(menuLength, forKey: "menuLength")
        UserDefaults.standard.set(menuScrolling, forKey: "menuScrolling")
        UserDefaults.standard.set(overlayFont, forKey: "overlayFont")
        if !relayKey.isEmpty {
            do { try KeychainStore.write(Data(relayKey.utf8), account: "relayKey") }
            catch { notice = "配对密钥保存失败：\(error.localizedDescription)" }
        }
    }
    private func saveAdjustment() {
        if let id = snapshot?.track.id { UserDefaults.standard.set(adjustment, forKey: "offset.\(id)") }
    }
    func clearLyrics() {
        lookupTask?.cancel(); loadingLyrics = false; lyricsAttempts = []
        Task {
            do { try await store.clear(); lyrics = nil; activeIndex = nil; lyricsStatus = "本地歌词缓存已清除" }
            catch { notice = error.localizedDescription }
        }
    }
    #if os(macOS)
    func toggleOverlay() {
        overlayVisible.toggle(); UserDefaults.standard.set(overlayVisible, forKey: "overlayVisible")
        OverlayController.shared.setVisible(overlayVisible, model: self)
    }
    private func pushRelayIfNeeded() {
        guard relayEnabled, relayTask == nil, !isDemo, Date().timeIntervalSince(lastRelay) >= 5 else { return }
        let state = relayState()
        let signature = "\(state.title)|\(state.line)|\(state.translation ?? "")|\(state.translationLanguage ?? "")|\(state.isPlaying)"
        guard signature != lastRelaySignature || Date().timeIntervalSince(lastRelay) >= 20 else { return }
        lastRelay = Date()
        let base = relayURL, key = relayKey
        relayTask = Task {
            defer { relayTask = nil }
            do {
                try await RelayClient.send(state, path: "update", base: base, key: key)
                lastRelaySignature = signature; relayStatus = "歌词已发送 · \(Date().formatted(date: .omitted, time: .standard))"
            } catch { relayStatus = "推送失败：\(error.localizedDescription)" }
        }
    }
    #else
    func connect() async {
        do {
            saveSettings()
            guard let redirect = URL(string: redirectURI) else { throw VerseError.message("请填写 HTTPS 回调地址") }
            let credential = try await authentication.connect(clientID: clientID, redirect: redirect)
            generation += 1; try persist(credential); isDemo = false; apply(nil); nextPoll = .distantPast
            status = "已连接，正在读取 Spotify"
        } catch { notice = error.localizedDescription }
    }
    func disconnect() {
        generation += 1; tokens = nil; KeychainStore.remove("spotifyTokens"); apply(nil)
        status = "已断开 Spotify"; liveActivity.stop()
    }
    private func persist(_ value: SpotifyTokens) throws {
        try KeychainStore.write(JSONEncoder().encode(value), account: "spotifyTokens"); tokens = value
    }
    func toggleActivity() {
        if liveActivity.isRunning { liveActivity.stop() }
        else {
            saveSettings()
            do { try liveActivity.start(state: relayState(), relayURL: relayEnabled ? relayURL : "", relayKey: relayKey) }
            catch { notice = error.localizedDescription }
        }
    }
    #endif
}
