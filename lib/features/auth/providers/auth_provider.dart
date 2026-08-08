import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false});

  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        state = state.copyWith(isLoading: false, isAuthenticated: true);
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // /auth/login is at the server root, not under /api/food, so use an
      // absolute URL to bypass the Dio baseUrl prefix.
      final response = await apiClient.dio.post('${ApiClient.host}/auth/login', data: {
        'username': username,
        'password': password,
        'role': 'restaurant',
      });

      if (response.statusCode == 200 && response.data['token'] != null) {
        final token = response.data['token'];
        await ApiClient.saveToken(token);
        apiClient.dio.options.headers['Authorization'] = 'Bearer $token'; // Update current instance
        state = state.copyWith(isLoading: false, isAuthenticated: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Login failed');
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data['message'] ?? 'Connection error');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> mockLogin() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 500));
    await ApiClient.saveToken('mock_token_123');
    state = state.copyWith(isLoading: false, isAuthenticated: true);
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    apiClient.dio.options.headers.remove('Authorization');
    state = state.copyWith(isAuthenticated: false);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
