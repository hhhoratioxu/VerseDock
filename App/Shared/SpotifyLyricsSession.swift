import SwiftUI
import WebKit
import VerseCore

/// An isolated, user-visible Spotify Web Player session. Authentication stays inside WebKit.
@MainActor final class SpotifyLyricsSession: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = SpotifyLyricsSession()
    @Published private(set) var ready = false
    @Published private(set) var status = "Spotify 原词尚未连接；当前使用备用来源"
    @Published private(set) var visibleHost = "open.spotify.com"
    var onReady: (() -> Void)?
    private var hasLoaded = false
    private var cooldownUntil = Date.distantPast
    private let dataStore = WKWebsiteDataStore(forIdentifier: UUID(uuidString: "C8928FC5-675C-4C4B-950E-030CC830BEA1")!)
    private let stateHandler = SpotifyLyricsStateHandler()
    private(set) lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.userContentController.add(stateHandler, name: "verseLyricsState")
        configuration.userContentController.addUserScript(WKUserScript(source: Self.bridge,
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        return view
    }()
    override init() { super.init(); stateHandler.owner = self }
    func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: "spotifyLyricsRestore") { open() }
    }
    func open() {
        guard !hasLoaded else { return }
        hasLoaded = true
        status = "请在下方 Spotify 网页登录；登录后会自动验证原词读取"
        webView.load(URLRequest(url: URL(string: "https://open.spotify.com/")!))
    }
    func reload() { ready = false; status = "正在重新加载 Spotify 网页会话"; webView.reload() }
    func goToLogin() {
        hasLoaded = true
        webView.load(URLRequest(url: URL(string: "https://accounts.spotify.com/en/login?continue=https%3A%2F%2Fopen.spotify.com%2F")!))
    }
    func disconnect() async {
        ready = false; hasLoaded = false; cooldownUntil = .distantPast
        UserDefaults.standard.set(false, forKey: "spotifyLyricsRestore")
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        await dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        status = "Spotify 歌词会话已清除；当前使用备用来源"
    }
    fileprivate func receive(_ value: String) {
        if value == "ready" {
            let changed = !ready
            ready = true; status = "Spotify 网页会话已就绪，原词会优先验证"
            if changed { onReady?() }
        } else if value == "signIn" {
            ready = false; status = "请登录 Spotify 网页以读取原词；当前使用备用来源"
        }
    }
    func lyrics(for track: Track) async throws -> LyricDocument? {
        guard ready, let link = track.spotifyURL else { throw VerseError.message("Spotify 原词未连接，请在设置中连接歌词网页会话") }
        guard Date() >= cooldownUntil else { throw VerseError.message("Spotify 原词仍在限流，暂时使用备用来源") }
        guard webView.url?.scheme == "https", webView.url?.host == "open.spotify.com" else {
            throw VerseError.message("请完成 Spotify 网页登录后重试原词")
        }
        try Task.checkCancellation()
        let raw = try await webView.callAsyncJavaScript("return await window.__verseDockLyrics.lookup(trackID);",
            arguments: ["trackID": link.lastPathComponent], in: nil, contentWorld: .page)
        try Task.checkCancellation()
        guard let result = raw as? [String: Any], let code = result["status"] as? Int else {
            throw VerseError.message("Spotify 网页歌词响应无效，请重新加载会话")
        }
        if code == 404 { status = "Spotify 当前歌曲无原词，已转备用来源"; return nil }
        if code == 401 || code == 403 {
            ready = false; status = "Spotify 歌词授权不可用，请重新登录；当前使用备用来源"
            throw VerseError.message("Spotify 歌词授权不可用（\(code)），这不代表歌曲没有歌词")
        }
        if code == 429 {
            let seconds = (result["retryAfter"] as? Double) ?? 60
            cooldownUntil = Date().addingTimeInterval(seconds.isFinite ? min(3600, max(1, seconds)) : 60)
            throw VerseError.message("Spotify 原词限流，暂时使用备用来源")
        }
        guard code == 200 else { throw VerseError.message("Spotify 原词读取失败（\(code)），暂时使用备用来源") }
        guard let body = result["body"] as? [String: Any] else { throw VerseError.message("Spotify 原词响应缺少内容") }
        let data = try JSONSerialization.data(withJSONObject: body)
        let document = try SpotifyLyrics.parse(data, track: track)
        if document != nil { UserDefaults.standard.set(true, forKey: "spotifyLyricsRestore") }
        status = document == nil ? "Spotify 当前歌曲没有可用原词，已转备用来源" : "已取得 Spotify 原词，优先显示"
        return document
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        visibleHost = webView.url?.host ?? "open.spotify.com"
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { status = "Spotify 网页未加载，请重试或检查网络" }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.targetFrame?.isMainFrame != false else { decisionHandler(.allow); return }
        let url = navigationAction.request.url
        let host = url?.host?.lowercased() ?? ""
        let allowed = url?.scheme == "https" && (host == "spotify.com" || host.hasSuffix(".spotify.com"))
        decisionHandler(allowed || url?.absoluteString == "about:blank" ? .allow : .cancel)
    }
    // Original bridge: only Spotify first-party request authorization is used, and it stays in this page closure.
    // No passwords, cookies, token strings, account profiles or request headers cross the native bridge.
    private static let bridge = #"""
    (() => {
      if (location.protocol !== 'https:' || location.hostname !== 'open.spotify.com') return;
      const nativeFetch = window.fetch.bind(window);
      let token = '', clientToken = '', expires = 0, lastState = '';
      const report = state => {
        if (lastState === state) return;
        lastState = state;
        window.webkit.messageHandlers.verseLyricsState.postMessage(state);
      };
      const acceptToken = body => {
        if (!body || typeof body !== 'object' || typeof body.accessToken !== 'string') return;
        if (body.isAnonymous === true) { token = ''; expires = 0; report('signIn'); return; }
        token = body.accessToken;
        expires = Number(body.accessTokenExpirationTimestampMs) || Date.now() + 10 * 60 * 1000;
        report('ready');
      };
      const tokenURL = raw => {
        try { const u = new URL(raw, location.href); return u.origin === location.origin &&
          (u.pathname === '/api/token' || u.pathname === '/get_access_token'); } catch { return false; }
      };
      const observeHeaders = (raw, headers) => {
        try {
          const u = new URL(raw, location.href);
          if (u.protocol !== 'https:' || !(u.hostname === 'spclient.wg.spotify.com' ||
              /^[a-z0-9]+-spclient\.spotify\.com$/.test(u.hostname) || u.hostname === 'api-partner.spotify.com' || u.hostname === 'api.spotify.com')) return;
          const values = new Headers(headers);
          const client = values.get('client-token');
          if (client) clientToken = client;
          const bearer = values.get('authorization') || '';
          if (bearer.startsWith('Bearer ') && bearer.length > 20) {
            if (token !== bearer.slice(7)) { token = bearer.slice(7); expires = Date.now() + 10 * 60 * 1000; report('ready'); }
          }
        } catch {}
      };
      window.fetch = function(input, options) {
        const raw = typeof input === 'string' || input instanceof URL ? String(input) : input.url;
        observeHeaders(raw, options && options.headers || input && input.headers);
        return nativeFetch(input, options).then(response => {
          if (tokenURL(raw) && response.ok) response.clone().json().then(acceptToken).catch(() => {});
          return response;
        });
      };
      const requests = new WeakMap();
      const originalOpen = XMLHttpRequest.prototype.open;
      const originalHeader = XMLHttpRequest.prototype.setRequestHeader;
      const originalSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(method, url, ...rest) {
        requests.set(this, {url: String(url), headers: {}});
        return originalOpen.call(this, method, url, ...rest);
      };
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        const request = requests.get(this);
        if (request && ['authorization', 'client-token'].includes(String(name).toLowerCase())) request.headers[name] = value;
        return originalHeader.call(this, name, value);
      };
      XMLHttpRequest.prototype.send = function(...args) {
        const request = requests.get(this);
        if (request) {
          observeHeaders(request.url, request.headers);
          if (tokenURL(request.url)) this.addEventListener('load', () => {
            try { if (this.status === 200) acceptToken(this.responseType === 'json' ? this.response : JSON.parse(this.responseText)); } catch {}
          }, {once: true});
        }
        return originalSend.apply(this, args);
      };
      Object.defineProperty(window, '__verseDockLyrics', {value: Object.freeze({
        lookup: async trackID => {
          if (!/^[A-Za-z0-9]{22}$/.test(trackID)) return {status: 400};
          if (!token || Date.now() + 2000 >= expires) { report('signIn'); return {status: 401}; }
          const controller = new AbortController();
          const timeout = setTimeout(() => controller.abort(), 7000);
          try {
            const headers = {authorization: 'Bearer ' + token, 'app-platform': 'WebPlayer', accept: 'application/json'};
            if (clientToken) headers['client-token'] = clientToken;
            const response = await nativeFetch('https://spclient.wg.spotify.com/color-lyrics/v2/track/' + trackID +
              '?format=json&vocalRemoval=false&market=from_token', {headers, credentials: 'omit', signal: controller.signal});
            if (response.status === 429) return {status: 429, retryAfter: Number(response.headers.get('Retry-After')) || 60};
            if (response.status === 401 || response.status === 403) report('signIn');
            if (response.status !== 200) return {status: response.status};
            const text = await response.text();
            if (text.length > 1000000) return {status: 502};
            const body = JSON.parse(text);
            const result = {lyrics: body.lyrics || null};
            if (typeof body.showLyrics === 'boolean') result.showLyrics = body.showLyrics;
            return {status: 200, body: result};
          } catch { return {status: 503}; }
          finally { clearTimeout(timeout); }
        }
      }), configurable: false, writable: false});
    })();
    """#
}

@MainActor private final class SpotifyLyricsStateHandler: NSObject, WKScriptMessageHandler {
    weak var owner: SpotifyLyricsSession?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host == "open.spotify.com",
              let state = message.body as? String, ["ready", "signIn"].contains(state) else { return }
        owner?.receive(state)
    }
}

struct SpotifyLyricsConnectionView: View {
    @ObservedObject var session = SpotifyLyricsSession.shared
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("连接 Spotify 原词").font(.headline)
                Spacer()
                Button("完成") { if let onDone { onDone() } else { dismiss() } }
            }
            Text("请在 Spotify 官方网页中自行登录。登录状态由本机隔离的 WebKit 会话管理；歌词授权只在该网页中使用，不导出 Cookie 或密码。此方式使用非公开网页接口，可能失效。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Label(session.visibleHost, systemImage: "lock"); Spacer()
                Button("前往 Spotify 登录") { session.goToLogin() }
                Button("重新加载") { session.reload() }
            }.font(.caption)
            SpotifyLyricsWebView(session: session)
            HStack {
                Text(session.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("清除歌词登录会话") { Task { await session.disconnect() } }
            }
        }.padding(16).task { session.open() }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 560)
        #endif
    }
}

#if os(macOS)
private struct SpotifyLyricsWebView: NSViewRepresentable {
    let session: SpotifyLyricsSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#else
private struct SpotifyLyricsWebView: UIViewRepresentable {
    let session: SpotifyLyricsSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#endif
