import XCTest
@testable import VerseCore

final class LyricsTests: XCTestCase {
    func testRepeatedTimesAndBilingualGroups() {
        let result = LRCParser.parse("[ar:Original]\n[00:05.5][00:10.50]原创一句\n[00:05.50]Original line\n[00:05.50]原创一句")
        XCTAssertEqual(result.lines.count, 2)
        XCTAssertEqual(result.lines[0].time, 5.5)
        XCTAssertEqual(result.lines[0].text, "原创一句\nOriginal line")
        XCTAssertEqual(result.lines[1].time, 10.5)
    }
    func testOffsetAnywhereAndSort() {
        let result = LRCParser.parse("\u{FEFF}[00:20.123]later\n[00:02]first\n[offset:-500]\n[00:00.10]intro")
        XCTAssertEqual(result.lines.map(\.time), [0, 1.5, 19.623])
    }
    func testInvalidTimestampsDoNotBecomeLyrics() {
        let result = LRCParser.parse("[00:60]wrong\n[-1:00]wrong\n[00:nan]wrong\n[00:02.123]valid\n[ti:title]")
        XCTAssertEqual(result.lines.count, 1)
        XCTAssertEqual(result.lines[0].text, "valid")
    }
    func testTimelineBoundariesSeekAndCalibration() {
        let lyrics = LRCParser.parse("[00:05]first\n[00:10]second\n[00:12]\n[00:16]third")
        XCTAssertNil(lyrics.activeIndex(at: 4.999))
        XCTAssertEqual(lyrics.activeIndex(at: 5), 0)
        XCTAssertEqual(lyrics.activeIndex(at: 10), 1)
        XCTAssertEqual(lyrics.activeIndex(at: 12), 2)
        XCTAssertEqual(lyrics.activeIndex(at: 4.8, adjustment: 0.2), 0)
        XCTAssertEqual(lyrics.activeIndex(at: 9, adjustment: -1), 0)
        XCTAssertEqual(lyrics.activeIndex(at: 100), 3)
        XCTAssertEqual(lyrics.activeIndex(at: 6), 0)
    }
    func testPlainTextDoesNotInventTiming() {
        let result = LRCParser.parse("纯文本\n没有时间戳")
        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertEqual(result.plainText, "纯文本\n没有时间戳")
    }
    func testPlaybackPauseClampAndReceiptClock() {
        let date = Date(timeIntervalSince1970: 100)
        let track = Track(id: "demo", title: "original", artist: "test", album: "test", duration: 20)
        let playing = PlaybackSnapshot(track: track, position: 10, isPlaying: true, receivedAt: date)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(2)), 12)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(50)), 20)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(-3)), 10)
        XCTAssertEqual(PlaybackSnapshot(track: track, position: 10, isPlaying: false, receivedAt: date)
            .progress(at: date.addingTimeInterval(50)), 10)
    }
    func testPodcastsAndNullItemsIgnored() throws {
        let data = Data("{\"is_playing\":true,\"progress_ms\":900,\"currently_playing_type\":\"episode\",\"item\":{\"id\":\"x\",\"name\":\"Podcast\",\"type\":\"episode\",\"duration_ms\":9000}}".utf8)
        XCTAssertNil(try JSONDecoder().decode(SpotifyEnvelope.self, from: data).snapshot())
    }
}
