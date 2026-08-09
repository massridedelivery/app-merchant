import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_interceptor.dart';

class ApiClient {
  // Server root. Most endpoints live under /api/food (see [baseUrl]), but a few
  // (e.g. /auth/login) sit at the root — call those with an absolute URL built
  // from [host] so they aren't prefixed with /api/food.
  static const String host = 'https://driver-api-dev.nutchaphut.dev';
  static const String baseUrl = '$host/api/food';
  static const bool useMock = false; // Toggle this to true to use the mock interceptor
  
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
        final token = await _getToken();
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

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }
}

// Global instance for simple access, later we can use Riverpod provider
final apiClient = ApiClient();
