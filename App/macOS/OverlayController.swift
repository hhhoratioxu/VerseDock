import AppKit
import SwiftUI

@MainActor final class OverlayController {
    static let shared = OverlayController()
    private var panel: NSPanel?
    func setVisible(_ visible: Bool, model: VerseModel) {
        if !visible { panel?.orderOut(nil); return }
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 120, y: 100, width: 760, height: 145),
                styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = false; window.backgroundColor = .clear
            window.hasShadow = true; window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 300, height: 90)
            window.contentView = NSHostingView(rootView: OverlayView(model: model))
            window.setFrameAutosaveName("VerseDockOverlay")
            panel = window
        }
        panel?.orderFrontRegardless()
    }
}

struct OverlayView: View {
    @ObservedObject var model: VerseModel
    var body: some View {
        VStack(spacing: 7) {
            Text(model.currentLine).font(.system(size: model.overlayFont, weight: .semibold, design: .rounded))
                .foregroundStyle(VerseTheme.accent).multilineTextAlignment(.center).lineLimit(3)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            Text(model.nextLine.isEmpty ? (model.lyrics == nil ? "等待歌词 · " + model.status : model.status) : model.nextLine)
                .font(.system(size: max(12, model.overlayFont * 0.55))).foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1))
        .contextMenu {
            Button("隐藏悬浮歌词") { model.toggleOverlay() }
            Button("字号 +") { model.overlayFont = min(48, model.overlayFont + 2); model.saveSettings() }
            Button("字号 −") { model.overlayFont = max(18, model.overlayFont - 2); model.saveSettings() }
        }
    }
}
