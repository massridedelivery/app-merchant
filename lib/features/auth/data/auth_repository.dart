import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Returns the session token, or null when the server did not issue one.
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      'username': username,
      'password': password,
      'role': 'restaurant',
    });
    if (response.statusCode != 200) return null;
    return response.data['token'] as String?;
  }

  Future<String?> currentToken() => _api.readToken();

  Future<void> persistToken(String token) => _api.saveToken(token);

  Future<void> forgetToken() => _api.clearToken();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
