import SwiftUI

@main struct VerseDockApp: App {
    @StateObject private var model = VerseModel.shared
    #if os(macOS)
    @NSApplicationDelegateAdaptor(VerseAppDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        #if os(macOS)
        WindowGroup("VerseDock", id: "main") {
            ContentView(model: model).frame(minWidth: 400, minHeight: 600)
        }.defaultSize(width: 480, height: 740).windowStyle(.hiddenTitleBar)
        #else
        WindowGroup { ContentView(model: model) }
        #endif
    }
}
