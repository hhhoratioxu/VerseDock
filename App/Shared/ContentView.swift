import SwiftUI
import UniformTypeIdentifiers
import VerseCore
#if os(macOS)
import AppKit
#endif

enum VerseTheme {
    static let ink = Color(red: 0.065, green: 0.068, blue: 0.064)
    static let accent = Color.white
}

struct ContentView: View {
    @ObservedObject var model: VerseModel
    @ObservedObject private var albumAppearance: VerseAlbumAppearance
    @State private var settings = false
    @State private var importing = false
    @State private var follow = true
    @State private var sourceDetails = false
    @State private var calibration = false
    @State private var appeared = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    #endif
    private var motion: Bool { model.interfaceMotionEnabled && !reduceMotion }
    init(model: VerseModel) {
        self.model = model
        self.albumAppearance = model.albumAppearance
    }
    private var brandMark: Image {
        #if os(macOS)
        if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return Image(nsImage: image) }
        return Image(systemName: "music.note")
        #else
        return Image("BrandMark")
        #endif
    }
    var body: some View {
        #if os(macOS)
        listeningView
        #else
        NavigationStack {
            listeningView.navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        #endif
    }
    private var listeningView: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 760 && geometry.size.height >= 540
            let coverSize = min(260.0, max(210.0, min(1100, geometry.size.width) * 0.29))
            VStack(spacing: 0) {
                if wide {
                    HStack(spacing: 52) {
                        albumPanel(size: coverSize).frame(width: coverSize)
                        lyricsBody(wide: true)
                    }.padding(.horizontal, 40).padding(.top, 26)
                } else {
                    trackHeader.padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 20)
                    lyricsBody(wide: false)
                }
                footer.padding(.horizontal, wide ? 38 : 28).padding(.top, 14).padding(.bottom, 20)
            }
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            VerseListeningBackground(palette: albumAppearance.palette, strength: model.albumBackgroundStrength,
                enabled: model.albumBackgroundEnabled, flowing: model.albumFlowEnabled).ignoresSafeArea()
        }
        .foregroundStyle(.white)
        .tint(VerseTheme.accent)
        .preferredColorScheme(.dark)
        .environment(\.verseMotionEnabled, model.interfaceMotionEnabled)
        .environment(\.verseGlassStrength, model.glassStrength)
        .environment(\.verseGlassColor, model.albumBackgroundEnabled ? albumAppearance.palette.tint : VerseAlbumPalette.neutral.tint)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || !motion ? 0 : 5)
        .modifier(LyricTranslationHost(model: model))
        .navigationTitle("VerseDock")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                moreMenu
                Button { showSettings(.appearance) } label: { Label("设置", systemImage: "gearshape") }
                    .help("设置").accessibilityLabel("设置")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $settings) { SettingsView(model: model) }
        #endif
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, UTType(filenameExtension: "lrc") ?? .data]) { result in
            switch result {
            case .success(let url): model.importLyrics(url)
            case .failure(let error): model.notice = error.localizedDescription
            }
        }
        .alert("VerseDock", isPresented: Binding(get: { !model.notice.isEmpty }, set: { if !$0 { model.notice = "" } })) {
            Button("知道了", role: .cancel) { model.notice = "" }
        } message: { Text(model.notice) }
        .task { model.start() }
        .onAppear {
            #if os(macOS)
            model.presentMainWindow = { openWindow(id: "main") }
            #endif
            withAnimation(motion ? .easeOut(duration: 0.35) : nil) { appeared = true }
        }
        .onChange(of: model.snapshot?.track.id) { _, _ in follow = true }
        #if os(iOS)
        .onChange(of: phase) { _, value in model.setForeground(value == .active) }
        #endif
    }
    private func showSettings(_ section: VerseSettingsSection) {
        model.settingsSection = section
        #if os(macOS)
        openSettings()
        #else
        settings = true
        #endif
    }
    private var moreMenu: some View {
        Menu {
            Button("重新查找歌词", systemImage: "arrow.clockwise") { model.retryLyrics() }
                .disabled(model.snapshot == nil || model.loadingLyrics)
            Button("导入 LRC 歌词", systemImage: "square.and.arrow.down") { importing = true }
            Divider()
            if !model.isDemo { Button("试用原创演示", systemImage: "play.circle") { model.demo() } }
        } label: { Label("更多操作", systemImage: "ellipsis") }
        .help("重新查找或导入歌词").accessibilityLabel("更多操作")
    }
    private var trackHeader: some View {
        HStack(spacing: 18) {
            VerseArtwork(url: model.snapshot?.track.artworkURL, size: 88, fallback: brandMark)
                .id(model.snapshot?.track.artworkURL).transition(.opacity)
            VStack(alignment: .leading, spacing: 6) {
                trackTitle(size: 23)
                Text(model.snapshot?.track.artist ?? "在 Spotify 播放歌曲")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.52)).lineLimit(1)
                playbackStatus.padding(.top, 3)
            }
            Spacer(minLength: 0)
        }.animation(motion ? .easeInOut(duration: 0.35) : nil, value: model.snapshot?.track.id)
    }
    private func albumPanel(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            VerseArtwork(url: model.snapshot?.track.artworkURL, size: size, fallback: brandMark)
                .id(model.snapshot?.track.artworkURL).transition(.opacity)
            VStack(alignment: .leading, spacing: 9) {
                trackTitle(size: 29)
                Text(model.snapshot?.track.artist ?? "在 Spotify 播放歌曲")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.58)).lineLimit(2)
                if let album = model.snapshot?.track.album, !album.isEmpty {
                    Text(album).font(.system(size: 11)).foregroundStyle(.white.opacity(0.32)).lineLimit(1)
                }
                playbackStatus.padding(.top, 7)
            }
            Spacer(minLength: 0)
        }
        .animation(motion ? .easeInOut(duration: 0.35) : nil, value: model.snapshot?.track.id)
    }
    private func trackTitle(size: CGFloat) -> some View {
        Text(model.snapshot?.track.title ?? "开始听歌")
            .font(.system(size: size, weight: .semibold)).tracking(-0.65).lineLimit(2)
            .fixedSize(horizontal: false, vertical: true).contentTransition(.opacity)
    }
    private var playbackStatus: some View {
        HStack(spacing: 7) {
            VersePlaybackIndicator(playing: model.snapshot?.isPlaying == true)
            Text(model.isDemo ? "原创演示" : model.status)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4)).lineLimit(2)
        }
    }
    private var lyricsHeader: some View {
        HStack {
            Text("歌词").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Button { follow.toggle() } label: {
                Label(follow ? "跟随中" : "自由浏览", systemImage: follow ? "location.fill" : "hand.draw")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(follow ? VerseTheme.accent.opacity(0.8) : .white.opacity(0.5))
            }.buttonStyle(VerseQuietStyle()).accessibilityIdentifier("lyrics-follow")
        }.padding(.leading, 3).padding(.trailing, 1)
    }
    @ViewBuilder private func lyricsBody(wide: Bool) -> some View {
        if let document = model.lyrics, !document.lines.isEmpty {
            VStack(spacing: 2) {
            lyricsHeader.padding(.horizontal, wide ? 0 : 28)
            GeometryReader { geometry in
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(document.lines) { line in
                                VerseLyricRow(text: line.text, translation: model.translatedLine(line.text),
                                    active: model.activeIndex == line.id,
                                    nearby: abs(line.id - (model.activeIndex ?? -2)) <= 1,
                                    fontSize: wide ? 30 : 28, timestamp: time(max(0, line.time - model.adjustment))) {
                                        follow = true
                                        Task { await model.seek(to: line) }
                                    }
                                    .disabled(model.seeking)
                                    .id(line.id)
                                    .help("点击跳转到 " + time(max(0, line.time - model.adjustment)))
                                    .accessibilityLabel("跳转到 " + time(max(0, line.time - model.adjustment)) + "：" + line.text)
                                    .accessibilityIdentifier("lyric-seek-\(line.id)")
                            }
                        }
                        .padding(.horizontal, wide ? 4 : 30)
                        .padding(.vertical, max(65, geometry.size.height * 0.36))
                    }
                    .scrollIndicators(.hidden)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08), .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    .onChange(of: model.activeIndex) { _, value in
                        guard follow, let value else { return }
                        withAnimation(motion ? .spring(duration: 0.65, bounce: 0) : nil) { reader.scrollTo(value, anchor: .center) }
                    }
                    .onChange(of: follow) { _, value in
                        if value, let index = model.activeIndex {
                            withAnimation(motion ? .spring(duration: 0.5, bounce: 0) : nil) { reader.scrollTo(index, anchor: .center) }
                        }
                    }
                    .onChange(of: model.translatedLines.count) { _, _ in
                        guard follow, let value = model.activeIndex else { return }
                        withAnimation(motion ? .easeInOut(duration: 0.35) : nil) { reader.scrollTo(value, anchor: .center) }
                    }
                    .onChange(of: geometry.size) { _, _ in
                        if follow, let value = model.activeIndex { reader.scrollTo(value, anchor: .center) }
                    }
                    .onAppear { if let value = model.activeIndex { reader.scrollTo(value, anchor: .center) } }
                }
            }
            }
        } else if let document = model.lyrics, !document.plainText.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("纯文本 · 没有同步时间").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    ForEach(Array(document.plainText.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, text in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(text).font(.system(size: 25, weight: .medium)).textSelection(.enabled)
                            if !model.translatedLine(text).isEmpty {
                                Text(model.translatedLine(text)).font(.system(size: 16)).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(32)
            }
        } else {
            VStack(spacing: 15) {
                Image(systemName: model.lyrics?.instrumental == true ? "pianokeys" : "music.note")
                    .font(.system(size: 34, weight: .ultraLight)).foregroundStyle(.white.opacity(0.25))
                Text(model.lyrics?.instrumental == true ? "纯音乐" : (model.loadingLyrics ? "正在找歌词" : "还没有歌词"))
                    .font(.system(size: 19, weight: .medium))
                Text(model.lyricsStatus).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center).lineSpacing(4)
                if model.loadingLyrics { ProgressView().controlSize(.small) }
                HStack(spacing: 8) {
                    Button("试用演示") { model.demo() }
                    if model.snapshot != nil { Button("重新查找") { model.retryLyrics() } }
                    else {
                        Button("打开设置") {
                            #if os(iOS)
                            showSettings(.connection)
                            #else
                            showSettings(.lyrics)
                            #endif
                        }
                    }
                }.buttonStyle(VerseControlStyle()).padding(.top, 5)
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var footer: some View {
        VStack(spacing: 13) {
            if !model.seekStatus.isEmpty {
                HStack {
                    Text(model.seekStatus).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    if model.seeking { ProgressView().controlSize(.mini) }
                }.transition(.opacity)
            }
            if let snapshot = model.snapshot {
                HStack(spacing: 11) {
                    Text(time(model.progress)).frame(minWidth: 29, alignment: .leading)
                    ProgressView(value: model.progress, total: max(1, snapshot.track.duration))
                        .progressViewStyle(VersePlaybackRail()).accessibilityLabel("播放进度")
                    Text(time(snapshot.track.duration)).frame(minWidth: 29, alignment: .trailing)
                }.font(.system(size: 10).monospacedDigit()).foregroundStyle(.white.opacity(0.38))
            }
            HStack(spacing: 6) {
                Button { sourceDetails.toggle() } label: {
                    HStack(spacing: 7) {
                        if model.loadingLyrics { ProgressView().controlSize(.mini) }
                        else { Circle().fill(VerseTheme.accent.opacity(0.7)).frame(width: 4, height: 4) }
                        Text(model.lyrics.map { $0.source == "Spotify" ? "Spotify 原词" : $0.source } ?? "歌词来源")
                            .font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }.foregroundStyle(.white.opacity(0.72))
                }
                .help(model.lyricsStatus).accessibilityLabel("歌词来源与状态")
                .popover(isPresented: $sourceDetails) { sourcePopover.presentationCompactAdaptation(.popover) }
                Spacer(minLength: 12)
                HStack(spacing: 0) {
                    Button { calibration.toggle() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "timer")
                            if abs(model.adjustment) >= 0.05 { Text(String(format: "%+.1fs", model.adjustment)).monospacedDigit() }
                        }.foregroundStyle(.white.opacity(0.65))
                    }
                    .help("歌词时间校准").accessibilityLabel("歌词时间校准")
                    .popover(isPresented: $calibration) { calibrationPopover.presentationCompactAdaptation(.popover) }
                    #if os(macOS)
                    Rectangle().fill(.white.opacity(0.08)).frame(width: 0.5, height: 14)
                    Button { model.toggleOverlay() } label: {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(model.overlayVisible ? VerseTheme.accent : .white.opacity(0.65))
                    }
                        .help(model.overlayVisible ? "隐藏悬浮歌词" : "显示悬浮歌词")
                        .accessibilityLabel(model.overlayVisible ? "隐藏悬浮歌词" : "悬浮歌词")
                    #else
                    ActivityButton(model: model, controller: model.liveActivity)
                    #endif
                }
                .padding(3)
                .modifier(VerseGlassSurface(cornerRadius: 18))
            }
            .buttonStyle(VerseQuietStyle())
            if model.isDemo {
                HStack {
                    Text("演示 · 原创歌词").foregroundStyle(.white.opacity(0.3))
                    Spacer()
                    Button("重播") { model.demo() }.accessibilityLabel("重新播放原创演示")
                    Button("回到 Spotify") { model.endDemo() }
                }.font(.system(size: 10)).buttonStyle(VerseQuietStyle())
            }
        }
    }
    private var sourcePopover: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(model.lyrics?.source == "Spotify" ? "Spotify 原词" : "歌词来源").font(.headline)
            Text(model.lyricsStatus).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.translationEnabled {
                Text(model.translationStatus).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let link = model.lyrics?.sourceURL { Link("查看来源 ↗", destination: link) }
                if let link = model.snapshot?.track.spotifyURL { Link("在 Spotify 打开 ↗", destination: link) }
            }.font(.system(size: 11))
            Divider()
            Button("设置歌词来源与翻译") { sourceDetails = false; showSettings(.lyrics) }.font(.system(size: 12))
            if !model.isDemo { Button("试用原创演示") { sourceDetails = false; model.demo() }.font(.system(size: 11)) }
        }
        .padding(20).frame(width: 310, alignment: .leading)
        .preferredColorScheme(.dark)
    }
    private var calibrationPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("歌词时间校准").font(.headline)
            Text("只影响当前这首歌。正值提前，负值延后。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button { model.adjustment = max(-10, model.adjustment - 0.2) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("歌词延后 0.2 秒")
                Spacer()
                Button { model.adjustment = 0 } label: { Text(String(format: "%+.1f 秒", model.adjustment)).monospacedDigit() }
                    .help("点击恢复零偏移")
                Spacer()
                Button { model.adjustment = min(10, model.adjustment + 0.2) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("歌词提前 0.2 秒")
            }.buttonStyle(VerseControlStyle())
        }.padding(20).frame(width: 280).preferredColorScheme(.dark)
    }
    private func time(_ value: Double) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}

enum VerseSettingsSection: String, CaseIterable {
    case appearance = "外观", lyrics = "歌词", translation = "翻译", connection = "连接"
    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .lyrics: "quote.bubble"
        case .translation: "character.bubble"
        case .connection: "antenna.radiowaves.left.and.right"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: VerseModel
    @ObservedObject private var spotifyLyrics = SpotifyLyricsSession.shared
    @State private var connectingLyrics = false
    @State private var path: [VerseSettingsSection]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    init(model: VerseModel) {
        self.model = model
        self._path = State(initialValue: [model.settingsSection])
    }
    var body: some View {
        Group {
            #if os(macOS)
            TabView(selection: $model.settingsSection) {
                ForEach(VerseSettingsSection.allCases, id: \.self) { section in
                    settingsForm(section)
                        .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                        .tag(section)
                }
            }
            .frame(width: 620, height: 680)
            .onDisappear { model.saveSettings() }
            #else
            NavigationStack(path: $path) {
                List(VerseSettingsSection.allCases, id: \.self) { section in
                    NavigationLink(value: section) { Label(section.rawValue, systemImage: section.symbol) }
                }
                .navigationTitle("设置")
                .navigationDestination(for: VerseSettingsSection.self) { settingsForm($0).navigationTitle($0.rawValue) }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { model.saveSettings(); dismiss() }.accessibilityLabel("保存设置")
                    }
                }
            }
            #endif
        }
        .preferredColorScheme(nil)
        #if os(iOS)
        .tint(.blue)
        #endif
        .sheet(isPresented: $connectingLyrics) { SpotifyLyricsConnectionView() }
    }
    private func settingsForm(_ category: VerseSettingsSection) -> some View {
            Form {
                if category == .appearance {
                Section("外观与交互") {
                    if reduceTransparency {
                        Text("系统已减少透明度，当前使用实色界面。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if #available(macOS 26.0, iOS 26.0, *) {
                        Text("Liquid Glass · 系统原生玻璃材质")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("当前系统使用磨砂材质，升级至 macOS / iOS 26 后启用 Liquid Glass。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VerseAppearancePreview(model: model, appearance: model.albumAppearance)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("Liquid Glass 强度")
                            Spacer()
                            Text(model.glassStrength.formatted(.percent.precision(.fractionLength(0))))
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                        Slider(value: $model.glassStrength, in: 0...1) { Text("Liquid Glass 强度") }.labelsHidden()
                            .accessibilityIdentifier("glass-strength")
                        HStack { Text("最通透"); Spacer(); Text("色调最浓") }
                            .font(.caption).foregroundStyle(.secondary)
                    }.disabled(reduceTransparency)
                    Toggle("专辑封面背景", isOn: $model.albumBackgroundEnabled)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("背景色彩浓度")
                            Spacer()
                            Text(model.albumBackgroundStrength.formatted(.percent.precision(.fractionLength(0))))
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                        Slider(value: $model.albumBackgroundStrength, in: 0...1) { Text("背景色彩浓度") }.labelsHidden()
                            .accessibilityIdentifier("album-background-strength")
                        HStack { Text("淡"); Spacer(); Text("浓") }.font(.caption).foregroundStyle(.secondary)
                    }.disabled(!model.albumBackgroundEnabled || reduceTransparency)
                    Toggle("背景柔和流动", isOn: $model.albumFlowEnabled)
                        .disabled(!model.albumBackgroundEnabled || !model.interfaceMotionEnabled || reduceMotion || reduceTransparency)
                    Toggle("界面动效", isOn: $model.interfaceMotionEnabled)
                    Text("拖动即生效，重启后保留。玻璃色调与封面背景分别调整，动效遵循系统辅助功能设置。")
                        .font(.caption).foregroundStyle(.secondary)
                    if reduceMotion {
                        Text("系统已开启“减少动态效果”，界面保持静态。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                }
                if category == .lyrics {
                Section("歌词来源") {
                    Toggle("自动查找在线歌词与备用来源", isOn: $model.onlineLyrics)
                    Toggle("优先使用 Spotify 原词", isOn: $model.preferSpotifyLyrics).disabled(!model.onlineLyrics)
                    Button("连接 / 查看 Spotify 原词会话") {
                        #if os(macOS)
                        DispatchQueue.main.async { SpotifyLyricsWindowController.shared.show() }
                        #else
                        connectingLyrics = true
                        #endif
                    }
                    Text(spotifyLyrics.status).font(.caption).foregroundStyle(.secondary)
                    Picker("备用歌词来源", selection: $model.lyricsProviderChoice) {
                        ForEach(LyricsProviderChoice.allCases, id: \.rawValue) { choice in
                            Text(choice.name).tag(choice)
                        }
                    }
                    .disabled(!model.onlineLyrics)
                    Text("Spotify 原词优先，无词或暂时不可用时使用备用。手动指定后只访问该备用来源，选择自动保存。")
                        .font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("连接与来源说明") {
                    Text("Spotify 原词通过独立的 Spotify 网页登录会话读取，需要在上方入口自行登录。网页接口不是公开开发者 API，可能失效；授权失败会明确显示，不会误报为歌曲无词。备用自动顺序为 LRCLIB、QQ 音乐、网易云、lyrics.ovh。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("YouTube Music、Apple Music 暂无已接通的歌词读取方式。备用来源仅接收歌曲信息，不接收 Spotify 授权；歌词缓存在本机，也可导入自己的 UTF-8 LRC。")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.lyricsAttempts.enumerated()), id: \.offset) { _, attempt in
                        Text("\(attempt.provider.name)：\(attempt.message)").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("重新查找当前歌曲") { model.retryLyrics() }.disabled(model.loadingLyrics || model.snapshot == nil)
                    Button("清除本地歌词缓存") { model.clearLyrics() }
                }
                }
                if category == .translation {
                Section("歌词翻译") {
                    Toggle("开启歌词翻译", isOn: $model.translationEnabled).disabled(!model.translationAvailable)
                    Picker("翻译为", selection: $model.translationTarget) {
                        ForEach(model.translationLanguages) { language in Text(language.name).tag(language.id) }
                    }.disabled(!model.translationEnabled)
                    Picker("原词语言", selection: $model.translationSource) {
                        Text("自动识别").tag("auto")
                        ForEach(model.translationLanguages) { language in Text(language.name).tag(language.id) }
                    }.disabled(!model.translationEnabled)
                    Text("默认关闭。开启后原词在上、译文在下；支持的主流语言由本机系统提供。使用 Apple 系统翻译，首次可能需要按提示下载语言包。需要 macOS 15 或 iOS/iPadOS 18 及以上。机器译文仅供参考。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.translationStatus).font(.caption).foregroundStyle(.secondary)
                    #if os(iOS)
                    Text("更改翻译偏好会结束当前实时活动，请重新开启。后台译文来自 Mac 推送桥，两端目标语言需一致；手机未开启翻译时不接收译文。")
                        .font(.caption).foregroundStyle(.secondary)
                    #endif
                    Button("重试翻译") { model.retryTranslation() }.disabled(!model.translationEnabled || model.lyrics == nil)
                }
                }
                #if os(macOS)
                if category == .appearance {
                Section("Mac 显示") {
                    Stepper("状态栏最多 \(model.menuLength) 个字符", value: $model.menuLength, in: 8...40)
                    Toggle("状态栏歌词滚动", isOn: $model.menuScrolling)
                    Slider(value: $model.overlayFont, in: 18...48, step: 1) { Text("悬浮字号") }
                    Text("顶部状态栏直接显示当前歌词。显示长度与滚动开关独立设置并自动保存，默认静态；开启滚动后，放不下的长句从头滚动。悬浮字号：\(Int(model.overlayFont))，拖动歌词或空白处可移动，右键可隐藏。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                }
                #else
                if category == .connection {
                Section("Spotify 连接") {
                    TextField("Spotify Client ID", text: $model.clientID).autocorrectionDisabled().textInputAutocapitalization(.never)
                    TextField("HTTPS 回调地址", text: $model.redirectURI).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    Text("将工程里的 web 回调页部署到你自己的 HTTPS 地址，并在 Spotify Dashboard 登记完全相同的地址。授权包含读取当前歌曲和控制播放进度；旧授权需要重新连接才能点击歌词跳转，进度控制需要 Premium。不需要 Client Secret。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("连接 Spotify") { Task { await model.connect() } }
                    Button("断开并删除本机授权", role: .destructive) { model.disconnect() }
                }
                Section("灵动岛与锁屏") {
                    Text("支持的 iPhone 显示灵动岛，iPad 显示锁屏实时活动（需要支持的系统）。前台按歌词更新；后台需要下面的 Mac 推送桥。系统会限制推送频率，无法保证每句准时抵达。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.liveActivity.status).font(.caption)
                }
                }
                #endif
                if category == .connection {
                Section("Mac → iPhone/iPad 推送桥") {
                    Toggle("启用后台推送桥", isOn: $model.relayEnabled)
                    TextField("HTTPS 服务地址", text: $model.relayURL)
                    SecureField("配对密钥（至少 32 字符）", text: $model.relayKey)
                    Text("两端填写同一服务地址和配对密钥。服务需配置 Apple APNs 签名密钥；私钥只留在服务端。Mac 持续运行时，每次发送当前歌词给该服务。配置后重新启动实时活动。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.relayStatus).font(.caption).foregroundStyle(.secondary)
                    Button("保存连接设置") { model.saveSettings() }
                }
                Section("关于") {
                    Text("VerseDock \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") · 原创原生实现")
                    Text("独立 Spotify 歌词伴侣。应用代码从零编写，无第三方歌词插件或 Spotify 客户端补丁。歌词内容归其权利人所有。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                }
            }
            .formStyle(.grouped)
            .id(category)
    }
}

private struct VerseAppearancePreview: View {
    @ObservedObject var model: VerseModel
    @ObservedObject var appearance: VerseAlbumAppearance
    var body: some View {
        ZStack {
            VerseListeningBackground(palette: appearance.palette, strength: model.albumBackgroundStrength,
                enabled: model.albumBackgroundEnabled, flowing: model.albumFlowEnabled, usesWindowBackdrop: false)
            VStack(spacing: 13) {
                HStack(spacing: 13) {
                    VerseArtwork(url: model.snapshot?.track.artworkURL, size: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.snapshot?.track.title ?? "VerseDock")
                            .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                        Text("外观实时预览").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 10)
                }
                .foregroundStyle(.white).padding(16).frame(maxWidth: 360)
                .modifier(VerseGlassSurface(cornerRadius: 21, interactive: false))
                Text(appearance.loading ? "正在准备封面配色…" :
                    (appearance.hasArtworkColors ? "配色来自当前专辑封面" : "无可用封面，使用柔和中性色"))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
            }.padding(.horizontal, 22)
        }
        .frame(height: 162).clipShape(RoundedRectangle(cornerRadius: 22))
        .environment(\.colorScheme, .dark)
        .environment(\.verseMotionEnabled, model.interfaceMotionEnabled)
        .environment(\.verseGlassStrength, model.glassStrength)
        .environment(\.verseGlassColor, model.albumBackgroundEnabled ? appearance.palette.tint : VerseAlbumPalette.neutral.tint)
    }
}
