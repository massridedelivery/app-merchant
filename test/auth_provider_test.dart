import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';

/// Stands in for the real client so the test never touches storage or the
/// network. Overriding it like this is what the global `apiClient` singleton
/// used to make impossible.
class _RecordingApiClient extends ApiClient {
  final List<String> savedTokens = [];
  bool cleared = false;
  String? storedToken;

  @override
  Future<String?> readToken() async => storedToken;

  @override
  Future<void> saveToken(String token) async {
    savedTokens.add(token);
    storedToken = token;
  }

  @override
  Future<void> clearToken() async {
    cleared = true;
    storedToken = null;
  }
}

void main() {
  ProviderContainer containerWith(_RecordingApiClient api) {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts unauthenticated when the injected client has no token', () async {
    final api = _RecordingApiClient();
    final container = containerWith(api);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).isLoading, isFalse);
  });

  test('restores the session from a token on the injected client', () async {
    final api = _RecordingApiClient()..storedToken = 'existing_token';
    final container = containerWith(api);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider).isAuthenticated, isTrue);
  });

  test('mockLogin saves through the injected client', () async {
    final api = _RecordingApiClient();
    final container = containerWith(api);

    await container.read(authProvider.notifier).mockLogin();

    expect(api.savedTokens, ['mock_token_123']);
    expect(container.read(authProvider).isAuthenticated, isTrue);
  });

  test('logout clears through the injected client', () async {
    final api = _RecordingApiClient()..storedToken = 'existing_token';
    final container = containerWith(api);

    await container.read(authProvider.notifier).logout();

    expect(api.cleared, isTrue);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });
}
