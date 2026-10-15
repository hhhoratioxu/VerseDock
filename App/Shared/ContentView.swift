import SwiftUI
import UniformTypeIdentifiers
import VerseCore
#if os(macOS)
import AppKit
#endif

enum VerseTheme {
    static let ink = Color(red: 0.055, green: 0.065, blue: 0.09)
    static let accent = Color(red: 0.72, green: 0.91, blue: 0.58)
}

struct ContentView: View {
    @ObservedObject var model: VerseModel
    @State private var settings = false
    @State private var importing = false
    @State private var follow = true
    @Environment(\.scenePhase) private var phase
    private var brandMark: Image {
        #if os(macOS)
        if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return Image(nsImage: image) }
        return Image(systemName: "waveform")
        #else
        return Image("BrandMark")
        #endif
    }
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            Divider().overlay(.white.opacity(0.05))
            trackHeader.padding(24)
            lyricsBody
            footer.padding(22)
        }
        .background(VerseTheme.ink)
        .foregroundStyle(.white)
        .tint(VerseTheme.accent)
        .preferredColorScheme(.dark)
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
        #if os(iOS)
        .onChange(of: phase) { _, value in model.setForeground(value == .active) }
        #endif
    }
    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                brandMark.resizable().scaledToFit().frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("VerseDock").font(.system(.title3, design: .rounded, weight: .bold))
                    Text("每一句，都在此刻").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }.help("导入 LRC 歌词")
                .accessibilityLabel("导入 LRC 歌词")
            Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.help("设置")
                .accessibilityLabel("设置")
        }.buttonStyle(.borderless)
    }
    private var trackHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.07))
                Image(systemName: "music.note").font(.title).foregroundStyle(VerseTheme.accent.opacity(0.8))
                if let artwork = model.snapshot?.track.artworkURL, artwork.scheme == "https" {
                    AsyncImage(url: artwork) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                }
            }.frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text(model.snapshot?.track.title ?? "从 Spotify 开始").font(.headline).lineLimit(2)
                Text(model.snapshot?.track.artist ?? "播放音乐，让歌词跟上旋律")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(model.snapshot?.isPlaying == true ? VerseTheme.accent : .gray).frame(width: 5, height: 5)
                    Text(model.status).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }
    @ViewBuilder private var lyricsBody: some View {
        if let document = model.lyrics, !document.lines.isEmpty {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(document.lines) { line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: model.activeIndex == line.id ? 30 : 26, weight: .bold, design: .rounded))
                                .foregroundStyle(model.activeIndex == line.id ? VerseTheme.accent : .white.opacity(0.30))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                                .id(line.id)
                                .accessibilityAddTraits(model.activeIndex == line.id ? .isSelected : [])
                        }
                    }.padding(.horizontal, 28).padding(.vertical, 80)
                }
                .onChange(of: model.activeIndex) { _, value in
                    guard follow, let value else { return }
                    withAnimation(.easeOut(duration: 0.3)) { reader.scrollTo(value, anchor: .center) }
                }
                .onAppear { if let value = model.activeIndex { reader.scrollTo(value, anchor: .center) } }
                .overlay(alignment: .topTrailing) {
                    Button { follow.toggle() } label: {
                        Label(follow ? "跟随" : "浏览", systemImage: follow ? "location.fill" : "hand.draw")
                            .font(.caption).padding(9).background(.ultraThinMaterial, in: Capsule())
                    }.buttonStyle(.plain).padding(.trailing, 24)
                }
            }
        } else if let document = model.lyrics, !document.plainText.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("纯文本歌词 · 无同步时间戳").font(.caption).foregroundStyle(VerseTheme.accent)
                    Text(document.plainText).font(.system(size: 24, weight: .medium)).lineSpacing(10).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(28)
            }
        } else {
            VStack(spacing: 18) {
                Image(systemName: model.lyrics?.instrumental == true ? "pianokeys" : "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 44, weight: .light)).foregroundStyle(VerseTheme.accent)
                Text(model.lyrics?.instrumental == true ? "让旋律自己说话" : "等一首歌，等一句词")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(model.lyricsStatus).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if model.loadingLyrics { ProgressView() }
                HStack {
                    Button("原创演示") { model.demo() }
                    if model.snapshot != nil { Button("重试歌词") { model.retryLyrics() } }
                }.buttonStyle(.bordered)
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var footer: some View {
        VStack(spacing: 15) {
            if let snapshot = model.snapshot {
                ProgressView(value: model.progress, total: max(1, snapshot.track.duration)).tint(VerseTheme.accent)
                HStack {
                    Text(time(model.progress)); Spacer(); Text(time(snapshot.track.duration))
                }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button { model.adjustment = max(-10, model.adjustment - 0.2) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("歌词延后 0.2 秒")
                Button { model.adjustment = 0 } label: {
                    Text(String(format: "%+.1f 秒", model.adjustment)).font(.caption.monospacedDigit()).frame(minWidth: 65)
                }.help("正值让歌词提前；点击恢复零偏移")
                Button { model.adjustment = min(10, model.adjustment + 0.2) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("歌词提前 0.2 秒")
                Spacer()
                #if os(macOS)
                Button { model.toggleOverlay() } label: {
                    Label(model.overlayVisible ? "隐藏悬浮" : "悬浮歌词", systemImage: "rectangle.on.rectangle")
                }
                #else
                ActivityButton(model: model, controller: model.liveActivity)
                #endif
            }.buttonStyle(.borderless).font(.caption)
            HStack {
                Text(model.lyricsStatus).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if let link = model.snapshot?.track.spotifyURL { Link("Spotify ↗", destination: link).font(.caption2) }
            }
            if model.isDemo {
                HStack {
                    Button("回到 Spotify") { model.endDemo() }
                    Spacer()
                    Button("从头演示") { model.demo() }
                }.font(.caption).buttonStyle(.bordered)
            }
        }
    }
    private func time(_ value: Double) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}

struct SettingsView: View {
    @ObservedObject var model: VerseModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("歌词来源") {
                    Toggle("使用 LRCLIB 在线歌词", isOn: $model.onlineLyrics)
                    Text("开启后将歌名、歌手、专辑和时长发送到 lrclib.net。也可以只导入自己的 UTF-8 LRC 文件。歌词存储在本机，可随时清除。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("清除本地歌词缓存") { model.clearLyrics() }
                }
                #if os(macOS)
                Section("Mac 显示") {
                    Stepper("菜单栏最多 \(model.menuLength) 个字符", value: $model.menuLength, in: 8...40)
                    Slider(value: $model.overlayFont, in: 18...48, step: 1) { Text("悬浮字号") }
                    Text("悬浮字号：\(Int(model.overlayFont)) · 可拖动悬浮窗，右键隐藏。菜单栏始终保留入口。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                #else
                Section("Spotify 连接") {
                    TextField("Spotify Client ID", text: $model.clientID).autocorrectionDisabled().textInputAutocapitalization(.never)
                    TextField("HTTPS 回调地址", text: $model.redirectURI).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    Text("将工程里的 web 回调页部署到你自己的 HTTPS 地址，并在 Spotify Dashboard 登记完全相同的地址。不需要 Client Secret。开发模式需要应用所有者 Premium，并将使用者加入白名单。")
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
                    Text("VerseDock 0.1 · 原创原生实现")
                    Text("独立 Spotify 歌词伴侣。应用代码从零编写，无第三方歌词插件或 Spotify 客户端补丁。歌词内容归其权利人所有。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("保存") { model.saveSettings(); dismiss() } } }
        }
        .preferredColorScheme(.dark).tint(VerseTheme.accent)
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }
}
