import Foundation
import CryptoKit
import VerseCore

actor LyricStore {
    private func directory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("VerseDock/Lyrics", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func url(_ id: String) throws -> URL {
        let key = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return try directory().appendingPathComponent(key + ".json")
    }
    func load(_ id: String) -> LyricDocument? {
        guard let path = try? url(id), let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(LyricDocument.self, from: data)
    }
    func save(_ document: LyricDocument, id: String) throws {
        try JSONEncoder().encode(document).write(to: url(id), options: .atomic)
    }
    func clear() throws {
        let root = try directory()
        for item in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            where item.pathExtension == "json" { try FileManager.default.removeItem(at: item) }
    }
}
