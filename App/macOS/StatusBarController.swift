import AppKit
import Combine
import SwiftUI
import VerseCore

@MainActor final class VerseAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarController.shared.start(model: .shared)
        VerseModel.shared.start()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// The lyric is the title of an actual macOS status button, visible before opening its menu.
@MainActor final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()
    private var item: NSStatusItem?
    private var model: VerseModel?
    private var subscriptions = Set<AnyCancellable>()
    private var fallbackWindow: NSWindow?
    private let bilingualText = BilingualStatusText()

    func start(model: VerseModel) {
        guard item == nil else { return }
        self.model = model
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "VerseDockLyrics"
        item.isVisible = true
        let menu = NSMenu(title: "VerseDock")
        menu.delegate = self
        item.menu = menu
        self.item = item
        if let button = item.button {
            button.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "VerseDock")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            button.alignment = .left
            button.cell?.lineBreakMode = .byClipping
            button.setAccessibilityIdentifier("VerseDockStatusLyrics")
            bilingualText.autoresizingMask = [.width, .height]
            bilingualText.frame = button.bounds.insetBy(dx: 0, dy: 0)
            button.addSubview(bilingualText)
            bilingualText.isHidden = true
        }
        model.$menuText.combineLatest(model.$menuTranslation).receive(on: RunLoop.main).sink { [weak self] title, translation in
            guard let self, let button = self.item?.button else { return }
            self.bilingualText.original = title; self.bilingualText.translation = translation
            self.bilingualText.isHidden = translation.isEmpty
            self.bilingualText.needsDisplay = true
            button.title = translation.isEmpty ? " " + title : ""
            button.image = translation.isEmpty ? NSImage(systemSymbolName: "music.note", accessibilityDescription: "VerseDock") : nil
            button.image?.isTemplate = true
            button.toolTip = model.currentLine + "\n" + model.currentTranslation + "\n" + (model.snapshot?.track.title ?? "VerseDock")
            button.setAccessibilityLabel("VerseDock 状态栏歌词：" + title + (translation.isEmpty ? "" : "；译文：" + translation))
        }.store(in: &subscriptions)
        model.$menuLength.receive(on: RunLoop.main).sink { [weak self] width in
            let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            let textWidth = (String(repeating: "字", count: max(8, min(40, width))) as NSString)
                .size(withAttributes: [.font: font]).width
            self?.item?.length = min(520, textWidth + 30)
        }.store(in: &subscriptions)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let model else { return }
        menu.removeAllItems()
        let line = NSMenuItem(title: model.currentLine.replacingOccurrences(of: "\n", with: " · "), action: nil, keyEquivalent: "")
        line.isEnabled = false; menu.addItem(line)
        if !model.currentTranslation.isEmpty {
            let translated = NSMenuItem(title: model.currentTranslation, action: nil, keyEquivalent: "")
            translated.isEnabled = false; menu.addItem(translated)
        }
        let song = NSMenuItem(title: model.snapshot.map { $0.track.title + " · " + $0.track.artist } ?? model.status,
            action: nil, keyEquivalent: "")
        song.isEnabled = false; menu.addItem(song)
        menu.addItem(.separator())
        add("打开歌词与设置", action: #selector(showMainWindow), to: menu)
        add("重新查找歌词", action: #selector(retry), to: menu)
        let sourceItem = NSMenuItem(title: "歌词提供商", action: nil, keyEquivalent: "")
        let sources = NSMenu()
        for choice in LyricsProviderChoice.allCases {
            let source = add(choice.name, action: #selector(changeProvider(_:)), to: sources)
            source.representedObject = choice.rawValue
            source.state = model.lyricsProviderChoice == choice ? .on : .off
        }
        sourceItem.submenu = sources; menu.addItem(sourceItem)
        let translate = add("开启歌词翻译", action: #selector(toggleTranslation), to: menu)
        translate.state = model.translationEnabled ? .on : .off
        translate.isEnabled = model.translationAvailable
        let scrolling = add("状态栏长句滚动", action: #selector(toggleScrolling), to: menu)
        scrolling.state = model.menuScrolling ? .on : .off
        let widthItem = NSMenuItem(title: "状态栏显示宽度", action: nil, keyEquivalent: "")
        let widths = NSMenu()
        for width in [8, 12, 18, 24, 32, 40] {
            let choice = add("\(width) 个字符", action: #selector(changeWidth(_:)), to: widths)
            choice.representedObject = width
            choice.state = model.menuLength == width ? .on : .off
        }
        widthItem.submenu = widths; menu.addItem(widthItem)
        add(model.overlayVisible ? "隐藏悬浮歌词" : "显示悬浮歌词", action: #selector(toggleOverlay), to: menu)
        menu.addItem(.separator())
        add("退出 VerseDock", action: #selector(quit), to: menu)
    }
    @discardableResult private func add(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; menu.addItem(entry); return entry
    }
    @objc private func retry() { model?.retryLyrics() }
    @objc private func toggleOverlay() { model?.toggleOverlay() }
    @objc private func toggleTranslation() { model?.translationEnabled.toggle(); if model?.translationEnabled == true { showMainWindow() } }
    @objc private func toggleScrolling() {
        guard let model else { return }
        model.menuScrolling.toggle()
    }
    @objc private func changeWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? Int else { return }
        model?.menuLength = width
    }
    @objc private func changeProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = LyricsProviderChoice(rawValue: raw) else { return }
        model?.lyricsProviderChoice = choice
    }
    @objc private func showMainWindow() {
        guard let model else { return }
        if let window = NSApp.windows.first(where: { $0.title == "VerseDock" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = fallbackWindow ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "VerseDock"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 400, height: 600); window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ContentView(model: model))
            if fallbackWindow == nil { window.center() }
            fallbackWindow = window; window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

private final class BilingualStatusText: NSView {
    var original = ""
    var translation = ""
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byClipping
        let width = max(0, bounds.width - 6)
        (original.replacingOccurrences(of: "\n", with: " ") as NSString).draw(
            in: NSRect(x: 3, y: bounds.height / 2 - 1, width: width, height: 12),
            withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: style])
        (translation.replacingOccurrences(of: "\n", with: " ") as NSString).draw(
            in: NSRect(x: 3, y: 0, width: width, height: 11),
            withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: style])
    }
}
