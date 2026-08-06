import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchant_app/features/auth/data/auth_repository.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

// State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;

  AuthState({this.isLoading = false, this.isAuthenticated = false});

  AuthState copyWith({bool? isLoading, bool? isAuthenticated}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
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

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final token =
          await _repository.login(username: username, password: password);

      if (token == null) {
        throw const AppFailure('เข้าสู่ระบบไม่สำเร็จ');
      }

      await _repository.persistToken(token);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } on AppFailure {
      if (mounted) state = state.copyWith(isLoading: false);
      rethrow;
    } on DioException catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
      throw AppFailure(
          e.response?.data['message'] ?? 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', e);
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
      throw AppFailure('เข้าสู่ระบบไม่สำเร็จ', e);
    }
  }

  Future<void> mockLogin() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _repository.persistToken('mock_token_123');
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
      throw AppFailure('เข้าสู่ระบบไม่สำเร็จ', e);
    }
    if (!mounted) return;
    state = state.copyWith(isLoading: false, isAuthenticated: true);
  }

  Future<void> logout() async {
    try {
      await _repository.forgetToken();
    } catch (e) {
      throw AppFailure('ออกจากระบบไม่สำเร็จ', e);
    }
    if (!mounted) return;
    state = state.copyWith(isAuthenticated: false);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
