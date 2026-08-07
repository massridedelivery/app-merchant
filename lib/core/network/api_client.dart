import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_interceptor.dart';

class ApiClient {
  /// Bare host. The backend serves three different prefixes off it
  /// (SCRUM-53 §1), so repositories carry the full path:
  ///
  /// * REST — `{host}/api/...`, e.g. `/api/food/restaurant/profile`
  /// * Auth — `{host}/auth/...`, with no `/api` prefix
  /// * WS   — `{host}/ws`
  // TODO(SCRUM-53): dev/staging/prod hosts are the ticket's one open item.
  static const String baseUrl = 'http://localhost:8080';
  static const bool useMock = true; // Toggle this to false to use real API

  static const String _accessTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  late final Dio _dio;

  /// Used only to refresh, so a 401 on the main client cannot recurse into
  /// itself through the retry interceptor.
  late final Dio _refreshDio;

  ApiClient() {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    _dio = Dio(options);
    _refreshDio = Dio(options);

    // Add Mock Interceptor if enabled
    if (useMock) {
      _dio.interceptors.add(MockInterceptor());
      _refreshDio.interceptors.add(MockInterceptor());
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // A 401 means the access token aged out. Refresh once, replay once —
        // never more, or an unauthorised call becomes an infinite loop.
        if (e.response?.statusCode != 401 || _isAuthCall(e.requestOptions)) {
          return handler.next(e);
        }
        if (!await _refreshSession()) return handler.next(e);

        try {
          final retried = await _dio.fetch(e.requestOptions);
          return handler.resolve(retried);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      },
    ));
  }

  Dio get dio => _dio;

  bool _isAuthCall(RequestOptions options) => options.path.startsWith('/auth/');

  /// Swaps the stored pair for a fresh one. Returns false when the refresh
  /// token is gone or itself rejected — the caller should send the user back to
  /// login.
  Future<bool> _refreshSession() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _refreshDio
          .post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = response.data as Map<String, dynamic>;
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is! String || refresh is! String) return false;
      await saveSession(accessToken: access, refreshToken: refresh);
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    _dio.options.headers['Authorization'] = 'Bearer $accessToken';
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    _dio.options.headers.remove('Authorization');
  }
}

/// The app's HTTP client. Override in tests with
/// `ProviderScope(overrides: [apiClientProvider.overrideWithValue(fake)])`.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
