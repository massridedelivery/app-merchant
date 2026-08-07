import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/auth/data/auth_repository.dart';
import 'package:merchant_app/features/auth/models/auth_session.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';

String _b64(Map<String, dynamic> part) =>
    base64Url.encode(utf8.encode(json.encode(part))).replaceAll('=', '');

/// Builds a structurally valid (unsigned) JWT — the app only ever reads the
/// payload; the server is the only party that can verify it.
String jwt({
  String userId = '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10',
  String role = 'restaurant',
  DateTime? expiry,
}) {
  final exp = (expiry ?? DateTime(2030)).millisecondsSinceEpoch ~/ 1000;
  return '${_b64({'alg': 'HS256'})}.'
      '${_b64({'user_id': userId, 'role': role, 'sid': 's1', 'exp': exp})}.'
      'signature';
}

TokenPair pair(String access) =>
    TokenPair(accessToken: access, refreshToken: 'refresh', expiresIn: 86400);

/// Stands in for the real client so tests never touch storage or the network.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());

  String? storedToken;
  TokenPair? issued;
  Object? loginError;
  bool loggedOut = false;
  bool sessionForgotten = false;

  @override
  Future<String?> currentToken() async => storedToken;

  @override
  Future<TokenPair> login({
    required String email,
    required String password,
    String? deviceId,
    String? appVersion,
  }) async {
    if (loginError != null) throw loginError!;
    return issued ?? pair(jwt());
  }

  @override
  Future<void> persistSession(TokenPair tokens) async {
    storedToken = tokens.accessToken;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<void> forgetSession() async {
    sessionForgotten = true;
    storedToken = null;
  }
}

void main() {
  late _FakeAuthRepository repo;

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<AuthState> settled(ProviderContainer c) async {
    c.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    return c.read(authProvider);
  }

  setUp(() => repo = _FakeAuthRepository());

  group('AuthClaims', () {
    test('reads user_id and role out of the payload', () {
      final claims = AuthClaims.tryParse(jwt())!;
      expect(claims.userId, '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10');
      expect(claims.isRestaurant, isTrue);
      expect(claims.isExpired, isFalse);
    });

    test('a past exp reads as expired', () {
      final claims = AuthClaims.tryParse(jwt(expiry: DateTime(2020)))!;
      expect(claims.isExpired, isTrue);
    });

    test('garbage parses to null instead of throwing', () {
      expect(AuthClaims.tryParse('not-a-jwt'), isNull);
      expect(AuthClaims.tryParse('a.b.c'), isNull);
      expect(AuthClaims.tryParse(''), isNull);
    });
  });

  group('startup', () {
    test('no stored token means no session', () async {
      final state = await settled(boot());
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.restaurantId, isNull);
    });

    test('a stored restaurant token restores the session and the id', () async {
      repo.storedToken = jwt();
      final state = await settled(boot());
      expect(state.isAuthenticated, isTrue);
      expect(state.restaurantId, '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10');
    });

    test('an expired token is not a session', () async {
      repo.storedToken = jwt(expiry: DateTime(2020));
      expect((await settled(boot())).isAuthenticated, isFalse);
    });

    test('a driver token is not a session either', () async {
      repo.storedToken = jwt(role: 'driver');
      expect((await settled(boot())).isAuthenticated, isFalse);
    });
  });

  group('login', () {
    test('stores the pair and exposes the restaurant id', () async {
      final container = boot();
      await settled(container);

      await container.read(authProvider.notifier).login('a@b.co', 'pw');

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.restaurantId, '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10');
      expect(repo.storedToken, isNotNull);
    });

    test('a non-restaurant account is rejected client-side', () async {
      // The endpoint itself does not check the role (SCRUM-53 §2).
      repo.issued = pair(jwt(role: 'customer'));
      final container = boot();
      await settled(container);

      await expectLater(
        container.read(authProvider.notifier).login('a@b.co', 'pw'),
        throwsA(isA<AppFailure>()),
      );

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(repo.storedToken, isNull, reason: 'must not persist the session');
    });

    test('an undecodable token is refused rather than trusted', () async {
      repo.issued = pair('garbage');
      final container = boot();
      await settled(container);

      await expectLater(
        container.read(authProvider.notifier).login('a@b.co', 'pw'),
        throwsA(isA<AppFailure>()),
      );
      expect(repo.storedToken, isNull);
    });

    test('isLoading is cleared after a failure', () async {
      repo.loginError = Exception('boom');
      final container = boot();
      await settled(container);

      await expectLater(
        container.read(authProvider.notifier).login('a@b.co', 'pw'),
        throwsA(isA<AppFailure>()),
      );
      expect(container.read(authProvider).isLoading, isFalse);
    });
  });

  group('logout', () {
    test('calls the endpoint and drops the local session', () async {
      repo.storedToken = jwt();
      final container = boot();
      await settled(container);

      await container.read(authProvider.notifier).logout();

      expect(repo.loggedOut, isTrue);
      expect(repo.sessionForgotten, isTrue);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.restaurantId, isNull);
    });
  });
}
