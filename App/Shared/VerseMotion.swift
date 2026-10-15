import SwiftUI
#if os(macOS)
import AppKit
#endif

private struct VerseMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}
private struct VerseGlassStrengthKey: EnvironmentKey { static let defaultValue = 0.4 }
private struct VerseGlassColorKey: EnvironmentKey { static let defaultValue = VerseAlbumPalette.neutral.tint }

extension EnvironmentValues {
    var verseMotionEnabled: Bool {
        get { self[VerseMotionEnabledKey.self] }
        set { self[VerseMotionEnabledKey.self] = newValue }
    }
    var verseGlassStrength: Double {
        get { self[VerseGlassStrengthKey.self] }
        set { self[VerseGlassStrengthKey.self] = newValue }
    }
    var verseGlassColor: Color {
        get { self[VerseGlassColorKey.self] }
        set { self[VerseGlassColorKey.self] = newValue }
    }
}

struct VerseGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 18
    var tint: Color? = nil
    var interactive = true
    var scrim = 0.12
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.verseGlassStrength) private var strength
    @Environment(\.verseGlassColor) private var albumColor
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(red: 0.16, green: 0.17, blue: 0.16), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.18), lineWidth: 0.7))
        } else if #available(macOS 26.0, iOS 26.0, *) {
            content.glassEffect((strength < 0.12 ? Glass.clear : Glass.regular)
                                .tint((tint ?? albumColor).opacity(strength * 0.7))
                                .interactive(interactive && motion && !reduceMotion),
                                in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(.black.opacity(scrim), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .background((tint ?? albumColor).opacity(strength * 0.45), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.1), lineWidth: 0.7))
        }
    }
}

struct VerseGlassGroup<Content: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { content }
        } else { content }
    }
}

struct VerseListeningBackground: View {
    let palette: VerseAlbumPalette
    var strength = 0.65
    var enabled = true
    var flowing = true
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var animate: Bool { motion && !reduceMotion && !reduceTransparency }
    var body: some View {
        ZStack {
                #if os(macOS)
                if !reduceTransparency { VerseWindowBackdrop() }
                #endif
                VerseTheme.ink
                if !reduceTransparency, enabled, strength > 0 {
                    ZStack {
                        VerseAlbumField(palette: palette, strength: strength, flowing: flowing && animate)
                            .id(palette).transition(.opacity)
                    }.animation(animate ? .easeInOut(duration: 1.8) : nil, value: palette)
                    LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.42), .black.opacity(0.58)],
                        startPoint: .top, endPoint: .bottom)
                }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}

#if os(macOS)
private struct VerseWindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = Backdrop()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
    private final class Backdrop: NSVisualEffectView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isOpaque = false
            window?.backgroundColor = NSColor(calibratedRed: 0.065, green: 0.068, blue: 0.064, alpha: 1)
            window?.appearance = NSAppearance(named: .darkAqua)
            window?.titlebarAppearsTransparent = true
        }
    }
}
#endif

struct VerseControlStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        Feedback(configuration: configuration, selected: selected)
    }
    private struct Feedback: View {
        let configuration: ButtonStyle.Configuration
        let selected: Bool
        @State private var hovered = false
        @Environment(\.verseMotionEnabled) private var motion
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Environment(\.isEnabled) private var enabled
        private var nativeGlass: Bool {
            if #available(macOS 26.0, iOS 26.0, *) { return !reduceTransparency }
            return false
        }
        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? VerseTheme.accent : .white.opacity(enabled ? 0.86 : 0.25))
                .padding(.horizontal, 11).frame(minWidth: 34, minHeight: 34)
                .background(.white.opacity(hovered ? 0.025 : 0), in: RoundedRectangle(cornerRadius: 18))
                .modifier(VerseGlassSurface(tint: selected ? VerseTheme.accent : nil))
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .scaleEffect(!nativeGlass && configuration.isPressed && motion && !reduceMotion ? 0.94 : 1)
                .animation(motion && !reduceMotion ? .easeOut(duration: 0.16) : nil, value: configuration.isPressed)
                .animation(motion && !reduceMotion ? .easeOut(duration: 0.18) : nil, value: hovered)
                .onHover { hovered = $0 }
        }
    }
}

struct VerseQuietStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Feedback(configuration: configuration) }
    private struct Feedback: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovered = false
        @Environment(\.verseMotionEnabled) private var motion
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                #if os(macOS)
                .frame(minWidth: 30, minHeight: 30)
                #else
                .frame(minWidth: 36, minHeight: 44)
                #endif
                .background(.white.opacity(configuration.isPressed ? 0.08 : (hovered ? 0.045 : 0)),
                            in: RoundedRectangle(cornerRadius: 13))
                .contentShape(RoundedRectangle(cornerRadius: 13))
                .scaleEffect(configuration.isPressed && motion && !reduceMotion ? 0.96 : 1)
                .animation(motion && !reduceMotion ? .easeOut(duration: 0.16) : nil, value: hovered)
                .animation(motion && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

/// A quiet playback indicator, not an audio level meter.
struct VersePlaybackIndicator: View {
    let playing: Bool
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20,
                                paused: !playing || !motion || reduceMotion || phase == .background)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3) { index in
                    let height = playing && motion && !reduceMotion
                        ? 4 + (sin(time * 3.4 + Double(index) * 1.8) + 1) * 3.5
                        : Double([5, 10, 7][index])
                    Capsule().fill(playing ? VerseTheme.accent : .white.opacity(0.3))
                        .frame(width: 2, height: height)
                }
            }.frame(width: 10, height: 13)
        }.accessibilityHidden(true)
    }
}

struct VerseArtwork: View {
    let url: URL?
    var size: CGFloat = 72
    var fallback: Image? = nil
    @State private var hovered = false
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        AsyncImage(url: url?.scheme == "https" ? url : nil) { phase in
            ZStack {
                if let image = phase.image {
                    image.resizable().scaledToFill().frame(width: size, height: size)
                        .blur(radius: size * 0.2).opacity(0.2).scaleEffect(1.12)
                    image.resizable().scaledToFill().frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size > 150 ? 19 : 13))
                        .transition(.opacity)
                } else if let fallback {
                    fallback.resizable().scaledToFill().frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size > 150 ? 19 : 13))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.045))
                    Image(systemName: "music.note").font(.system(size: 23, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: size > 150 ? 19 : 13)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: size * 0.09, y: size * 0.055)
        .rotation3DEffect(.degrees(hovered && motion && !reduceMotion ? 3 : 0), axis: (x: -0.3, y: 1, z: 0))
        .scaleEffect(hovered && motion && !reduceMotion ? 1.015 : 1)
        .animation(motion && !reduceMotion ? .spring(duration: 0.4, bounce: 0.15) : nil, value: hovered)
        .onHover { hovered = $0 }
        .accessibilityHidden(true)
    }
}

struct VerseLyricRow: View {
    let text: String
    let translation: String
    let active: Bool
    let nearby: Bool
    var fontSize: CGFloat = 28
    var timestamp: String? = nil
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text.isEmpty ? "♪" : text)
                    .font(.system(size: fontSize, weight: active ? .semibold : .medium))
                    .tracking(-0.55).lineSpacing(5)
                    .foregroundStyle(.white.opacity(active ? 0.98 : (hovered ? 0.72 : (nearby ? 0.48 : 0.22))))
                    .fixedSize(horizontal: false, vertical: true)
                if !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 14, weight: .regular)).lineSpacing(3)
                        .foregroundStyle(.white.opacity(active ? 0.56 : (nearby ? 0.32 : 0.18)))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("译文：" + translation)
                        .transition(.opacity)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            if let timestamp {
                Text(timestamp).font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white.opacity(hovered ? 0.45 : 0)).frame(width: 29, alignment: .trailing)
            }
            }
            .scaleEffect(active || !motion || reduceMotion ? 1 : 0.975, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .animation(motion && !reduceMotion ? .spring(duration: 0.5, bounce: 0.06) : nil, value: active)
            .animation(motion && !reduceMotion ? .easeOut(duration: 0.18) : nil, value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct VersePlaybackRail: ProgressViewStyle {
    @Environment(\.verseMotionEnabled) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(VerseTheme.accent.opacity(0.85))
                    .frame(width: geometry.size.width * max(0, min(1, configuration.fractionCompleted ?? 0)))
            }
            .animation(motion && !reduceMotion ? .linear(duration: 0.14) : nil, value: configuration.fractionCompleted)
        }.frame(height: 3)
    }
}
