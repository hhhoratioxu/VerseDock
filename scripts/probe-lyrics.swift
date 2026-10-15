import Foundation
import VerseCore

@main struct LyricsProbe {
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 4, let duration = Double(args[3]) else {
            print("Usage: probe-lyrics title artist album duration-seconds [lrclib|qqMusic|netEase|lyricsOVH]"); return
        }
        let providers = args.count > 4 ? [LyricsProvider(rawValue: args[4])].compactMap { $0 } : LyricsProvider.allCases
        let track = Track(id: "diagnostic", title: args[0], artist: args[1], album: args[2], duration: duration)
        let result = try await LyricsClient(providers: providers).lookup(for: track)
        struct Report: Encodable {
            let title: String; let artist: String; let duration: Double; let source: String?
            let timedLines: Int; let plainCharacters: Int; let firstTimestamp: Double?; let lastTimestamp: Double?
            let matchNote: String?; let attempts: [LyricsAttempt]
        }
        let report = Report(title: track.title, artist: track.artist, duration: duration, source: result.document?.source,
            timedLines: result.document?.lines.count ?? 0, plainCharacters: result.document?.plainText.count ?? 0,
            firstTimestamp: result.document?.lines.first?.time, lastTimestamp: result.document?.lines.last?.time,
            matchNote: result.document?.matchNote, attempts: result.attempts)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try encoder.encode(report), encoding: .utf8)!)
    }
}
