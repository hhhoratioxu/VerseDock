"""Original, single-household Mac -> APNs Live Activity relay.

Bind to loopback and place behind your own HTTPS reverse proxy. No Spotify tokens
are accepted here. No request bodies, query strings or APNs tokens are logged.
"""
import base64
import hmac
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

import httpx
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

FIELDS = {'title', 'artist', 'line', 'nextLine', 'isPlaying', 'source', 'updatedAt', 'position', 'duration'}
WEB = Path(__file__).resolve().parent.parent / 'web'


def validate_state(value):
    if not isinstance(value, dict) or set(value) != FIELDS:
        raise ValueError('invalid content state')
    for field in ('title', 'artist', 'line', 'nextLine', 'source'):
        if not isinstance(value[field], str) or len(value[field]) > 300:
            raise ValueError('text field too long')
    if not isinstance(value['isPlaying'], bool):
        raise ValueError('invalid playback state')
    for field in ('updatedAt', 'position', 'duration'):
        number = value[field]
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or number < 0:
            raise ValueError('invalid numeric field')
    if abs(value['updatedAt'] - time.time()) > 120:
        raise ValueError('stale sender clock')
    # Limit payload by UTF-8 byte size, because APNs has a 4 KB budget.
    if len(json.dumps(value, ensure_ascii=False).encode()) > 3000:
        raise ValueError('content state too large')
    return value


def activity_payload(state, timestamp):
    return {'aps': {'timestamp': int(timestamp), 'event': 'update', 'content-state': state,
                    'stale-date': int(timestamp) + 30}}


class APNs:
    def __init__(self, team, key_id, bundle, key_path, environment):
        if environment not in ('sandbox', 'production'):
            raise ValueError('APNS_ENV must be sandbox or production')
        self.team, self.key_id = team, key_id
        self.topic = bundle + '.push-type.liveactivity'
        self.key = serialization.load_pem_private_key(Path(key_path).read_bytes(), password=None)
        if not isinstance(self.key, ec.EllipticCurvePrivateKey) or not isinstance(self.key.curve, ec.SECP256R1):
            raise ValueError('APNs requires a P-256 private key')
        self.host = 'https://api.sandbox.push.apple.com' if environment == 'sandbox' else 'https://api.push.apple.com'
        self.client = httpx.Client(http2=True, timeout=10)
        self.cached = None
        self.issued = 0

    def jwt(self):
        now = int(time.time())
        if self.cached is not None and now - self.issued < 1200:
            return self.cached
        def segment(data):
            return base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).rstrip(b'=')
        content = segment({'alg': 'ES256', 'kid': self.key_id}) + b'.' + segment({'iss': self.team, 'iat': now})
        der = self.key.sign(content, ec.ECDSA(hashes.SHA256()))
        r, s = decode_dss_signature(der)
        signature = base64.urlsafe_b64encode(r.to_bytes(32, 'big') + s.to_bytes(32, 'big')).rstrip(b'=')
        self.cached = (content + b'.' + signature).decode()
        self.issued = now
        return self.cached

    def send(self, token, payload):
        response = self.client.post(self.host + '/3/device/' + token, json=payload, headers={
            'authorization': 'bearer ' + self.jwt(), 'apns-topic': self.topic,
            'apns-push-type': 'liveactivity', 'apns-priority': '5',
            'apns-expiration': str(int(time.time()) + 30)})
        if response.status_code == 200:
            return 'accepted'
        try:
            reason = response.json().get('reason')
        except ValueError:
            reason = None
        if response.status_code == 410 or reason in ('BadDeviceToken', 'Unregistered'):
            return 'expired'
        return 'failed'


class Relay:
    def __init__(self, secret, database, apns):
        if len(secret) < 32:
            raise ValueError('RELAY_KEY must have at least 32 characters')
        self.secret, self.apns = secret, apns
        self.lock = threading.Lock()
        self.db = sqlite3.connect(database, check_same_thread=False)
        self.db.execute('CREATE TABLE IF NOT EXISTS activities (id TEXT PRIMARY KEY, token TEXT NOT NULL, registered REAL NOT NULL)')
        self.db.commit()
        self.last_update = 0.0
        if database != ':memory:': os.chmod(database, 0o600)

    def register(self, value):
        if not isinstance(value, dict) or set(value) != {'activityID', 'token'}:
            raise ValueError('invalid registration')
        identifier, token = value['activityID'], value['token']
        if not isinstance(identifier, str) or not re.fullmatch(r'[A-Za-z0-9-]{1,100}', identifier):
            raise ValueError('invalid activity identifier')
        if not isinstance(token, str) or not re.fullmatch(r'[0-9a-fA-F]{64,512}', token) or len(token) % 2:
            raise ValueError('invalid push token')
        with self.lock:
            self.db.execute('DELETE FROM activities WHERE registered < ?', (time.time() - 8 * 3600,))
            count = self.db.execute('SELECT COUNT(*) FROM activities').fetchone()[0]
            exists = self.db.execute('SELECT 1 FROM activities WHERE id = ?', (identifier,)).fetchone()
            if count >= 8 and not exists: raise ValueError('household device limit reached')
            self.db.execute('INSERT OR REPLACE INTO activities VALUES (?,?,?)', (identifier, token, time.time()))
            self.db.commit()
        return {'registered': True}

    def unregister(self, value):
        if not isinstance(value, dict) or set(value) != {'activityID'} or not isinstance(value['activityID'], str):
            raise ValueError('invalid removal')
        with self.lock:
            self.db.execute('DELETE FROM activities WHERE id = ?', (value['activityID'],))
            self.db.commit()
        return {'removed': True}

    def update(self, value):
        state = validate_state(value)
        with self.lock:
            now = time.time()
            if now - self.last_update < 5:
                return 429, {'error': 'rate_limited'}
            self.last_update = now
            self.db.execute('DELETE FROM activities WHERE registered < ?', (now - 8 * 3600,))
            registrations = self.db.execute('SELECT id, token FROM activities').fetchall()
            accepted = 0
            failed = 0
            for identifier, token in registrations:
                try:
                    result = self.apns.send(token, activity_payload(state, now))
                except (httpx.HTTPError, OSError):
                    result = 'failed'
                if result == 'accepted': accepted += 1
                elif result == 'expired': self.db.execute('DELETE FROM activities WHERE id = ?', (identifier,))
                else: failed += 1
            self.db.commit()
            if failed: return 502, {'error': 'apns_failed', 'accepted': accepted, 'failed': failed}
            if not registrations: return 409, {'error': 'no_registered_activity'}
            if accepted == 0: return 410, {'error': 'activities_expired'}
            return 200, {'accepted': accepted}


def handler_for(relay):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, value):
            data = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            if status == 429: self.send_header('Retry-After', '5')
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            self.connection.settimeout(15)
            auth = self.headers.get('Authorization', '')
            if not hmac.compare_digest(auth.encode(), ('Bearer ' + relay.secret).encode()):
                self.reply(401, {'error': 'unauthorized'}); return
            if self.headers.get('Transfer-Encoding'):
                self.reply(400, {'error': 'chunked_requests_unsupported'}); return
            if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
                self.reply(415, {'error': 'json_required'}); return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if length <= 0 or length > 8192: raise ValueError('body size')
                value = json.loads(self.rfile.read(length))
                path = urlsplit(self.path).path
                if path == '/register': self.reply(200, relay.register(value))
                elif path == '/unregister': self.reply(200, relay.unregister(value))
                elif path == '/update': self.reply(*relay.update(value))
                else: self.reply(404, {'error': 'not_found'})
            except (ValueError, KeyError, TypeError):
                self.reply(400, {'error': 'invalid_request'})
            except (TimeoutError, OSError):
                self.close_connection = True

        def do_GET(self):
            path = urlsplit(self.path).path
            if path == '/health': self.reply(200, {'service': 'VerseDock relay'}); return
            files = {'/callback.html': ('callback.html', 'text/html; charset=utf-8'),
                     '/callback.js': ('callback.js', 'text/javascript; charset=utf-8'),
                     '/callback.css': ('callback.css', 'text/css; charset=utf-8')}
            if path not in files: self.reply(404, {'error': 'not_found'}); return
            filename, mime = files[path]
            data = (WEB / filename).read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(data)
    return Handler


if __name__ == '__main__':
    # Protect new database files before opening them.
    os.umask(0o077)
    required = ('RELAY_KEY', 'APNS_TEAM_ID', 'APNS_KEY_ID', 'APNS_KEY_PATH', 'APNS_BUNDLE_ID')
    if any(not os.environ.get(name) for name in required):
        raise SystemExit('Missing relay/APNs configuration. See docs/SETUP.zh-CN.md.')
    apns = APNs(os.environ['APNS_TEAM_ID'], os.environ['APNS_KEY_ID'], os.environ['APNS_BUNDLE_ID'],
                os.environ['APNS_KEY_PATH'], os.environ.get('APNS_ENV', 'sandbox'))
    relay = Relay(os.environ['RELAY_KEY'], os.environ.get('RELAY_DB', 'activities.sqlite'), apns)
    server = ThreadingHTTPServer(('127.0.0.1', int(os.environ.get('RELAY_PORT', '8787'))), handler_for(relay))
    server.daemon_threads = True
    print('VerseDock relay listening on loopback; APNs delivery requires live device verification.', flush=True)
    try: server.serve_forever()
    finally: server.server_close(); apns.client.close(); relay.db.close()
