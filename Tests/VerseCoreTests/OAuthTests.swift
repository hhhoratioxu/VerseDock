import XCTest
@testable import VerseCore

final class OAuthTests: XCTestCase {
    func testRFC7636ChallengeVector() {
        XCTAssertEqual(OAuthPKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
    func testRandomVerifierIsURLSafe() throws {
        let first = try OAuthPKCE.randomString(), second = try OAuthPKCE.randomString()
        XCTAssertEqual(first.count, 43); XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
    func testCallbackRejectsWrongStateDuplicateAndForeignURL() throws {
        XCTAssertEqual(try OAuthPKCE.callbackCode(URL(string: "versedock://oauth?code=abc&state=ok")!, expectedState: "ok"), "abc")
        for url in ["versedock://oauth?code=abc&state=bad", "versedock://oauth?code=abc&state=ok&state=ok",
                    "https://attacker.invalid/?code=abc&state=ok", "versedock://oauth?code=abc&code=other&state=ok"] {
            XCTAssertThrowsError(try OAuthPKCE.callbackCode(URL(string: url)!, expectedState: "ok"))
        }
        XCTAssertThrowsError(try OAuthPKCE.callbackCode(URL(string: "versedock://oauth?error=access_denied&state=ok")!, expectedState: "ok"))
    }
    func testAuthorizationUsesReadAndSeekScopesAndSecureRedirect() throws {
        let url = try OAuthPKCE.authorizeURL(clientID: "client", redirect: URL(string: "https://example.com/callback.html")!, verifier: "test", state: "random")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first(where: { $0.name == "scope" })?.value, "user-read-currently-playing user-modify-playback-state")
        XCTAssertEqual(items.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
        XCTAssertThrowsError(try OAuthPKCE.authorizeURL(clientID: "client", redirect: URL(string: "http://example.com/callback")!, verifier: "test", state: "random"))
    }
    func testFormEscapesAmpersandsAndPlus() {
        XCTAssertEqual(String(data: OAuthPKCE.form(["code": "x+y&z=1"]), encoding: .utf8), "code=x%2By%26z%3D1")
    }
    func testRetryAfterAndHTTPFailure() {
        let url = URL(string: "https://api.spotify.com")!
        XCTAssertThrowsError(try SpotifyAPI.validate(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "17"])!)) {
            XCTAssertEqual($0 as? VerseError, .rateLimited(17))
        }
        XCTAssertThrowsError(try SpotifyAPI.validate(HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!))
    }
}
