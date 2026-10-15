import Foundation

public struct LyricsClient: Sendable {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    /// Exact metadata lookup only. Never silently substitute a different recording.
    public func fetch(for track: Track) async throws -> LyricDocument? {
        var url = URLComponents(string: "https://lrclib.net/api/get")!
        url.queryItems = [URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 15
        request.setValue("VerseDock/0.1 (personal lyrics companion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try SpotifyAPI.validate(response)
        guard data.count < 2_000_000 else { throw VerseError.message("歌词响应过大") }
        struct Record: Decodable {
            let trackName: String; let artistName: String; let duration: Double
            let instrumental: Bool; let plainLyrics: String?; let syncedLyrics: String?
        }
        let record = try JSONDecoder().decode(Record.self, from: data)
        func normalize(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard normalize(record.trackName) == normalize(track.title),
              normalize(record.artistName) == normalize(track.artist),
              abs(record.duration - track.duration) <= 3 else { return nil }
        if record.instrumental {
            return LyricDocument(lines: [], source: "LRCLIB", instrumental: true)
        }
        let parsed = LRCParser.parse(record.syncedLyrics ?? "", source: "LRCLIB")
        guard !parsed.lines.isEmpty || !(record.plainLyrics ?? "").isEmpty else { return nil }
        return LyricDocument(lines: parsed.lines, plainText: record.plainLyrics ?? parsed.plainText, source: "LRCLIB")
    }
}
