import AppKit
import SwiftUI

@MainActor final class OverlayController: NSObject, NSWindowDelegate {
    static let shared = OverlayController()
    private var panel: NSWindow?
    func setVisible(_ visible: Bool, model: VerseModel) {
        if !visible { panel?.orderOut(nil); return }
        if panel == nil {
            let window = FloatingLyricsWindow(contentRect: NSRect(x: 120, y: 100, width: 760, height: 145),
                styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            window.level = .floating
            window.title = "VerseDock 悬浮歌词"
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = false; window.backgroundColor = .clear
            window.hasShadow = true; window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 300, height: 90)
            window.contentView = DraggableLyricsView(rootView: OverlayView(model: model))
            _ = window.setFrameUsingName("VerseDockOverlay")
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) {
                window.center()
            }
            window.setFrameAutosaveName("VerseDockOverlay")
            window.delegate = self
            panel = window
        }
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }
    func windowDidMove(_ notification: Notification) { panel?.saveFrame(usingName: "VerseDockOverlay") }
    func windowDidEndLiveResize(_ notification: Notification) { panel?.saveFrame(usingName: "VerseDockOverlay") }
}

private final class DraggableLyricsView: NSHostingView<OverlayView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let view = super.hitTest(point) else { return nil }
        return NSApp.currentEvent?.type == .leftMouseDown ? self : view
    }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private final class FloatingLyricsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        let point = event.locationInWindow
        let interior = NSRect(origin: .zero, size: frame.size).insetBy(dx: 8, dy: 8)
        if event.type == .leftMouseDown, interior.contains(point) {
            // Handle the drag before SwiftUI text or its context-menu hosting view consumes the event.
            performDrag(with: event)
            return
        }
        super.sendEvent(event)
    }
}

struct OverlayView: View {
    @ObservedObject var model: VerseModel
    var body: some View {
        VStack(spacing: 7) {
            Text(model.currentLine).font(.system(size: model.overlayFont, weight: .semibold, design: .rounded))
                .foregroundStyle(VerseTheme.accent).multilineTextAlignment(.center).lineLimit(3)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            Text(!model.currentTranslation.isEmpty ? model.currentTranslation :
                (model.translationEnabled ? model.translationStatus :
                (model.nextLine.isEmpty ? (model.lyrics == nil ? "等待歌词 · " + model.status : model.status) : model.nextLine)))
                .font(.system(size: max(12, model.overlayFont * 0.55))).foregroundStyle(.white.opacity(0.62))
                .lineLimit(model.translationEnabled ? 2 : 1)
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Image(systemName: "circle.grid.2x2.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)).padding(11)
        }
        .help("拖动歌词或空白处移动窗口；右键调整或隐藏。位置会自动保存。")
        .contextMenu {
            Button("隐藏悬浮歌词") { model.toggleOverlay() }
            Button("字号 +") { model.overlayFont = min(48, model.overlayFont + 2); model.saveSettings() }
            Button("字号 −") { model.overlayFont = max(18, model.overlayFont - 2); model.saveSettings() }
        }
    }
}
