import Foundation

public enum LyricsProvider: String, Codable, CaseIterable, Sendable {
    case spotify, lrclib, qqMusic, netEase, lyricsOVH
    public static let backupProviders: [LyricsProvider] = [.lrclib, .qqMusic, .netEase, .lyricsOVH]
    public var name: String {
        switch self { case .spotify: return "Spotify"; case .lrclib: return "LRCLIB"; case .qqMusic: return "QQ 音乐"; case .netEase: return "网易云音乐"; case .lyricsOVH: return "lyrics.ovh" }
    }
}
public enum LyricsProviderChoice: String, CaseIterable, Sendable {
    case automatic, lrclib, qqMusic, netEase, lyricsOVH
    public var name: String {
        switch self {
        case .automatic: return "自动（默认）"
        case .lrclib: return "LRCLIB"
        case .qqMusic: return "QQ 音乐"
        case .netEase: return "网易云音乐"
        case .lyricsOVH: return "lyrics.ovh（纯文本）"
        }
    }
    public var providers: [LyricsProvider] {
        switch self {
        case .automatic: return LyricsProvider.backupProviders
        case .lrclib: return [.lrclib]
        case .qqMusic: return [.qqMusic]
        case .netEase: return [.netEase]
        case .lyricsOVH: return [.lyricsOVH]
        }
    }
}
public struct LyricsAttempt: Codable, Equatable, Sendable {
    public let provider: LyricsProvider
    public let outcome: String
    public let message: String
}
public struct LyricsLookup: Sendable {
    public let document: LyricDocument?
    public let attempts: [LyricsAttempt]
}

/// Anonymous service adapters written for VerseDock; no Spotify cookies or third-party lyrics SDKs.
public actor LyricsClient {
    private let session: URLSession
    private let providers: [LyricsProvider]
    private let timeout: TimeInterval
    private var nextRequest: [LyricsProvider: Date] = [:]
    private var cooldown: [LyricsProvider: Date] = [:]
    private var artistAliases: [String: [String]] = [:]
    public init(session: URLSession = .shared, providers: [LyricsProvider] = LyricsProvider.backupProviders,
                timeout: TimeInterval = 6) {
        self.session = session; self.providers = providers; self.timeout = timeout
    }
    public func fetch(for track: Track) async throws -> LyricDocument? {
        try await lookup(for: track).document
    }
    public func lookup(for track: Track, providers preferred: [LyricsProvider]? = nil,
                       spotify: (@Sendable (Track) async throws -> LyricDocument?)? = nil,
                       progress: (@Sendable (String) async -> Void)? = nil) async throws -> LyricsLookup {
        var attempts: [LyricsAttempt] = []
        var plain: LyricDocument?
        let order = (spotify == nil ? [] : [LyricsProvider.spotify]) + (preferred ?? providers).filter { $0 != .spotify }
        for provider in order {
            try Task.checkCancellation()
            await progress?("正在查找歌词 · \(provider.name)")
            do {
                let document: LyricDocument?
                switch provider {
                case .spotify:
                    guard let spotify else { throw VerseError.message("Spotify 歌词会话尚未连接") }
                    document = try await spotify(track)
                case .lrclib: document = try await lrclib(track)
                case .qqMusic: document = try await qqMusic(track)
                case .netEase: document = try await netEase(track)
                case .lyricsOVH: document = try await ovh(track)
                }
                if let document {
                    let timed = !document.lines.isEmpty || document.instrumental
                    attempts.append(LyricsAttempt(provider: provider, outcome: timed ? "matched" : "plain",
                        message: document.instrumental ? "来源标记为纯音乐" : (timed ? "已取得同步歌词" :
                            (provider == .spotify ? "Spotify 提供纯文本，无同步时间轴" : "只有纯文本，继续寻找同步歌词"))))
                    if timed || provider == .spotify { return LyricsLookup(document: document, attempts: attempts) }
                    if plain == nil { plain = document }
                } else {
                    attempts.append(LyricsAttempt(provider: provider, outcome: "notFound", message: "没有匹配的歌词"))
                }
            } catch {
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
                attempts.append(LyricsAttempt(provider: provider, outcome: "unavailable", message: error.localizedDescription))
            }
        }
        try Task.checkCancellation()
        return LyricsLookup(document: plain, attempts: attempts)
    }
    private func request<T: Decodable>(_ provider: LyricsProvider, _ base: String,
                                        _ items: [URLQueryItem] = []) async throws -> T? {
        if let until = cooldown[provider], until > Date() {
            throw VerseError.message("该来源仍在限流，暂时跳过")
        }
        if let next = nextRequest[provider] {
            let wait = next.timeIntervalSinceNow
            if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        }
        try Task.checkCancellation()
        nextRequest[provider] = Date().addingTimeInterval(0.3)
        var parts = URLComponents(string: base)!
        if !items.isEmpty { parts.queryItems = items }
        var request = URLRequest(url: parts.url!)
        request.timeoutInterval = timeout
        request.httpShouldHandleCookies = false
        request.setValue("VerseDock/0.1.6 (https://github.com/hhhoratioxu/VerseDock)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if provider == .qqMusic { request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer") }
        if provider == .netEase { request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw VerseError.message("歌词服务响应无效") }
        if response.statusCode == 404 { return nil }
        if response.statusCode == 429 {
            let header = response.value(forHTTPHeaderField: "Retry-After") ?? ""
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            let raw = Double(header) ?? formatter.date(from: header)?.timeIntervalSinceNow ?? 60
            let seconds = raw.isFinite ? max(1, raw) : 60
            cooldown[provider] = Date().addingTimeInterval(seconds)
            throw VerseError.message("服务限流，已按 Retry-After 暂停该来源")
        }
        guard (200..<300).contains(response.statusCode) else { throw VerseError.http(response.statusCode) }
        guard data.count < 2_000_000 else { throw VerseError.message("歌词响应过大") }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private struct LRCRecord: Decodable {
        let id: Int; let trackName: String; let artistName: String; let albumName: String?
        let duration: Double; let instrumental: Bool; let plainLyrics: String?; let syncedLyrics: String?
    }
    private func lrclib(_ track: Track) async throws -> LyricDocument? {
        let title = LyricsMatching.title(track.title)
        let queries = [[URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: track.artist)],
                       [URLQueryItem(name: "track_name", value: LyricsMatching.simplify(title))]]
        var plain: LyricDocument?
        for query in queries {
            let records: [LRCRecord] = try await request(.lrclib, "https://lrclib.net/api/search", query) ?? []
            let candidates = records.compactMap { record -> (LRCRecord, LyricsMatch)? in
                guard let match = LyricsMatching.match(track, title: record.trackName, artists: [record.artistName],
                    album: record.albumName ?? "", duration: record.duration) else { return nil }
                return (record, match)
            }.sorted { $0.1.score > $1.1.score }
            for (record, match) in candidates {
                let parsed = LRCParser.parse(record.syncedLyrics ?? "", source: "LRCLIB")
                let text = (record.plainLyrics ?? parsed.plainText).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !parsed.lines.isEmpty || !text.isEmpty || record.instrumental else { continue }
                let document = LyricDocument(lines: parsed.lines, plainText: text, source: "LRCLIB",
                    instrumental: record.instrumental, sourceURL: URL(string: "https://lrclib.net/api/get/\(record.id)"), matchNote: match.note)
                if !document.lines.isEmpty || document.instrumental { return document }
                if plain == nil { plain = document }
            }
            if plain != nil { return plain }
        }
        return plain
    }
    private struct QQSearch: Decodable {
        let code: Int
        let data: SearchData?
        struct SearchData: Decodable { let song: Songs? }
        struct Songs: Decodable { let list: [Song]? }
        struct Song: Decodable {
            let songmid: String; let songname: String; let albumname: String?; let interval: Double
            let singer: [Artist]
            struct Artist: Decodable { let name: String; let mid: String? }
        }
    }
    private struct QQLyrics: Decodable {
        let retcode: Int?; let code: Int?; let lyric: String?; let trans: String?
    }
    private struct QQSingerInfo: Decodable {
        let code: Int; let singer: Block?
        struct Block: Decodable { let code: Int; let data: SingerData? }
        struct SingerData: Decodable { let singer_list: [Singer]? }
        struct Singer: Decodable { let basic_info: Basic?; let ex_info: Extra? }
        struct Basic: Decodable { let name: String? }
        struct Extra: Decodable { let foreign_name: String? }
    }
    private func qqAliases(_ mid: String) async throws -> [String] {
        if let cached = artistAliases[mid] { return cached }
        let payload: [String: Any] = ["comm": ["ct": 24, "cv": 0], "singer": [
            "module": "music.musichallSinger.SingerInfoInter", "method": "GetSingerDetail",
            "param": ["singer_mids": [mid], "ex_singer": 1]]]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let response: QQSingerInfo? = try await request(.qqMusic, "https://u.y.qq.com/cgi-bin/musicu.fcg", [
            URLQueryItem(name: "data", value: String(data: data, encoding: .utf8)!)])
        guard let response, response.code == 0, response.singer?.code == 0 else {
            throw VerseError.message("QQ 音乐歌手别名查询暂不可用")
        }
        let names = (response.singer?.data?.singer_list ?? []).flatMap {
            [$0.basic_info?.name, $0.ex_info?.foreign_name].compactMap { $0 }.filter { !$0.isEmpty }
        }
        artistAliases[mid] = names
        return names
    }
    private func qqMusic(_ track: Track) async throws -> LyricDocument? {
        let query = LyricsMatching.simplify(LyricsMatching.title(track.title) + " " + track.artist)
        let result: QQSearch? = try await request(.qqMusic, "https://c.y.qq.com/soso/fcgi-bin/client_search_cp", [
            URLQueryItem(name: "w", value: query), URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "n", value: "10"), URLQueryItem(name: "p", value: "1"), URLQueryItem(name: "t", value: "0")])
        guard let result else { return nil }
        guard result.code == 0 else { throw VerseError.message("QQ 音乐搜索暂不可用（\(result.code)）") }
        let candidates = (result.data?.song?.list ?? []).compactMap { song -> (QQSearch.Song, LyricsMatch)? in
            // First filter title, version and duration; verify every singer before requesting lyrics.
            guard let match = LyricsMatching.match(track, title: song.songname, artists: [track.artist],
                album: song.albumname ?? "", duration: song.interval) else { return nil }
            return (song, match)
        }.sorted { $0.1.score > $1.1.score }
        var plain: LyricDocument?
        let wanted = LyricsMatching.artists([track.artist])
        for (song, _) in candidates.prefix(3) {
            var names: [String] = []
            for singer in song.singer.prefix(4) {
                if wanted.contains(LyricsMatching.normalize(singer.name)) { names.append(singer.name) }
                else if let mid = singer.mid {
                    let aliases = try await qqAliases(mid)
                    names.append(aliases.first(where: { wanted.contains(LyricsMatching.normalize($0)) }) ?? singer.name)
                } else { names.append(singer.name) }
            }
            guard let match = LyricsMatching.match(track, title: song.songname, artists: names,
                album: song.albumname ?? "", duration: song.interval) else { continue }
            let response: QQLyrics? = try await request(.qqMusic, "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg", [
                URLQueryItem(name: "songmid", value: song.songmid), URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "nobase64", value: "1"), URLQueryItem(name: "g_tk", value: "5381")])
            guard let response else { continue }
            guard (response.retcode ?? response.code ?? -1) == 0 else {
                throw VerseError.message("QQ 音乐歌词暂不可用（\(response.retcode ?? response.code ?? -1)）")
            }
            let original = LyricsMatching.decodeEntities(response.lyric ?? "")
            // Translation is opt-in and has its own target language; never mix it into the original line.
            let parsed = LRCParser.parse(original, source: "QQ 音乐")
            guard !parsed.lines.isEmpty || !parsed.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let document = LyricDocument(lines: parsed.lines, plainText: parsed.plainText, source: "QQ 音乐",
                sourceURL: URL(string: "https://y.qq.com/n/ryqq/songDetail/\(song.songmid)"), matchNote: match.note)
            if !document.lines.isEmpty { return document }
            if plain == nil { plain = document }
        }
        return plain
    }
    private struct NetEaseSearch: Decodable {
        let code: Int
        let result: Result?
        struct Result: Decodable { let songs: [Song]? }
        struct Song: Decodable {
            let id: Int; let name: String; let dt: Double; let ar: [Artist]; let al: Album
            struct Album: Decodable { let name: String }
            struct Artist: Decodable {
                let name: String; let alias: [String]?; let alia: [String]?; let tns: [String]?
                var names: [String] { [name] + (alias ?? []) + (alia ?? []) + (tns ?? []) }
            }
        }
    }
    private struct NetEaseLyrics: Decodable {
        let code: Int; let lrc: Block?; let nolyric: Bool?
        struct Block: Decodable { let lyric: String? }
    }
    private func netEase(_ track: Track) async throws -> LyricDocument? {
        let title = LyricsMatching.simplify(LyricsMatching.title(track.title))
        let wanted = LyricsMatching.artists([track.artist])
        var tried = Set<Int>()
        var plain: LyricDocument?
        for query in [title + " " + LyricsMatching.simplify(track.artist), title] {
            let response: NetEaseSearch? = try await request(.netEase, "https://music.163.com/api/cloudsearch/pc", [
                URLQueryItem(name: "s", value: query), URLQueryItem(name: "type", value: "1"),
                URLQueryItem(name: "limit", value: "15"), URLQueryItem(name: "offset", value: "0")])
            guard let response else { continue }
            guard response.code == 200 else { throw VerseError.message("网易云搜索暂不可用（\(response.code)）") }
            let candidates = (response.result?.songs ?? []).compactMap { song -> (NetEaseSearch.Song, LyricsMatch)? in
                let artists = song.ar.map { artist in
                    artist.names.first(where: { wanted.contains(LyricsMatching.normalize($0)) }) ?? artist.name
                }
                guard let match = LyricsMatching.match(track, title: song.name, artists: artists,
                    album: song.al.name, duration: song.dt / 1000) else { return nil }
                return (song, match)
            }.sorted { $0.1.score > $1.1.score }
            for (song, match) in candidates.prefix(3) where tried.insert(song.id).inserted {
                let result: NetEaseLyrics? = try await request(.netEase, "https://music.163.com/api/song/lyric", [
                    URLQueryItem(name: "id", value: String(song.id)), URLQueryItem(name: "lv", value: "-1"),
                    URLQueryItem(name: "kv", value: "-1"), URLQueryItem(name: "tv", value: "-1")])
                guard let result else { continue }
                guard result.code == 200 else { throw VerseError.message("网易云歌词暂不可用（\(result.code)）") }
                let parsed = LRCParser.parse(result.lrc?.lyric ?? "", source: "网易云音乐")
                // "No lyrics" alone is not proof that a recording is instrumental.
                guard !parsed.lines.isEmpty || !parsed.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let document = LyricDocument(lines: parsed.lines, plainText: parsed.plainText, source: "网易云音乐",
                    sourceURL: URL(string: "https://music.163.com/song?id=\(song.id)"), matchNote: match.note)
                if !document.lines.isEmpty || document.instrumental { return document }
                if plain == nil { plain = document }
            }
            if plain != nil { return plain }
        }
        return plain
    }
    private struct OVHLyrics: Decodable { let lyrics: String? }
    private func ovh(_ track: Track) async throws -> LyricDocument? {
        // This source supplies plain text only: never manufacture timestamps for it.
        var allowed = CharacterSet.urlPathAllowed; allowed.remove(charactersIn: "/?#%")
        guard let artist = track.artist.addingPercentEncoding(withAllowedCharacters: allowed),
              let title = track.title.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        let response: OVHLyrics? = try await request(.lyricsOVH, "https://api.lyrics.ovh/v1/\(artist)/\(title)")
        guard let text = response?.lyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return LyricDocument(lines: [], plainText: text, source: "lyrics.ovh", sourceURL: URL(string: "https://lyrics.ovh"))
    }
}
