import SwiftUI
import ImageIO

struct VerseAlbumColor: Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    var color: Color { Color(red: red, green: green, blue: blue) }
    var luminance: Double { red * 0.2126 + green * 0.7152 + blue * 0.0722 }
    var saturation: Double { max(red, green, blue) - min(red, green, blue) }
    func distance(to other: Self) -> Double {
        pow(red - other.red, 2) + pow(green - other.green, 2) + pow(blue - other.blue, 2)
    }
}

struct VerseAlbumPalette: Equatable, Hashable, Sendable {
    let colors: [VerseAlbumColor]
    static let neutral = Self(colors: [
        .init(red: 0.27, green: 0.31, blue: 0.35),
        .init(red: 0.23, green: 0.27, blue: 0.30),
        .init(red: 0.19, green: 0.23, blue: 0.26)
    ])
    var tint: Color { colors[0].color }

    /// Quantized color populations from a small sRGB thumbnail, retaining the cover's hues.
    static func extract(from data: Data) -> Self? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 32,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = thumbnail.width, height = thumbnail.height
        guard width > 0, height > 0, width <= 32, height <= 32 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        struct Population {
            var count = 0
            var red = 0.0, green = 0.0, blue = 0.0
            var average: VerseAlbumColor {
                .init(red: red / Double(count), green: green / Double(count), blue: blue / Double(count))
            }
        }
        var buckets: [Int: Population] = [:]
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Double(bytes[offset + 3]) / 255
            guard alpha > 0.8 else { continue }
            let red = min(1, Double(bytes[offset]) / 255 / alpha)
            let green = min(1, Double(bytes[offset + 1]) / 255 / alpha)
            let blue = min(1, Double(bytes[offset + 2]) / 255 / alpha)
            let key = min(7, Int(red * 8)) * 64 + min(7, Int(green * 8)) * 8 + min(7, Int(blue * 8))
            var bucket = buckets[key, default: Population()]
            bucket.count += 1; bucket.red += red; bucket.green += green; bucket.blue += blue
            buckets[key] = bucket
        }
        let ordered = buckets.sorted { left, right in
            func score(_ value: Population) -> Double {
                let c = value.average
                let visibility = c.luminance < 0.06 ? 0.12 : (c.luminance > 0.94 ? 0.3 : 1)
                return Double(value.count) * (0.55 + c.saturation) * visibility
            }
            let a = score(left.value), b = score(right.value)
            return a == b ? left.key < right.key : a > b
        }
        var selected: [VerseAlbumColor] = []
        for candidate in ordered.map({ $0.value.average }) {
            if selected.allSatisfy({ $0.distance(to: candidate) > 0.065 }) { selected.append(candidate) }
            if selected.count == 3 { break }
        }
        guard let first = selected.first else { return nil }
        while selected.count < 3 { selected.append(first) }
        return Self(colors: selected)
    }
}

enum VerseAppearanceSettings {
    static func unit(_ key: String, default fallback: Double) -> Double {
        guard let value = UserDefaults.standard.object(forKey: key) as? Double, value.isFinite else { return fallback }
        return max(0, min(1, value))
    }
}

@MainActor final class VerseAlbumAppearance: ObservableObject {
    @Published private(set) var palette = VerseAlbumPalette.neutral
    @Published private(set) var hasArtworkColors = false
    @Published private(set) var loading = false
    private var requestedURL: URL?
    private var request: Task<Void, Never>?
    private var cache: [URL: VerseAlbumPalette] = [:]
    private var cacheOrder: [URL] = []

    func update(_ artwork: URL?) {
        let url = artwork?.scheme?.lowercased() == "https" ? artwork : nil
        guard url != requestedURL else { return }
        requestedURL = url; request?.cancel()
        guard let url else { palette = .neutral; hasArtworkColors = false; loading = false; return }
        if let cached = cache[url] { palette = cached; hasArtworkColors = true; loading = false; return }
        hasArtworkColors = false; loading = true
        request = Task { [weak self] in
            do {
                let query = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
                let (data, response) = try await URLSession.shared.data(for: query)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      http.mimeType?.lowercased().hasPrefix("image/") == true,
                      !data.isEmpty, data.count <= 8 * 1024 * 1024 else { throw URLError(.cannotDecodeContentData) }
                try Task.checkCancellation()
                let extracted = await Task.detached(priority: .utility) { VerseAlbumPalette.extract(from: data) }.value
                try Task.checkCancellation()
                guard let extracted else { throw URLError(.cannotDecodeContentData) }
                guard let self, self.requestedURL == url else { return }
                if self.cache.count >= 12, let oldest = self.cacheOrder.first {
                    self.cache.removeValue(forKey: oldest); self.cacheOrder.removeFirst()
                }
                self.cache[url] = extracted; self.cacheOrder.append(url)
                self.palette = extracted; self.hasArtworkColors = true; self.loading = false
            } catch {
                guard !Task.isCancelled, let self, self.requestedURL == url else { return }
                self.palette = .neutral; self.hasArtworkColors = false; self.loading = false
            }
        }
    }
}

struct VerseAlbumField: View {
    let palette: VerseAlbumPalette
    let strength: Double
    let flowing: Bool
    @Environment(\.scenePhase) private var phase
    @State private var frozenTime = Date().timeIntervalSinceReferenceDate
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !flowing || phase != .active)) { timeline in
            let time = flowing && phase == .active ? timeline.date.timeIntervalSinceReferenceDate : frozenTime
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let anchors: [(Double, Double)] = [(0.12, 0.15), (0.9, 0.4), (0.3, 0.95), (0.75, 0.1)]
                for index in anchors.indices {
                    let anchor = anchors[index]
                    let x = anchor.0 + sin(time / (12 + Double(index) * 3) + Double(index)) * 0.19
                    let y = anchor.1 + cos(time / (16 + Double(index) * 2) + Double(index) * 1.7) * 0.16
                    let center = CGPoint(x: size.width * x, y: size.height * y)
                    let source = palette.colors[index % palette.colors.count]
                    let scale = min(1, 0.75 / max(0.001, source.red, source.green, source.blue))
                    let color = Color(red: source.red * scale, green: source.green * scale, blue: source.blue * scale)
                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(strength * 0.9), location: 0),
                        .init(color: color.opacity(strength * 0.45), location: 0.45),
                        .init(color: .clear, location: 1)
                    ])
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(gradient,
                        center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.8))
                }
            }
        }
        .onChange(of: flowing) { _, value in if !value { frozenTime = Date().timeIntervalSinceReferenceDate } }
        .onChange(of: phase) { _, value in if value != .active { frozenTime = Date().timeIntervalSinceReferenceDate } }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
