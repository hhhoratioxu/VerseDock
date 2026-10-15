import SwiftUI

@main struct VerseDockApp: App {
    @StateObject private var model = VerseModel.shared
    var body: some Scene {
        #if os(macOS)
        WindowGroup("VerseDock", id: "main") {
            ContentView(model: model).frame(minWidth: 400, minHeight: 600)
        }.defaultSize(width: 480, height: 740).windowStyle(.hiddenTitleBar)
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Label(model.menuTitle, systemImage: "waveform")
        }.menuBarExtraStyle(.window)
        #else
        WindowGroup { ContentView(model: model) }
        #endif
    }
}

#if os(macOS)
struct MenuContent: View {
    @ObservedObject var model: VerseModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VerseDock").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(model.currentLine).font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(VerseTheme.accent).lineLimit(4)
            Text(model.snapshot?.track.artist ?? model.status).font(.caption).foregroundStyle(.secondary)
            Divider()
            Button(model.overlayVisible ? "隐藏悬浮歌词" : "显示悬浮歌词") { model.toggleOverlay() }
            Button("打开歌词与设置") { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
            Button("退出 VerseDock") { NSApplication.shared.terminate(nil) }
        }.padding(20).frame(width: 300).preferredColorScheme(.dark).task { model.start() }
    }
}
#endif
