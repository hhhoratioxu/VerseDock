import Foundation

public struct LyricLine: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let time: Double
    public let text: String
    public init(id: Int, time: Double, text: String) {
        self.id = id; self.time = time; self.text = text
    }
}

public struct LyricDocument: Codable, Equatable, Sendable {
    public let lines: [LyricLine]
    public let plainText: String
    public let source: String
    public let instrumental: Bool
    public let sourceURL: URL?
    public let matchNote: String?
    public init(lines: [LyricLine], plainText: String = "", source: String, instrumental: Bool = false,
                sourceURL: URL? = nil, matchNote: String? = nil) {
        self.lines = lines; self.plainText = plainText; self.source = source; self.instrumental = instrumental
        self.sourceURL = sourceURL; self.matchNote = matchNote
    }
    /// Positive adjustment displays the lyrics earlier. LRC's own offset is already applied by the parser.
    public func activeIndex(at position: Double, adjustment: Double = 0) -> Int? {
        let target = position + adjustment
        var lower = 0, upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lines[middle].time <= target { lower = middle + 1 } else { upper = middle }
        }
        return lower == 0 ? nil : lower - 1
    }
}

public enum LRCParser {
    /// Parses repeated timestamps, fractional seconds, metadata and global millisecond offsets.
    /// Equal timestamps form one display group, useful for bilingual LRC files.
    public static func parse(_ input: String, source: String = "本地 LRC") -> LyricDocument {
        var offset: Double = 0
        var entries: [(time: Double, text: String, order: Int)] = []
        let rows = input.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
        for row in rows {
            if row.lowercased().hasPrefix("[offset:"), let close = row.firstIndex(of: "]"),
               let value = Double(row[row.index(row.startIndex, offsetBy: 8)..<close]), value.isFinite {
                offset = value / 1000
            }
            var cursor = row.startIndex
            var stamps: [Double] = []
            while cursor < row.endIndex, row[cursor] == "[",
                  let close = row[cursor...].firstIndex(of: "]") {
                let tag = String(row[row.index(after: cursor)..<close])
                guard let stamp = timestamp(tag) else { break }
                stamps.append(stamp)
                cursor = row.index(after: close)
            }
            let text = String(row[cursor...]).trimmingCharacters(in: .whitespaces)
            for stamp in stamps { entries.append((stamp, text, entries.count)) }
        }
        entries.sort { $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time }
        var lines: [LyricLine] = []
        for entry in entries {
            let time = max(0, entry.time + offset)
            if let last = lines.last, last.time == time {
                // Ignore exact duplicate lines but preserve translations and intentional empty intervals.
                let texts = last.text.components(separatedBy: "\n")
                if !entry.text.isEmpty && !texts.contains(entry.text) {
                    lines[lines.count - 1] = LyricLine(id: last.id, time: time,
                        text: last.text.isEmpty ? entry.text : last.text + "\n" + entry.text)
                }
            } else { lines.append(LyricLine(id: lines.count, time: time, text: entry.text)) }
        }
        let plain = lines.isEmpty
            ? rows.filter { !$0.hasPrefix("[") }.joined(separator: "\n")
            : lines.map(\.text).joined(separator: "\n")
        return LyricDocument(lines: lines, plainText: plain, source: source)
    }
    private static func timestamp(_ value: String) -> Double? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[0].allSatisfy(\.isNumber),
              parts[1].allSatisfy({ $0.isNumber || $0 == "." }),
              let minutes = Double(parts[0]), let seconds = Double(parts[1]),
              minutes.isFinite, seconds.isFinite, seconds >= 0, seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }
}
