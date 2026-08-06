import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchant_app/features/auth/data/auth_repository.dart';

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
  AuthNotifier(this._repository) : super(AuthState(isLoading: true)) {
    _init();
  }

  final AuthRepository _repository;

  Future<void> _init() async {
    try {
      final token = await _repository.currentToken();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: token != null);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token =
          await _repository.login(username: username, password: password);

      if (token == null) {
        if (!mounted) return false;
        state = state.copyWith(isLoading: false, error: 'Login failed');
        return false;
      }

      await _repository.persistToken(token);
      if (!mounted) return true;
      state = state.copyWith(isLoading: false, isAuthenticated: true);
      return true;
    } on DioException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data['message'] ?? 'Connection error');
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> mockLogin() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 500));
    await _repository.persistToken('mock_token_123');
    if (!mounted) return;
    state = state.copyWith(isLoading: false, isAuthenticated: true);
  }

  Future<void> logout() async {
    await _repository.forgetToken();
    if (!mounted) return;
    state = state.copyWith(isAuthenticated: false);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
