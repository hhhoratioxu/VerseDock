import Foundation

/// Stable identifiers keep asynchronous, out-of-order translations attached to the right original.
public struct LyricTranslationPlan: Equatable, Sendable {
    public struct Unit: Equatable, Sendable {
        public let id: String
        public let text: String
    }
    public let units: [Unit]
    public init(document: LyricDocument) {
        let texts = document.lines.isEmpty
            ? document.plainText.components(separatedBy: .newlines) : document.lines.map(\.text)
        var seen = Set<String>()
        units = texts.compactMap { text in
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.unicodeScalars.contains(where: CharacterSet.letters.contains), seen.insert(text).inserted else { return nil }
            return Unit(id: String(seen.count - 1), text: text)
        }
    }
    public func original(id: String, matching text: String) -> String? {
        units.first(where: { $0.id == id && $0.text == text })?.text
    }
}
