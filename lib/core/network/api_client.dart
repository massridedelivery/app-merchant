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

  static const String _tokenKey = 'auth_token';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add Mock Interceptor if enabled
    if (useMock) {
      _dio.interceptors.add(MockInterceptor());
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors here (e.g., 401 Unauthorized -> logout)
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _dio.options.headers.remove('Authorization');
  }
}

/// The app's HTTP client. Override in tests with
/// `ProviderScope(overrides: [apiClientProvider.overrideWithValue(fake)])`.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
