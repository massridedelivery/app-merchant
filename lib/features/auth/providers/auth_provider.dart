import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/notification_service.dart';
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

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // /auth/login is at the server root, not under /api/food, so use an
      // absolute URL to bypass the Dio baseUrl prefix.
      // Backend contract: body uses `email` (not `username`), there is no
      // `role` field (role lives in the JWT), and the response is a TokenPair
      // { access_token, refresh_token, expires_in } — not { token }.
      final response = await apiClient.dio.post('${ApiClient.host}/auth/login', data: {
        'email': email,
        'password': password,
      });

      final accessToken = response.data['access_token'];
      if (response.statusCode == 200 && accessToken != null) {
        await ApiClient.saveToken(accessToken as String);
        final refreshToken = response.data['refresh_token'];
        if (refreshToken != null) {
          await ApiClient.saveRefreshToken(refreshToken as String);
        }
        apiClient.dio.options.headers['Authorization'] = 'Bearer $accessToken'; // Update current instance
        // Register this device for push once we're authenticated (no-op until
        // Firebase Messaging is wired — see NotificationService).
        unawaited(notificationService.registerCurrentDevice());
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
    await notificationService.unregisterCurrentDevice();
    await ApiClient.clearToken();
    apiClient.dio.options.headers.remove('Authorization');
    state = state.copyWith(isAuthenticated: false);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
