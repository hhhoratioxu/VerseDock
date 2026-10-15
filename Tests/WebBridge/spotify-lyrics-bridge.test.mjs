import assert from 'node:assert/strict';

// Network-free tests for VerseDock's original WebKit bridge. All authorization values below are fake fixtures.
export default async function testBridge(source) {
  let cases = 0;
  function environment(host = 'open.spotify.com') {
    const messages = [], requests = [];
    const fixture = { status: 200, anonymous: false, expiration: Date.now() + 60000 };
    class HeadersFixture {
      constructor(value = {}) { this.values = value instanceof HeadersFixture ? value.values : value; }
      get(key) { return Object.entries(this.values).find(([name]) => name.toLowerCase() === key.toLowerCase())?.[1] ?? null; }
    }
    class XHRFixture { open() {} setRequestHeader() {} send() {} addEventListener() {} }
    const window = {
      webkit: { messageHandlers: { verseLyricsState: { postMessage(value) { messages.push(value); } } } },
      fetch: async (raw, options) => {
        requests.push({ raw, options });
        if (String(raw).includes('/api/token')) return { ok: true, clone: () => ({ json: async () => ({
          accessToken: 'fake-test-authorization-only', isAnonymous: fixture.anonymous,
          accessTokenExpirationTimestampMs: fixture.expiration
        }) }) };
        return { status: fixture.status, headers: { get: () => '17' }, text: async () => JSON.stringify({
          lyrics: { syncType: 'LINE_SYNCED', lines: [{ startTimeMs: '1000', words: 'Original test line' }] },
          ignoredSensitiveField: 'must-never-cross-the-bridge'
        }) };
      }
    };
    new Function('window', 'location', 'XMLHttpRequest', 'Headers', 'URL', 'AbortController', 'setTimeout', 'clearTimeout', source)(
      window, { protocol: 'https:', hostname: host, origin: 'https://' + host, href: 'https://' + host + '/' },
      XHRFixture, HeadersFixture, URL, AbortController, setTimeout, clearTimeout);
    return { window, fixture, messages, requests, XHRFixture };
  }
  async function authorize(env) { await env.window.fetch('https://open.spotify.com/api/token'); await Promise.resolve(); }
  const id = '1234567890abcdefghijkl';
  {
    const env = environment(); await authorize(env);
    assert.deepEqual(env.messages, ['ready']);
    const result = await env.window.__verseDockLyrics.lookup(id);
    assert.equal(result.status, 200);
    assert.equal(result.body.lyrics.lines[0].words, 'Original test line');
    assert.deepEqual(Object.keys(result.body), ['lyrics']);
    assert.deepEqual(Object.keys(env.window.__verseDockLyrics), ['lookup']);
    assert.ok(!JSON.stringify(result).includes('fake-test-authorization'));
    const sent = env.requests.at(-1);
    assert.ok(sent.raw.startsWith('https://spclient.wg.spotify.com/color-lyrics/v2/track/' + id));
    assert.equal(sent.options.credentials, 'omit');
    assert.equal(sent.options.headers.authorization, 'Bearer fake-test-authorization-only');
    env.fixture.status = 429;
    assert.deepEqual(await env.window.__verseDockLyrics.lookup(id), { status: 429, retryAfter: 17 });
    env.fixture.status = 401;
    assert.deepEqual(await env.window.__verseDockLyrics.lookup(id), { status: 401 });
    assert.deepEqual(env.messages, ['ready', 'signIn']);
    await authorize(env); assert.deepEqual(env.messages, ['ready', 'signIn', 'ready']);
    cases++;
  }
  {
    const env = environment(); env.fixture.anonymous = true; await authorize(env);
    assert.deepEqual(env.messages, ['signIn']);
    assert.deepEqual(await env.window.__verseDockLyrics.lookup(id), { status: 401 });
    assert.equal(env.requests.length, 1);
    assert.deepEqual(await env.window.__verseDockLyrics.lookup('../private?x'), { status: 400 });
    cases++;
  }
  {
    const env = environment(); env.fixture.expiration = Date.now() - 1000; await authorize(env);
    assert.deepEqual(await env.window.__verseDockLyrics.lookup(id), { status: 401 });
    assert.equal(env.requests.length, 1);
    assert.deepEqual(env.messages, ['ready', 'signIn']);
    env.fixture.expiration = Date.now() + 60000; await authorize(env);
    assert.deepEqual(env.messages, ['ready', 'signIn', 'ready']);
    cases++;
  }
  {
    const env = environment();
    await env.window.fetch('https://other.invalid/request', { headers: { authorization: 'Bearer fake-not-a-spotify-token' } });
    assert.deepEqual(env.messages, []);
    assert.deepEqual(await env.window.__verseDockLyrics.lookup(id), { status: 401 });
    const xhr = new env.XHRFixture(); xhr.open('GET', 'https://spclient.wg.spotify.com/state');
    xhr.setRequestHeader('Authorization', 'Bearer fake-web-player-header'); xhr.send();
    assert.deepEqual(env.messages, ['signIn', 'ready']);
    assert.equal((await env.window.__verseDockLyrics.lookup(id)).status, 200);
    assert.ok(env.messages.every(value => ['ready', 'signIn'].includes(value)));
    cases++;
  }
  {
    const env = environment();
    await env.window.fetch('https://api-partner.spotify.com/pathfinder/v2/query', { headers: {
      Authorization: 'Bearer fake-partner-authorization', 'Client-Token': 'fake-client-token'
    } });
    assert.deepEqual(env.messages, ['ready']);
    const response = await env.window.__verseDockLyrics.lookup(id);
    assert.equal(response.status, 200);
    assert.equal(env.requests.at(-1).options.headers['client-token'], 'fake-client-token');
    assert.ok(!JSON.stringify(response).includes('fake-client-token'));
    assert.ok(!JSON.stringify(response).includes('fake-partner-authorization'));
    cases++;
  }
  {
    const env = environment('other.invalid');
    assert.equal(env.window.__verseDockLyrics, undefined);
    cases++;
  }
  return { cases, passed: true, realNetworkUsed: false, realCredentialsUsed: false };
}
