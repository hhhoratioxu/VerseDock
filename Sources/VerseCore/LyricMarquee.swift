import Foundation

public enum LyricMarquee {
    /// Scroll by extended grapheme clusters so emoji and combining marks are never split.
    public static func text(_ text: String, width: Int, elapsed: TimeInterval, enabled: Bool = true) -> String {
        let characters = Array(text.replacingOccurrences(of: "\n", with: " · "))
        let width = max(1, min(width, 80))
        guard characters.count > width else { return String(characters) }
        guard enabled else { return String(characters.prefix(width - 1)) + "…" }
        let ribbon = characters + Array("   ")
        let safeTime = elapsed.isFinite ? max(0, elapsed - 1.2) : 0
        let offset = Int((safeTime / 0.32).truncatingRemainder(dividingBy: Double(ribbon.count)))
        return String((0..<width).map { ribbon[(offset + $0) % ribbon.count] })
    }
}
