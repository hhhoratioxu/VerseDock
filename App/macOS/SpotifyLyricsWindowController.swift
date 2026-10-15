import AppKit
import SwiftUI

@MainActor final class SpotifyLyricsWindowController {
    static let shared = SpotifyLyricsWindowController()
    private var window: NSWindow?
    func show() {
        let session = SpotifyLyricsSession.shared
        if window == nil {
            let value = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760),
                styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            value.title = "VerseDock · Spotify 原词登录"
            value.minSize = NSSize(width: 720, height: 600)
            value.isReleasedWhenClosed = false
            value.contentView = NSHostingView(rootView: SpotifyLyricsConnectionView(onDone: { [weak value] in value?.orderOut(nil) }))
            value.center()
            window = value
        }
        session.open()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(session.webView)
    }
}
