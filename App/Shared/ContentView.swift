import SwiftUI
import UniformTypeIdentifiers
import VerseCore
#if os(macOS)
import AppKit
#endif

enum VerseTheme {
    static let ink = Color(red: 0.065, green: 0.068, blue: 0.064)
    static let accent = Color(red: 0.79, green: 0.88, blue: 0.64)
}

struct ContentView: View {
    @ObservedObject var model: VerseModel
    @State private var settings = false
    @State private var importing = false
    @State private var follow = true
    @State private var sourceDetails = false
    @State private var calibration = false
    @State private var appeared = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Bool { model.interfaceMotionEnabled && !reduceMotion }
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
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 12)
            Rectangle().fill(.white.opacity(0.055)).frame(height: 0.5).padding(.horizontal, 24)
            trackHeader.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 18)
            lyricsBody
            footer.padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { VerseListeningBackground(artwork: model.snapshot?.track.artworkURL).ignoresSafeArea() }
        .foregroundStyle(.white)
        .tint(VerseTheme.accent)
        .preferredColorScheme(.dark)
        .environment(\.verseMotionEnabled, model.interfaceMotionEnabled)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || !motion ? 0 : 5)
        .modifier(LyricTranslationHost(model: model))
        .sheet(isPresented: $settings) { SettingsView(model: model) }
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
        .onAppear { withAnimation(motion ? .easeOut(duration: 0.35) : nil) { appeared = true } }
        .onChange(of: model.snapshot?.track.id) { _, _ in follow = true }
        #if os(iOS)
        .onChange(of: phase) { _, value in model.setForeground(value == .active) }
        #endif
    }
    private var header: some View {
        HStack(spacing: 3) {
            HStack(spacing: 8) {
                brandMark.resizable().scaledToFit().frame(width: 25, height: 25)
                    .clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true)
                Text("VerseDock").font(.system(size: 15, weight: .semibold)).tracking(-0.3)
                    .foregroundStyle(.white.opacity(0.88))
            }
            Spacer()
            VerseGlassGroup {
            HStack(spacing: 6) {
            Button { model.retryLyrics() } label: { Image(systemName: "arrow.clockwise") }
                .help("重新查找歌词（跳过缓存）").accessibilityLabel("重新查找歌词")
                .disabled(model.snapshot == nil || model.loadingLyrics)
            Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                .help("导入 LRC 歌词").accessibilityLabel("导入 LRC 歌词")
            Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }
                .help("设置").accessibilityLabel("设置")
            }
            }
        }.buttonStyle(VerseControlStyle())
    }
    private var trackHeader: some View {
        HStack(spacing: 17) {
            VerseArtwork(url: model.snapshot?.track.artworkURL)
                .id(model.snapshot?.track.artworkURL)
                .transition(.opacity.combined(with: .scale(scale: motion ? 0.96 : 1)))
            VStack(alignment: .leading, spacing: 5) {
                Text(model.snapshot?.track.title ?? "开始听歌")
                    .font(.system(size: 20, weight: .semibold)).tracking(-0.5).lineLimit(2)
                    .contentTransition(.opacity)
                Text(model.snapshot?.track.artist ?? "在 Spotify 播放，歌词会自动出现")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.48)).lineLimit(1)
                    .contentTransition(.opacity)
                HStack(spacing: 7) {
                    VersePlaybackIndicator(playing: model.snapshot?.isPlaying == true)
                    Text(model.isDemo ? "原创演示" : model.status)
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
                }.padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .animation(motion ? .easeInOut(duration: 0.3) : nil, value: model.snapshot?.track.id)
    }
    @ViewBuilder private var lyricsBody: some View {
        if let document = model.lyrics, !document.lines.isEmpty {
            GeometryReader { geometry in
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 15) {
                            ForEach(document.lines) { line in
                                VerseLyricRow(text: line.text, translation: model.translatedLine(line.text),
                                    active: model.activeIndex == line.id,
                                    nearby: abs(line.id - (model.activeIndex ?? -2)) <= 1) {
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
                        .padding(.horizontal, 33)
                        .padding(.vertical, max(70, geometry.size.height * 0.44))
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
                    .onAppear { if let value = model.activeIndex { reader.scrollTo(value, anchor: .center) } }
                    .overlay(alignment: .topTrailing) {
                        Button { follow.toggle() } label: {
                            Label(follow ? "跟随" : "浏览", systemImage: follow ? "location.fill" : "hand.draw")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(VerseControlStyle(selected: follow))
                        .accessibilityIdentifier("lyrics-follow")
                        .padding(.trailing, 22).padding(.top, 3)
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
                    else { Button("打开设置") { settings = true } }
                }.buttonStyle(VerseControlStyle()).padding(.top, 5)
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var footer: some View {
        VStack(spacing: 12) {
            if !model.seekStatus.isEmpty {
                HStack {
                    Text(model.seekStatus).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                        .contentTransition(.opacity)
                    Spacer()
                    if model.seeking { ProgressView().controlSize(.mini) }
                }.transition(.opacity)
            }
            if let snapshot = model.snapshot {
                VStack(spacing: 8) {
                    ProgressView(value: model.progress, total: max(1, snapshot.track.duration))
                        .progressViewStyle(VersePlaybackRail()).accessibilityLabel("播放进度")
                    HStack { Text(time(model.progress)); Spacer(); Text(time(snapshot.track.duration)) }
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(.white.opacity(0.28))
                }
            }
            VerseGlassGroup {
            HStack(spacing: 6) {
                Button { sourceDetails.toggle() } label: {
                    HStack(spacing: 6) {
                        if model.loadingLyrics { ProgressView().controlSize(.mini) }
                        else { Circle().fill(VerseTheme.accent.opacity(0.7)).frame(width: 4, height: 4) }
                        Text(model.lyrics.map { $0.source == "Spotify" ? "Spotify 原词" : $0.source } ?? "歌词来源")
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                    }
                }
                .help(model.lyricsStatus).accessibilityLabel("歌词来源与状态")
                .buttonStyle(VerseControlStyle(selected: sourceDetails))
                .popover(isPresented: $sourceDetails) { sourcePopover.presentationCompactAdaptation(.popover) }
                Spacer(minLength: 4)
                Button { calibration.toggle() } label: {
                    Label(abs(model.adjustment) < 0.05 ? "校准" : String(format: "%+.1fs", model.adjustment), systemImage: "timer")
                }
                .accessibilityLabel("歌词时间校准")
                .buttonStyle(VerseControlStyle(selected: calibration))
                .popover(isPresented: $calibration) { calibrationPopover.presentationCompactAdaptation(.popover) }
                #if os(macOS)
                Button { model.toggleOverlay() } label: { Image(systemName: "rectangle.on.rectangle") }
                    .buttonStyle(VerseControlStyle(selected: model.overlayVisible))
                    .help(model.overlayVisible ? "隐藏悬浮歌词" : "显示悬浮歌词")
                    .accessibilityLabel(model.overlayVisible ? "隐藏悬浮歌词" : "悬浮歌词")
                #else
                ActivityButton(model: model, controller: model.liveActivity)
                #endif
            }.buttonStyle(VerseControlStyle())
            }
            if model.isDemo {
                HStack {
                    Text("演示 · 原创歌词").foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Button("重播") { model.demo() }.accessibilityLabel("重新播放原创演示")
                    Button("回到 Spotify") { model.endDemo() }
                }.font(.system(size: 10)).buttonStyle(VerseControlStyle())
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
            Button("设置歌词来源与翻译") { sourceDetails = false; settings = true }.font(.system(size: 12))
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

struct SettingsView: View {
    @ObservedObject var model: VerseModel
    @ObservedObject private var spotifyLyrics = SpotifyLyricsSession.shared
    @State private var connectingLyrics = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle("界面动效", isOn: $model.interfaceMotionEnabled)
                    Text("歌词过渡、按钮反馈与悬浮窗淡入。会遵循系统的“减少动态效果”设置；关闭后立即切换。")
                        .font(.caption).foregroundStyle(.secondary)
                    if reduceMotion {
                        Text("系统已开启“减少动态效果”，界面保持静态。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("歌词来源") {
                    Toggle("自动查找在线歌词与备用来源", isOn: $model.onlineLyrics)
                    Toggle("优先使用 Spotify 原词", isOn: $model.preferSpotifyLyrics).disabled(!model.onlineLyrics)
                    Button("连接 / 查看 Spotify 原词会话") {
                        #if os(macOS)
                        dismiss()
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
                #if os(macOS)
                Section("Mac 显示") {
                    Stepper("状态栏最多 \(model.menuLength) 个字符", value: $model.menuLength, in: 8...40)
                    Toggle("状态栏歌词滚动", isOn: $model.menuScrolling)
                    Slider(value: $model.overlayFont, in: 18...48, step: 1) { Text("悬浮字号") }
                    Text("顶部状态栏直接显示当前歌词。显示长度与滚动开关独立设置并自动保存，默认静态；开启滚动后，放不下的长句从头滚动。悬浮字号：\(Int(model.overlayFont))，拖动歌词或空白处可移动，右键可隐藏。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                #else
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
                #endif
                Section("Mac → iPhone/iPad 推送桥") {
                    Toggle("启用后台推送桥", isOn: $model.relayEnabled)
                    TextField("HTTPS 服务地址", text: $model.relayURL)
                    SecureField("配对密钥（至少 32 字符）", text: $model.relayKey)
                    Text("两端填写同一服务地址和配对密钥。服务需配置 Apple APNs 签名密钥；私钥只留在服务端。Mac 持续运行时，每次发送当前歌词给该服务。配置后重新启动实时活动。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.relayStatus).font(.caption).foregroundStyle(.secondary)
                }
                Section("关于") {
                    Text("VerseDock 0.1.5 · 原创原生实现")
                    Text("独立 Spotify 歌词伴侣。应用代码从零编写，无第三方歌词插件或 Spotify 客户端补丁。歌词内容归其权利人所有。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("保存") { model.saveSettings(); dismiss() } } }
        }
        .preferredColorScheme(.dark).tint(VerseTheme.accent)
        .sheet(isPresented: $connectingLyrics) { SpotifyLyricsConnectionView() }
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }
}
