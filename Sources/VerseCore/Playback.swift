import Foundation

public struct Track: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let artworkURL: URL?
    public init(id: String, title: String, artist: String, album: String,
                duration: Double, artworkURL: URL? = nil) {
        self.id = id; self.title = title; self.artist = artist; self.album = album
        self.duration = max(0, duration); self.artworkURL = artworkURL
    }
    public var spotifyURL: URL? {
        let prefix = "spotify:track:"
        let value = id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : id
        guard value.count == 22, value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return URL(string: "https://open.spotify.com/track/\(value)")
    }
}

public struct PlaybackSnapshot: Equatable, Sendable {
    public let track: Track
    public let position: Double
    public let isPlaying: Bool
    public let receivedAt: Date
    public init(track: Track, position: Double, isPlaying: Bool, receivedAt: Date = Date()) {
        self.track = track; self.position = max(0, position)
        self.isPlaying = isPlaying; self.receivedAt = receivedAt
    }
    public func progress(at date: Date) -> Double {
        min(track.duration, max(0, position + (isPlaying ? max(0, date.timeIntervalSince(receivedAt)) : 0)))
    }
}

public struct SpotifyEnvelope: Decodable {
    public let progress_ms: Double?
    public let is_playing: Bool
    public let currently_playing_type: String?
    public let item: Item?
    public struct Item: Decodable {
        public let id: String?
        public let name: String
        public let type: String?
        public let duration_ms: Double
        public let artists: [Artist]?
        public let album: Album?
        public struct Artist: Decodable { public let name: String }
        public struct Album: Decodable {
            public let name: String
            public let images: [Artwork]?
            public struct Artwork: Decodable { public let url: URL }
        }
    }
    public func snapshot(at date: Date = Date()) -> PlaybackSnapshot? {
        guard currently_playing_type == "track", let item, item.type == "track",
              let id = item.id else { return nil }
        return PlaybackSnapshot(track: Track(id: id, title: item.name,
            artist: (item.artists ?? []).map(\.name).joined(separator: ", "),
            album: item.album?.name ?? "", duration: item.duration_ms / 1000,
            artworkURL: item.album?.images?.first?.url), position: (progress_ms ?? 0) / 1000,
            isPlaying: is_playing, receivedAt: date)
    }
}
