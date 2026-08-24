import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records whether the socket asked for a refresh, and what it can hand back.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.token, this.refreshSucceeds = false});

  String? token;
  bool refreshSucceeds;
  int refreshCalls = 0;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<bool> refreshSession() async {
    refreshCalls++;
    return refreshSucceeds;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reconnect backoff (SCRUM-53 §11)', () {
    test('doubles and then holds at a ceiling', () {
      final socket = SocketService(_FakeApiClient());
      addTearDown(socket.dispose);

      // Was a flat 3s forever: a host that is down for an hour took 1,200
      // attempts, and with an expired token the loop could never succeed.
      expect(socket.delayForAttempt(0), const Duration(seconds: 2));
      expect(socket.delayForAttempt(1), const Duration(seconds: 4));
      expect(socket.delayForAttempt(2), const Duration(seconds: 8));
      expect(socket.delayForAttempt(3), const Duration(seconds: 16));
      expect(socket.delayForAttempt(4), const Duration(seconds: 32));
    });

    test('never grows past a minute, however long the outage runs', () {
      final socket = SocketService(_FakeApiClient());
      addTearDown(socket.dispose);

      for (final attempt in [5, 6, 10, 40, 1000]) {
        expect(socket.delayForAttempt(attempt), const Duration(seconds: 60),
            reason: 'attempt $attempt');
      }
    });

    test('the delay never goes backwards as attempts climb', () {
      final socket = SocketService(_FakeApiClient());
      addTearDown(socket.dispose);

      var previous = Duration.zero;
      for (var attempt = 0; attempt < 12; attempt++) {
        final delay = socket.delayForAttempt(attempt);
        expect(delay, greaterThanOrEqualTo(previous));
        previous = delay;
      }
    });
  });

  group('missing token', () {
    test('reports the socket as down instead of returning silently', () async {
      final api = _FakeApiClient(token: null);
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      final states = <bool>[];
      socket.connectionStatus.listen(states.add);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(Duration.zero);

      // MainScreen calls connect() once in initState. A silent return left the
      // socket dead for the rest of the session with nothing observing it.
      expect(states, contains(false));
      socket.disconnect();
    });

    test('does not ask for a refresh when there was never a token', () async {
      final api = _FakeApiClient(token: null);
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(Duration.zero);

      // Nothing expired — the app simply has no session yet.
      expect(api.refreshCalls, 0);
      socket.disconnect();
    });
  });

  group('expired token', () {
    test('refreshes once when the handshake fails', () async {
      // A token that exists but is rejected at upgrade. The host is
      // unreachable in a test, so the handshake fails the same way an expired
      // token would — which is exactly the point: the socket cannot tell them
      // apart, so it has to try a refresh.
      final api = _FakeApiClient(token: 'expired', refreshSucceeds: false);
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // There is no 401 for the HTTP retry interceptor to catch here: the
      // token is only ever checked at upgrade (SCRUM-53 §11).
      expect(api.refreshCalls, 1);
      socket.disconnect();
    });

    test('gives up on refreshing rather than spinning on a dead session',
        () async {
      final api = _FakeApiClient(token: 'expired', refreshSucceeds: false);
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Once per connection cycle, not once per attempt — a dead refresh token
      // would otherwise be re-posted on every retry forever.
      expect(api.refreshCalls, 1);
      socket.disconnect();
    });

    test('disconnect clears the cycle so a later connect may refresh again',
        () async {
      final api = _FakeApiClient(token: 'expired', refreshSucceeds: false);
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      socket.disconnect();

      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Signing back in, or reopening the shell, is a fresh cycle.
      expect(api.refreshCalls, 2);
      socket.disconnect();
    });
  });

  group('connection status', () {
    test('mock mode reports connected without touching the network', () async {
      final api = _FakeApiClient(token: 'anything');
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      final states = <bool>[];
      socket.connectionStatus.listen(states.add);

      await socket.connect(mockMode: true);
      await Future<void>.delayed(Duration.zero);

      expect(states, [true]);
      expect(api.refreshCalls, 0);
      socket.disconnect();
    });

    test('a failed handshake never reports connected', () async {
      final api = _FakeApiClient(token: 'valid-looking');
      final socket = SocketService(api);
      addTearDown(socket.dispose);

      final states = <bool>[];
      socket.connectionStatus.listen(states.add);

      await socket.connect(mockMode: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // WebSocketChannel.connect is lazy, so emitting true right after it used
      // to announce a connection that had not happened — and OrderNotifier
      // reconciled against it.
      expect(states, isNot(contains(true)));
      socket.disconnect();
    });
  });
}
