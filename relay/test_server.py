import json
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from server import Relay, activity_payload, handler_for, validate_state


def state():
    return dict(title='原创歌', artist='测试', line='当前一句', nextLine='下一句', isPlaying=True,
                source='本地 LRC', updatedAt=time.time(), position=8.2, duration=30)


class FakeAPNs:
    def __init__(self): self.sent = []; self.result = 'accepted'
    def send(self, token, payload): self.sent.append((token, payload)); return self.result


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.apns = FakeAPNs()
        self.relay = Relay('a' * 32, ':memory:', self.apns)
    def tearDown(self): self.relay.db.close()
    def register(self): self.relay.register({'activityID': 'test-id', 'token': 'ab' * 32})
    def test_no_registration_does_not_claim_success(self):
        self.assertEqual(self.relay.update(state())[0], 409)
    def test_payload_matches_activitykit_schema_and_budget(self):
        value = state(); payload = activity_payload(value, 123)
        self.assertEqual(payload['aps']['event'], 'update')
        self.assertEqual(payload['aps']['content-state'], value)
        self.assertEqual(payload['aps']['stale-date'], 153)
        self.assertNotIn('alert', payload['aps'])
    def test_optional_translation_is_validated_and_preserved(self):
        value = {**state(), 'translation': 'Translated original test line', 'translationLanguage': 'en'}
        self.assertEqual(validate_state(value), value)
        self.assertEqual(activity_payload(value, 123)['aps']['content-state']['translation'], value['translation'])
        self.assertEqual(validate_state(state()).get('translation'), None)
        for extra in ({'translation': True}, {'translation': 'x' * 301}, {'translationLanguage': 1}, {'unknown': 'x'}):
            with self.assertRaises(ValueError): validate_state({**state(), **extra})
    def test_device_translation_requires_opt_in_and_matching_language(self):
        for preference in ('', 'fr', 'en'):
            self.relay.register({'activityID':'test-id', 'token':'ab' * 32, 'translationLanguage':preference})
            self.relay.last_update = 0
            self.relay.update({**state(), 'translation':'Original test translation', 'translationLanguage':'en'})
            delivered = self.apns.sent[-1][1]['aps']['content-state']
            self.assertEqual('translation' in delivered, preference == 'en')
        with self.assertRaises(ValueError):
            self.relay.register({'activityID':'test-id', 'token':'ab' * 32, 'translationLanguage':True})
    def test_delivery_throttle_and_unregistration(self):
        self.register()
        self.assertEqual(self.relay.update(state()), (200, {'accepted': 1}))
        self.assertEqual(self.relay.update(state())[0], 429)
        self.relay.unregister({'activityID': 'test-id'})
        self.assertEqual(self.relay.db.execute('SELECT COUNT(*) FROM activities').fetchone()[0], 0)
    def test_expired_token_removed(self):
        self.register(); self.apns.result = 'expired'
        self.assertEqual(self.relay.update(state())[0], 410)
        self.assertEqual(self.relay.db.execute('SELECT COUNT(*) FROM activities').fetchone()[0], 0)
    def test_apns_failure_is_reported(self):
        self.register(); self.apns.result = 'failed'
        self.assertEqual(self.relay.update(state())[0], 502)
    def test_invalid_or_oversized_input(self):
        for replacement in ({'duration': float('nan')}, {'isPlaying': 'yes'}, {'updatedAt': 1},
                            {'line': 'x' * 301}, {'duration': True}):
            with self.assertRaises(ValueError): validate_state({**state(), **replacement})
        with self.assertRaises(ValueError): self.relay.register({'activityID': '../x', 'token': 'ab' * 32})
    def test_real_http_requires_auth_and_accepts_json(self):
        server = ThreadingHTTPServer(('127.0.0.1', 0), handler_for(self.relay))
        worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
        url = 'http://127.0.0.1:' + str(server.server_port) + '/register'
        body = json.dumps({'activityID': 'http-test', 'token': 'ab' * 32}).encode()
        try:
            request = urllib.request.Request(url, body, {'Content-Type': 'application/json'})
            with self.assertRaises(urllib.error.HTTPError) as caught: urllib.request.urlopen(request)
            self.assertEqual(caught.exception.code, 401)
            request.add_header('Authorization', 'Bearer ' + 'a' * 32)
            with urllib.request.urlopen(request) as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(json.load(response), {'registered': True})
        finally: server.shutdown(); server.server_close(); worker.join()


if __name__ == '__main__': unittest.main()
