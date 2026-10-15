import XCTest
@testable import VerseCore

private final class LyricsStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class LyricsClientTests: XCTestCase {
    private let track = Track(id: "original", title: "最後是我開了口", artist: "小賤", album: "原专辑", duration: 235)
    private func session(_ handler: @escaping (URLRequest) throws -> (Int, [String: String], Data)) -> URLSession {
        LyricsStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LyricsStub.self]
        return URLSession(configuration: configuration)
    }
    private func body(_ value: Any) -> Data { try! JSONSerialization.data(withJSONObject: value) }
    private func record(title: String = "最后是我开了口", artist: String = "小贱", timed: Bool = true) -> [String: Any] {
        ["id": 1, "trackName": title, "artistName": artist, "albumName": "精选集", "duration": 241,
         "instrumental": false, "plainLyrics": "测试原创一\n测试原创二", "syncedLyrics": timed ? "[00:01]测试原创一\n[00:05]测试原创二" : ""]
    }
    func testSearchAcceptsTraditionalNamesAndReissueWithVisibleDurationNote() async throws {
        let client = LyricsClient(session: session { request in
            XCTAssertEqual(request.url?.path, "/api/search")
            return (200, [:], self.body([self.record()]))
        })
        let result = try await client.lookup(for: track)
        XCTAssertEqual(result.document?.source, "LRCLIB")
        XCTAssertEqual(result.document?.lines.count, 2)
        XCTAssertNotNil(result.document?.matchNote)
        XCTAssertEqual(result.attempts.count, 1)
    }
    func testServerFailureFallsThroughToQQWithOptInTranslation() async throws {
        let client = LyricsClient(session: session { request in
            if request.url?.host == "lrclib.net" { return (503, [:], Data()) }
            if request.url?.path.contains("client_search") == true {
                return (200, [:], self.body(["code":0,"data":["song":["list":[
                    ["songmid":"test-mid","songname":"最后是我开了口","albumname":"原专辑","interval":235,"singer":[["name":"小贱"]]]
                ]]]]))
            }
            XCTAssertTrue(request.url?.path.contains("fcg_query_lyric") == true)
            return (200, [:], self.body(["retcode":0,"lyric":"[00&#58;01]原创 &amp; 测试\n[00:05]第二句","trans":"[00:01]Original test"]))
        })
        let result = try await client.lookup(for: track)
        XCTAssertEqual(result.attempts.map(\.outcome), ["unavailable", "matched"])
        XCTAssertEqual(result.document?.source, "QQ 音乐")
        XCTAssertEqual(result.document?.lines.first?.text, "原创 & 测试")
    }
    func testPlainLRCLIBContinuesToSynchronizedBackup() async throws {
        let client = LyricsClient(session: session { request in
            if request.url?.host == "lrclib.net" { return (200, [:], self.body([self.record(timed:false)])) }
            if request.url?.path.contains("client_search") == true {
                return (200, [:], self.body(["code":0,"data":["song":["list":[
                    ["songmid":"test-mid","songname":"最后是我开了口","interval":235,"singer":[["name":"小贱"]]]
                ]]]]))
            }
            return (200, [:], self.body(["retcode":0,"lyric":"[00:01]原创同步测试"]))
        })
        let result = try await client.lookup(for: track)
        XCTAssertEqual(result.attempts.map(\.outcome), ["plain", "matched"])
        XCTAssertEqual(result.document?.source, "QQ 音乐")
    }
    func testNotFoundAcrossSourcesIsNotAnOutage() async throws {
        let client = LyricsClient(session: session { _ in (404, [:], Data()) })
        let result = try await client.lookup(for: track)
        XCTAssertNil(result.document)
        XCTAssertEqual(result.attempts.map(\.outcome), ["notFound", "notFound", "notFound", "notFound"])
    }
    func testManualSourceChoiceDoesNotContactUnselectedProviders() async throws {
        let client = LyricsClient(session: session { request in
            XCTAssertEqual(request.url?.host, "api.lyrics.ovh")
            return (404, [:], Data())
        })
        let result = try await client.lookup(for: track, providers: LyricsProviderChoice.lyricsOVH.providers)
        XCTAssertNil(result.document)
        XCTAssertEqual(result.attempts.map(\.provider), [.lyricsOVH])
    }
    func testNetEaseUsesVerifiedArtistAliasesAndRejectsCovers() async throws {
        let song = Track(id: "test", title: "十年", artist: "Eason Chan", album: "黑白灰", duration: 205.4)
        let client = LyricsClient(session: session { request in
            XCTAssertEqual(request.url?.host, "music.163.com")
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if request.url?.path.contains("cloudsearch") == true {
                return (200, [:], self.body(["code":200,"result":["songs":[
                    ["id":1,"name":"十年","dt":205400,"al":["name":"黑白灰"],"ar":[["name":"翻唱歌手"]]],
                    ["id":2,"name":"十年","dt":205423,"al":["name":"黑白灰"],"ar":[["name":"陈奕迅","alias":["Eason Chan"]]]]
                ]]]))
            }
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value, "2")
            return (200, [:], self.body(["code":200,"lrc":["lyric":"[00:01]原创测试词"],"tlyric":["lyric":"[00:01]Do not show without consent"]]))
        })
        let result = try await client.lookup(for: song, providers: [.netEase])
        XCTAssertEqual(result.document?.source, "网易云音乐")
        XCTAssertEqual(result.document?.lines.first?.text, "原创测试词")
        XCTAssertEqual(result.document?.sourceURL?.absoluteString, "https://music.163.com/song?id=2")
        XCTAssertEqual(result.attempts.map(\.provider), [.netEase])
    }
    func testNetEaseServiceFailureFallsThrough() async throws {
        let client = LyricsClient(session: session { request in
            if request.url?.host == "music.163.com" { return (200, [:], self.body(["code":-460])) }
            return (200, [:], self.body(["lyrics":"原创备用词"]))
        }, providers: [.netEase, .lyricsOVH])
        let result = try await client.lookup(for: track)
        XCTAssertEqual(result.attempts.map(\.outcome), ["unavailable", "plain"])
        XCTAssertEqual(result.document?.source, "lyrics.ovh")
    }
    func testNetEaseMissingLyricsDoesNotMislabelSongAsInstrumental() async throws {
        let client = LyricsClient(session: session { request in
            if request.url?.path.contains("cloudsearch") == true {
                return (200, [:], self.body(["code":200,"result":["songs":[
                    ["id":1,"name":"最后是我开了口","dt":235000,"al":["name":"原专辑"],"ar":[["name":"小贱"]]]
                ]]]))
            }
            return (200, [:], self.body(["code":200,"nolyric":true]))
        }, providers: [.netEase])
        let result = try await client.lookup(for: track)
        XCTAssertNil(result.document)
        XCTAssertEqual(result.attempts.map(\.outcome), ["notFound"])
    }
    func testRetryAfterRetainedAcrossTracksWhileBackupStillWorks() async throws {
        var primaryCalls = 0
        let client = LyricsClient(session: session { request in
            if request.url?.host == "lrclib.net" { primaryCalls += 1; return (429, ["Retry-After":"60"], Data()) }
            return (200, [:], self.body(["lyrics":"原创纯文本，不附会时间轴"]))
        }, providers: [.lrclib, .lyricsOVH])
        for _ in 0..<2 {
            let result = try await client.lookup(for: track)
            XCTAssertEqual(result.document?.source, "lyrics.ovh")
            XCTAssertTrue(result.document!.lines.isEmpty)
        }
        XCTAssertEqual(primaryCalls, 1)
    }
    func testMalformedSourceDoesNotStopPlainTextFallback() async throws {
        let client = LyricsClient(session: session { request in
            if request.url?.host == "lrclib.net" { return (200, [:], Data("{broken".utf8)) }
            return (200, [:], self.body(["lyrics":"[00:03]纯文本服务返回的字面内容"]))
        }, providers: [.lrclib, .lyricsOVH])
        let result = try await client.lookup(for: track)
        XCTAssertEqual(result.attempts.first?.outcome, "unavailable")
        XCTAssertTrue(result.document!.lines.isEmpty)
    }
    func testMatchingRejectsCoverLiveRemixAndLongerEdit() {
        XCTAssertNil(LyricsMatching.match(track,title:track.title,artists:["其他歌手"],album:"",duration:235))
        XCTAssertNil(LyricsMatching.match(track,title:track.title+" (Live)",artists:[track.artist],album:"",duration:235))
        XCTAssertNil(LyricsMatching.match(track,title:track.title,artists:[track.artist],album:"Live 2026",duration:235))
        XCTAssertNil(LyricsMatching.match(track,title:track.title,artists:[track.artist],album:"",duration:260))
        XCTAssertNotNil(LyricsMatching.match(track,title:"最后是我开了口",artists:["小贱"],album:"精选",duration:235))
    }
    func testSoundtrackTitleAndVerifiedForeignArtistAlias() async throws {
        let value = Track(id:"test",title:"小幸運 - 電影《我的少女時代》主題曲",artist:"Hebe Tien",album:"小幸運",duration:259)
        let client = LyricsClient(session: session { request in
            if request.url?.path.contains("client_search") == true {
                return (200, [:], self.body(["code":0,"data":["song":["list":[
                    ["songmid":"test-mid","songname":"小幸运","interval":263,"singer":[["name":"田馥甄","mid":"singer-mid"]]]
                ]]]]))
            }
            if request.url?.host == "u.y.qq.com" {
                return (200, [:], self.body(["code":0,"singer":["code":0,"data":["singer_list":[
                    ["basic_info":["name":"田馥甄"],"ex_info":["foreign_name":"Hebe Tien"]]
                ]]]]))
            }
            return (200, [:], self.body(["retcode":0,"lyric":"[00:01]原创别名测试"]))
        },providers:[.qqMusic])
        let result = try await client.lookup(for:value)
        XCTAssertEqual(result.document?.source,"QQ 音乐")
        XCTAssertEqual(result.document?.lines.count,1)
        XCTAssertNotNil(result.document?.matchNote)
    }
    func testCancellationStopsBeforeAnotherSourceIsContacted() async throws {
        var calls = 0
        let client = LyricsClient(session: session { _ in calls += 1; throw URLError(.cancelled) })
        do { _ = try await client.lookup(for: track); XCTFail("Cancellation must propagate") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(calls, 1)
    }
    func testOVHPathSegmentsCannotInjectQueryOrFragment() async throws {
        let value = Track(id:"test",title:"Song / ?#%",artist:"Artist / Pair",album:"",duration:100)
        let client = LyricsClient(session: session { request in
            XCTAssertNil(request.url?.query); XCTAssertNil(request.url?.fragment)
            XCTAssertTrue(request.url!.absoluteString.contains("%2F"))
            XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
            XCTAssertFalse(request.httpShouldHandleCookies)
            return (200, [:], self.body(["lyrics":"Original test text"]))
        }, providers:[.lyricsOVH])
        let result = try await client.lookup(for:value)
        XCTAssertEqual(result.document?.plainText,"Original test text")
    }
    func testOldCachedDocumentsRemainDecodable() throws {
        let old = body(["lines":[],"plainText":"原创","source":"本地 LRC","instrumental":false])
        let result = try JSONDecoder().decode(LyricDocument.self, from: old)
        XCTAssertNil(result.sourceURL); XCTAssertNil(result.matchNote)
    }
    func testMarqueeScrollsWrapsAndPreservesGraphemes() {
        let line = "一二三四五六七八九十"
        XCTAssertEqual(LyricMarquee.text(line,width:4,elapsed:0),"一二三四")
        XCTAssertEqual(LyricMarquee.text(line,width:4,elapsed:1.6),"二三四五")
        XCTAssertEqual(LyricMarquee.text(line,width:4,elapsed:1.2 + 13 * 0.32 + 0.01),"一二三四")
        XCTAssertEqual(LyricMarquee.text(line,width:4,elapsed:10,enabled:false),"一二三…")
        XCTAssertEqual(LyricMarquee.text("短句",width:4,elapsed:99),"短句")
        XCTAssertEqual(LyricMarquee.text("👨‍👩‍👧‍👦春夏秋冬",width:2,elapsed:0),"👨‍👩‍👧‍👦春")
    }
}
