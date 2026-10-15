import XCTest
@testable import VerseCore

final class LyricTranslationTests: XCTestCase {
    func testRepeatedLinesShareTranslationWithoutChangingOriginalTiming() {
        let document = LRCParser.parse("[00:01]原创第一句\n[00:02]♪\n[00:03]原创第一句\n[00:04]原创第二句")
        let plan = LyricTranslationPlan(document: document)
        XCTAssertEqual(plan.units.map(\.text), ["原创第一句", "原创第二句"])
        XCTAssertEqual(document.lines.map(\.time), [1, 2, 3, 4])
        XCTAssertEqual(plan.original(id: "1", matching: "原创第二句"), "原创第二句")
        XCTAssertNil(plan.original(id: "1", matching: "另一首歌"))
        XCTAssertNil(plan.original(id: "999", matching: "原创第二句"))
    }
    func testPlainLyricsKeepRowBoundariesAndSkipEmptyOrMusicalRows() {
        let document = LyricDocument(lines: [], plainText: "First original line\n\n♪\nSecond line\nFirst original line", source: "测试")
        XCTAssertEqual(LyricTranslationPlan(document: document).units.map(\.text), ["First original line", "Second line"])
        XCTAssertTrue(document.lines.isEmpty)
        XCTAssertTrue(LyricTranslationPlan(document: .init(lines: [], source: "纯音乐", instrumental: true)).units.isEmpty)
    }
}
