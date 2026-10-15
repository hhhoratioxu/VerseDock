import ActivityKit
import Foundation

struct LyricsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let artist: String
        let line: String
        let nextLine: String
        let isPlaying: Bool
        let source: String
        let updatedAt: Double
        let position: Double
        let duration: Double
    }
    let sessionName: String
}
