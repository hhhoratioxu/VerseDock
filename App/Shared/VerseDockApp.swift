import SwiftUI

@main struct VerseDockApp: App {
    @StateObject private var model = VerseModel.shared
    #if os(macOS)
    @NSApplicationDelegateAdaptor(VerseAppDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        #if os(macOS)
        Window("VerseDock", id: "main") {
            ContentView(model: model).frame(minWidth: 400, minHeight: 580)
        }
        .defaultSize(width: 900, height: 660)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("紧凑窗口") { StatusBarController.shared.resizeMainWindow(compact: true) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("舒展窗口") { StatusBarController.shared.resizeMainWindow(compact: false) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
        Settings { SettingsView(model: model) }
        #else
        WindowGroup { ContentView(model: model) }
        #endif
    }
}
