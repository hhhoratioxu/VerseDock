import Foundation
import CryptoKit
import Security

public enum VerseError: Error, LocalizedError, Equatable {
    case message(String)
    case http(Int)
    case rateLimited(Double)
    public var errorDescription: String? {
        switch self {
        case .message(let value): return value
        case .http(let status): return "服务返回 HTTP \(status)"
        case .rateLimited(let seconds): return "请求过于频繁，\(Int(seconds)) 秒后再试"
        }
    }
}

public enum OAuthPKCE {
    public static func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess
        else { throw VerseError.message("无法生成安全随机数") }
        return base64URL(Data(bytes))
    }
    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    public static func authorizeURL(clientID: String, redirect: URL, verifier: String, state: String) throws -> URL {
        guard !clientID.isEmpty, redirect.scheme == "https", redirect.host != nil,
              redirect.user == nil, redirect.password == nil, redirect.query == nil, redirect.fragment == nil
        else { throw VerseError.message("请设置 Client ID 和有效的 HTTPS 回调地址") }
        var url = URLComponents(string: "https://accounts.spotify.com/authorize")!
        url.queryItems = ["response_type": "code", "client_id": clientID,
            "redirect_uri": redirect.absoluteString, "scope": "user-read-currently-playing",
            "code_challenge_method": "S256", "code_challenge": challenge(for: verifier), "state": state]
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return url.url!
    }
    public static func callbackCode(_ url: URL, expectedState: String) throws -> String {
        guard url.scheme == "versedock", url.host == "oauth", url.path.isEmpty || url.path == "/" else {
            throw VerseError.message("授权回调地址不匹配")
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func unique(_ key: String) -> String? {
            let values = query.filter { $0.name == key }
            return values.count == 1 ? values.first?.value : nil
        }
        guard !expectedState.isEmpty, unique("state") == expectedState else {
            throw VerseError.message("授权状态校验失败，请重新连接")
        }
        if unique("error") != nil { throw VerseError.message("Spotify 授权被取消或拒绝") }
        guard let code = unique("code"), !code.isEmpty else { throw VerseError.message("回调缺少授权码") }
        return code
    }
    public static func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let value = values.sorted { $0.key < $1.key }.map {
            ($0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + "=" +
            ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&")
        return Data(value.utf8)
    }
}

public struct SpotifyTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken; self.refreshToken = refreshToken; self.expiresAt = expiresAt
    }
}

public struct SpotifyAPI: Sendable {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func exchange(code: String, verifier: String, clientID: String, redirect: URL) async throws -> SpotifyTokens {
        try await tokenRequest(["grant_type": "authorization_code", "code": code,
            "code_verifier": verifier, "client_id": clientID, "redirect_uri": redirect.absoluteString], previous: nil)
    }
    public func refresh(_ tokens: SpotifyTokens, clientID: String) async throws -> SpotifyTokens {
        try await tokenRequest(["grant_type": "refresh_token", "refresh_token": tokens.refreshToken,
            "client_id": clientID], previous: tokens.refreshToken)
    }
    private func tokenRequest(_ values: [String: String], previous: String?) async throws -> SpotifyTokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"; request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = OAuthPKCE.form(values)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        struct Result: Decodable { let access_token: String; let refresh_token: String?; let expires_in: Double }
        let result = try JSONDecoder().decode(Result.self, from: data)
        guard let refresh = result.refresh_token ?? previous, !refresh.isEmpty,
              !result.access_token.isEmpty, result.expires_in > 0 else { throw VerseError.message("授权令牌无效") }
        return SpotifyTokens(accessToken: result.access_token, refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(result.expires_in))
    }
    public func currentlyPlaying(accessToken: String) async throws -> PlaybackSnapshot? {
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        if (response as? HTTPURLResponse)?.statusCode == 204 { return nil }
        return try JSONDecoder().decode(SpotifyEnvelope.self, from: data).snapshot()
    }
    public static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw VerseError.message("无效的网络响应") }
        if http.statusCode == 429 {
            throw VerseError.rateLimited(max(1, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30))
        }
        guard (200..<300).contains(http.statusCode) else { throw VerseError.http(http.statusCode) }
    }
}
