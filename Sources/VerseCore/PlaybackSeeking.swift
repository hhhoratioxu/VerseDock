import Foundation

public enum PlaybackSeeking {
    public static func position(for line: LyricLine, document: LyricDocument,
                                duration: Double, adjustment: Double) throws -> Double {
        guard document.lines.contains(line), duration.isFinite, duration > 0,
              line.time.isFinite, line.time >= 0, adjustment.isFinite else {
            throw VerseError.message("这句歌词没有可用的同步时间")
        }
        // The displayed timeline uses position + adjustment; invert it when seeking.
        return min(max(0, duration - 0.05), max(0, line.time - adjustment))
    }
    public static func milliseconds(_ position: Double, duration: Double) throws -> Int {
        guard position.isFinite, duration.isFinite, duration > 0, duration < Double(Int.max) / 1000 else {
            throw VerseError.message("播放时间无效")
        }
        // Spotify advances to the next song if the requested position exceeds the duration.
        return Int(min(max(0, duration - 0.05), max(0, position)) * 1000)
    }
}
