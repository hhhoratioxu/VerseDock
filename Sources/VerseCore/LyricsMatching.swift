import Foundation

public struct LyricsMatch: Sendable {
    public let score: Double
    public let note: String?
}
public enum LyricsMatching {
    public static func simplify(_ value: String) -> String {
        value.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? value
    }
    public static func normalize(_ value: String) -> String {
        let folded = simplify(value).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX"))
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
    public static func title(_ value: String) -> String {
        // Remove soundtrack descriptions, while retaining live/remix/acoustic/edition labels.
        let pattern = #"\s*(?:[-–—]\s*|[（(])(?:电影|電視劇|电视剧|電視|电视|電視劇|電影|影视|影視|网剧|網劇|from\b|theme\b|ost\b).*$"#
        return value.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func artists(_ values: [String]) -> Set<String> {
        let pattern = #"\s+(?:feat\.?|ft\.?|featuring|with|and|x)\s+|[,，&、;/；]"#
        return Set(values.flatMap { value in
            value.replacingOccurrences(of: pattern, with: "|", options: [.regularExpression, .caseInsensitive])
                .components(separatedBy: "|").map(normalize).filter { !$0.isEmpty }
        })
    }
    private static func versions(_ value: String) -> Set<String> {
        let text = simplify(value).lowercased()
        var result = Set<String>()
        for word in ["live", "remix", "instrumental", "karaoke", "acoustic"] {
            if text.range(of: "\\b" + word + "\\b", options: .regularExpression) != nil { result.insert(word) }
        }
        for (label, words) in [("live", ["现场", "演唱会"]), ("remix", ["混音", "重混"]),
                                ("instrumental", ["伴奏", "纯音乐"]), ("acoustic", ["不插电"])] {
            if words.contains(where: text.contains) { result.insert(label) }
        }
        return result
    }
    public static func match(_ track: Track, title: String, artists candidateArtists: [String],
                             album: String, duration: Double) -> LyricsMatch? {
        guard !normalize(track.title).isEmpty, normalize(Self.title(title)) == normalize(Self.title(track.title)),
              !artists([track.artist]).isEmpty, artists(candidateArtists) == artists([track.artist]),
              duration.isFinite, duration > 0, track.duration.isFinite, track.duration > 0,
              versions(title + " " + album) == versions(track.title + " " + track.album) else { return nil }
        let difference = abs(duration - track.duration)
        guard difference <= min(8, max(3, track.duration * 0.035)) else { return nil }
        let note = difference > 3 ? String(format: "版本时长相差 %.1f 秒，可用 ± 校准", difference) : nil
        return LyricsMatch(score: (difference <= 3 ? 100 : 0) +
            (normalize(album) == normalize(track.album) ? 20 : 0) - difference, note: note)
    }
    static func decodeEntities(_ value: String) -> String {
        let regex = try! NSRegularExpression(pattern: #"&(?:#(?:[0-9]+|[xX][0-9a-fA-F]+)|amp|lt|gt|quot|apos|nbsp);"#)
        var output = "", cursor = value.startIndex
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
            guard let range = Range(match.range, in: value) else { continue }
            output += value[cursor..<range.lowerBound]
            let entity = String(value[range].dropFirst().dropLast())
            let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
            if let replacement = named[entity] { output += replacement }
            else {
                let hex = entity.lowercased().hasPrefix("#x")
                let number = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10)
                if let number, let scalar = UnicodeScalar(number), number != 0 { output.unicodeScalars.append(scalar) }
                else { output += value[range] }
            }
            cursor = range.upperBound
        }
        output += value[cursor...]
        return output
    }
}
