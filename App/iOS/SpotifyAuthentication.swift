import UIKit
import AuthenticationServices
import VerseCore

@MainActor final class SpotifyAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    func connect(clientID: String, redirect: URL) async throws -> SpotifyTokens {
        guard session == nil else { throw VerseError.message("授权正在进行，请完成或取消当前窗口") }
        let verifier = try OAuthPKCE.randomString(), state = try OAuthPKCE.randomString()
        let url = try OAuthPKCE.authorizeURL(clientID: clientID, redirect: redirect, verifier: verifier, state: state)
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: url, callbackURLScheme: "versedock") { [weak self] url, error in
                Task { @MainActor in
                    self?.session = nil
                    if let url { continuation.resume(returning: url) }
                    else { continuation.resume(throwing: error ?? VerseError.message("授权已取消")) }
                }
            }
            auth.presentationContextProvider = self
            session = auth
            if !auth.start() { session = nil; continuation.resume(throwing: VerseError.message("无法打开授权窗口")) }
        }
        let code = try OAuthPKCE.callbackCode(callback, expectedState: state)
        return try await SpotifyAPI().exchange(code: code, verifier: verifier, clientID: clientID, redirect: redirect)
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
