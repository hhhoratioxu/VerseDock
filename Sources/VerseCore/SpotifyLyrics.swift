import Foundation

/// Decode Spotify's own web-player response. This parser never treats an HTTP authentication error as "no lyrics".
public enum SpotifyLyrics {
    private struct Envelope: Decodable {
        let lyrics: Lyrics?
        let showLyrics: Bool?
        struct Lyrics: Decodable {
            let syncType: String
            let lines: [Line]
            let providerDisplayName: String?
            struct Line: Decodable { let startTimeMs: String?; let words: String }
        }
    }
    public static func parse(_ data: Data, track: Track) throws -> LyricDocument? {
        guard data.count < 2_000_000, track.spotifyURL != nil else { throw VerseError.message("Spotify 歌词数据无效") }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if envelope.showLyrics == false { return nil }
        guard let value = envelope.lyrics else { throw VerseError.message("Spotify 歌词响应缺少内容") }
        guard value.lines.count <= 5_000 else { throw VerseError.message("Spotify 歌词行数过多") }
        let plain = value.lines.map(\.words).joined(separator: "\n")
        guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let synchronized = ["LINE_SYNCED", "SYLLABLE_SYNCED"].contains(value.syncType)
        var rows: [(Double, String, Int)] = []
        if synchronized {
            for (index, line) in value.lines.enumerated() {
                guard let text = line.startTimeMs, let milliseconds = Double(text), milliseconds.isFinite,
                      milliseconds >= 0, milliseconds < 86_400_000 else {
                    throw VerseError.message("Spotify 歌词时间戳无效")
                }
                rows.append((milliseconds / 1000, line.words, index))
            }
        }
        rows.sort { $0.0 == $1.0 ? $0.2 < $1.2 : $0.0 < $1.0 }
        var lines: [LyricLine] = []
        for (time, text, _) in rows {
            if let previous = lines.last, previous.time == time {
                if !text.isEmpty, !previous.text.components(separatedBy: "\n").contains(text) {
                    lines[lines.count - 1] = .init(id: previous.id, time: time,
                        text: previous.text.isEmpty ? text : previous.text + "\n" + text)
                }
            } else { lines.append(.init(id: lines.count, time: time, text: text)) }
        }
        return LyricDocument(lines: lines, plainText: plain, source: "Spotify", sourceURL: track.spotifyURL,
            matchNote: value.providerDisplayName.map { "原词提供方：" + String($0.prefix(100)) })
    }
}
