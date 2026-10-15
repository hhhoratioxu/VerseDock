import Foundation
import VerseCore

struct RelayState: Codable, Equatable {
    let title: String
    let artist: String
    let line: String
    let nextLine: String
    let isPlaying: Bool
    let source: String
    let updatedAt: Double
    let position: Double
    let duration: Double
    var translation: String? = nil
    var translationLanguage: String? = nil
}

enum RelayClient {
    static func send<T: Encodable>(_ value: T, path: String, base: String, key: String) async throws {
        guard let url = URL(string: base), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              key.count >= 32 else { throw VerseError.message("推送桥需要 HTTPS 服务地址和至少 32 字符的配对密钥") }
        var request = URLRequest(url: url.appendingPathComponent(path))
        request.httpMethod = "POST"; request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(value)
        let (_, response) = try await URLSession.shared.data(for: request)
        try SpotifyAPI.validate(response)
    }
}
