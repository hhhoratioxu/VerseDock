import AppKit
import SwiftUI

@MainActor final class OverlayController: NSObject, NSWindowDelegate {
    static let shared = OverlayController()
    private var panel: NSWindow?
    private var visibilityRevision = 0
    func setVisible(_ visible: Bool, model: VerseModel) {
        visibilityRevision += 1
        let revision = visibilityRevision
        let animate = model.interfaceMotionEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !visible {
            guard let panel else { return }
            if !animate { panel.orderOut(nil); panel.alphaValue = 1; return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    guard self?.visibilityRevision == revision else { return }
                    panel?.orderOut(nil); panel?.alphaValue = 1
                }
            }
            return
        }
        if panel == nil {
            let window = FloatingLyricsWindow(contentRect: NSRect(x: 120, y: 100, width: 760, height: 145),
                styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            window.level = .floating
            window.title = "VerseDock 悬浮歌词"
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = false; window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
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
        guard let panel else { return }
        if animate, !panel.isVisible { panel.alphaValue = 0 }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                panel.animator().alphaValue = 1
            }
        } else { panel.alphaValue = 1 }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    private var motion: Bool { model.interfaceMotionEnabled && !reduceMotion }
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Text(model.currentLine).font(.system(size: model.overlayFont, weight: .medium))
                    .tracking(-0.5).foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center).lineLimit(3)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .id(model.currentLine)
                    .transition(.opacity.combined(with: .offset(y: motion ? 5 : 0)))
            }.animation(motion ? .easeOut(duration: 0.28) : nil, value: model.currentLine)
            ZStack {
                Text(secondaryLine)
                    .font(.system(size: max(12, model.overlayFont * 0.53))).foregroundStyle(.white.opacity(0.48))
                    .lineLimit(model.translationEnabled ? 2 : 1)
                    .id(secondaryLine).transition(.opacity)
            }.animation(motion ? .easeOut(duration: 0.22) : nil, value: secondaryLine)
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(VerseGlassSurface(cornerRadius: 22, tint: .black.opacity(0.12), interactive: false))
        .environment(\.verseMotionEnabled, model.interfaceMotionEnabled)
        .overlay(alignment: .topLeading) {
            Image(systemName: "circle.grid.2x2.fill").font(.system(size: 9))
                .foregroundStyle(.white.opacity(hovered ? 0.4 : 0)).padding(11)
        }
        .animation(motion ? .easeOut(duration: 0.18) : nil, value: hovered)
        .onHover { hovered = $0 }
        .preferredColorScheme(.dark)
        .help("拖动歌词或空白处移动窗口；右键调整或隐藏。位置会自动保存。")
        .contextMenu {
            Button("隐藏悬浮歌词") { model.toggleOverlay() }
            Button("字号 +") { model.overlayFont = min(48, model.overlayFont + 2); model.saveSettings() }
            Button("字号 −") { model.overlayFont = max(18, model.overlayFont - 2); model.saveSettings() }
        }
    }
    private var secondaryLine: String {
        if !model.currentTranslation.isEmpty { return model.currentTranslation }
        if !model.nextLine.isEmpty { return model.nextLine }
        if model.lyrics == nil { return "等待歌词" }
        return model.snapshot.map { $0.track.artist + " · " + $0.track.title } ?? "VerseDock"
    }
}
