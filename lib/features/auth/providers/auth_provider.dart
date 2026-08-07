import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/features/auth/data/auth_repository.dart';
import 'package:merchant_app/features/auth/models/auth_session.dart';

// State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;

  /// Decoded from the access token. `claims.userId` is the `restaurant_id`
  /// every food endpoint keys off (SCRUM-53 §2).
  final AuthClaims? claims;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.claims,
  });

  String? get restaurantId => claims?.userId;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    AuthClaims? claims,
    bool clearClaims = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      claims: clearClaims ? null : (claims ?? this.claims),
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
      final claims = token == null ? null : AuthClaims.tryParse(token);
      if (!mounted) return;
      // An expired or non-restaurant token is treated as no session at all.
      final usable = claims != null && claims.isRestaurant && !claims.isExpired;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: usable,
        claims: usable ? claims : null,
        clearClaims: !usable,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final tokens = await _repository.login(email: email, password: password);

      // Login does not check the role server-side, so the client must.
      final claims = AuthClaims.tryParse(tokens.accessToken);
      if (claims == null) {
        throw const AppFailure('เข้าสู่ระบบไม่สำเร็จ');
      }
      if (!claims.isRestaurant) {
        throw const AppFailure('บัญชีนี้ไม่ใช่บัญชีร้านค้า');
      }

      await _repository.persistSession(tokens);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        claims: claims,
      );
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

  /// Shortcut used by the onboarding screens while the real flow is stubbed.
  /// Deliberately runs the same path as [login] so claims, the role check and
  /// the restaurant id all behave identically against MockInterceptor.
  Future<void> mockLogin() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await login('owner@somchai-kitchen.co.th', 'Sup3rSecret!');
  }

  /// Signs out everywhere — the endpoint revokes every refresh token on the
  /// account. The local session is dropped even if the call fails, so a network
  /// blip cannot strand the merchant in a logged-in shell.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Ignored on purpose; clearing locally is what signs this device out.
    } finally {
      await _repository.forgetSession();
    }
    if (!mounted) return;
    state = state.copyWith(isAuthenticated: false, clearClaims: true);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// The merchant's own id, which doubles as the `restaurant_id` in every food
/// endpoint. Null until a session is loaded.
final restaurantIdProvider = Provider<String?>(
  (ref) => ref.watch(authProvider).restaurantId,
);
