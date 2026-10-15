import XCTest
@testable import VerseCore

private final class SpotifyTestNetwork: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class SpotifyLyricsTests: XCTestCase {
    private let track = Track(id: "1234567890abcdefghijkl", title: "原创测试", artist: "VerseDock", album: "原创", duration: 120)
    private func json(_ body: Any) -> Data { try! JSONSerialization.data(withJSONObject: body) }
    private func session(_ handler: @escaping (URLRequest) throws -> (Int, Data)) -> URLSession {
        SpotifyTestNetwork.handler = handler
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [SpotifyTestNetwork.self]
        return URLSession(configuration: configuration)
    }
    private var playing: Data {
        json(["progress_ms":12000,"is_playing":true,"currently_playing_type":"track","item":[
            "id":track.id,"name":track.title,"type":"track","duration_ms":120000,"artists":[["name":track.artist]]]])
    }
    func testSpotifyResponsePreservesTimedGroupsAndProviderAttribution() throws {
        let document = try SpotifyLyrics.parse(json(["lyrics":["syncType":"LINE_SYNCED","providerDisplayName":"测试提供方","lines":[
            ["startTimeMs":"5000","words":"原创第二句"],["startTimeMs":"1000","words":"原创第一句"],
            ["startTimeMs":"1000","words":"同时间内容"],["startTimeMs":"6000","words":""]]]]),track:track)
        XCTAssertEqual(document?.source,"Spotify")
        XCTAssertEqual(document?.lines.map(\.time),[1,5,6])
        XCTAssertEqual(document?.lines.first?.text,"原创第一句\n同时间内容")
        XCTAssertEqual(document?.sourceURL,track.spotifyURL)
    }
    func testSpotifyPlainTextHasNoInventedTimeline() throws {
        let document = try SpotifyLyrics.parse(json(["lyrics":["syncType":"UNSYNCED","lines":[
            ["startTimeMs":"0","words":"Original first line"],["startTimeMs":"0","words":"Original second line"]]]]),track:track)
        XCTAssertTrue(document!.lines.isEmpty)
        XCTAssertEqual(document?.plainText,"Original first line\nOriginal second line")
    }
    func testMissingAndMalformedSpotifyDataRemainDifferent() throws {
        XCTAssertNil(try SpotifyLyrics.parse(json(["showLyrics":false]),track:track))
        XCTAssertThrowsError(try SpotifyLyrics.parse(json([:]),track:track))
        XCTAssertThrowsError(try SpotifyLyrics.parse(json(["lyrics":["syncType":"LINE_SYNCED","lines":[["startTimeMs":"NaN","words":"原创"]]]]),track:track))
    }
    func testSpotifyOriginalWinsEvenWithManualBackupSelected() async throws {
        let client = LyricsClient(session: session { _ in XCTFail("Backup must not be contacted"); return (500,Data()) })
        let result = try await client.lookup(for:track,providers:[.qqMusic],spotify:{ _ in
            LyricDocument(lines:[.init(id:0,time:1,text:"原创第一句")],source:"Spotify")
        })
        XCTAssertEqual(result.document?.source,"Spotify"); XCTAssertEqual(result.attempts.map(\.provider),[.spotify])
    }
    func testSpotifyPlainOriginalWinsOverTimedBackup() async throws {
        let client = LyricsClient(session: session { _ in XCTFail("Spotify's plain lyrics still have priority"); return (500,Data()) })
        let result = try await client.lookup(for:track,spotify:{ _ in .init(lines:[],plainText:"原创纯文本",source:"Spotify") })
        XCTAssertEqual(result.document?.source,"Spotify"); XCTAssertEqual(result.attempts.map(\.outcome),["plain"])
    }
    func testMissingSpotifyUsesOnlySelectedBackup() async throws {
        let client = LyricsClient(session:session { request in
            XCTAssertEqual(request.url?.host,"api.lyrics.ovh"); XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
            return (200,self.json(["lyrics":"原创备用词"]))
        })
        let result = try await client.lookup(for:track,providers:[.lyricsOVH],spotify:{ _ in nil })
        XCTAssertEqual(result.attempts.map(\.provider),[.spotify,.lyricsOVH])
        XCTAssertEqual(result.attempts.map(\.outcome),["notFound","plain"])
    }
    func testSpotifyAuthorizationFailureIsNotReportedAsNoLyrics() async throws {
        let client = LyricsClient(session:session { _ in (200,self.json(["lyrics":"原创备用词"])) })
        let result = try await client.lookup(for:track,providers:[.lyricsOVH],spotify:{ _ in throw VerseError.http(401) })
        XCTAssertEqual(result.attempts.first?.outcome,"unavailable"); XCTAssertEqual(result.document?.source,"lyrics.ovh")
    }
    func testCancellingSpotifyStopsBeforeBackup() async throws {
        let client = LyricsClient(session:session { _ in XCTFail("Cancelled lookup must stop"); return (500,Data()) })
        do { _ = try await client.lookup(for:track,spotify:{ _ in throw CancellationError() }); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testSeekUsesRealPlayerEndpointAndClampsEndOfSong() async throws {
        var puts = 0
        let api = SpotifyAPI(session:session { request in
            XCTAssertEqual(request.url?.host,"api.spotify.com")
            if request.httpMethod == "GET" { return (200,self.playing) }
            puts += 1
            XCTAssertEqual(request.httpMethod,"PUT"); XCTAssertEqual(request.url?.path,"/v1/me/player/seek")
            XCTAssertEqual(URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems?.first?.value,"119950")
            return (204,Data())
        })
        try await api.seek(to:999,track:track,accessToken:"test-fixture-token")
        XCTAssertEqual(puts,1)
    }
    func testSeekRejectsChangedSongWithoutSendingControl() async throws {
        let api = SpotifyAPI(session:session { request in
            XCTAssertEqual(request.httpMethod,"GET")
            return (200,self.json(["progress_ms":1,"is_playing":true,"currently_playing_type":"track","item":[
                "id":"other","name":"Other","type":"track","duration_ms":120000]]))
        })
        do { try await api.seek(to:10,track:track,accessToken:"test-fixture-token");XCTFail("Changed song must not seek") }
        catch { XCTAssertTrue(error is VerseError) }
    }
    func testClickInvertsAdjustmentAndProtectsBoundaries() throws {
        let document = LRCParser.parse("[00:01]原创第一句\n[00:20]原创第二句\n[02:00]结尾")
        XCTAssertEqual(try PlaybackSeeking.position(for:document.lines[1],document:document,duration:120,adjustment:2),18)
        XCTAssertEqual(try PlaybackSeeking.position(for:document.lines[0],document:document,duration:120,adjustment:2),0)
        XCTAssertEqual(try PlaybackSeeking.position(for:document.lines[2],document:document,duration:120,adjustment:0),119.95)
        XCTAssertThrowsError(try PlaybackSeeking.position(for:.init(id:999,time:20,text:"过期歌词"),document:document,duration:120,adjustment:0))
        XCTAssertThrowsError(try PlaybackSeeking.milliseconds(.nan,duration:120))
        XCTAssertThrowsError(try PlaybackSeeking.milliseconds(1,duration:.infinity))
    }
}
