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
      var claims = token == null ? null : AuthClaims.tryParse(token);
      var usable = claims != null && claims.isRestaurant && !claims.isExpired;

      // The access token lives ~24h. If it is missing or expired but a refresh
      // token is still on disk, refresh silently rather than sending the
      // merchant back to login — so the session is "remembered" for as long as
      // the (much longer-lived) refresh token is valid.
      if (!usable) {
        final refreshed = await _tryRefreshSession();
        if (refreshed != null) {
          claims = refreshed;
          usable = refreshed.isRestaurant && !refreshed.isExpired;
        }
      }

      if (!mounted) return;
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

  /// Swaps a stored refresh token for a fresh session on startup. Returns the
  /// new claims, or null when there is no refresh token or the server rejects
  /// it (a real logout on another device, or an expired refresh token).
  Future<AuthClaims?> _tryRefreshSession() async {
    try {
      final refreshToken = await _repository.currentRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final tokens = await _repository.refresh(refreshToken);
      final claims = AuthClaims.tryParse(tokens.accessToken);
      if (claims == null) return null;
      await _repository.persistSession(tokens);
      return claims;
    } catch (_) {
      return null;
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
      throw AppFailure(_errorText(e, 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), e);
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
      throw AppFailure('เข้าสู่ระบบไม่สำเร็จ', e);
    }
  }

  /// Local `08…` → E.164 `+668…`; the OTP endpoints reject anything else.
  static String _toE164(String phone) {
    final p = phone.trim().replaceAll(' ', '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0')) return '+66${p.substring(1)}';
    return '+66$p';
  }

  /// Step 1 of phone auth: request an SMS OTP. Returns the `ref_id` +
  /// `is_registered` the OTP screen needs.
  Future<SendOtpResult> requestOtp(String phone) async {
    try {
      return await _repository.sendOtp(phone: _toE164(phone));
    } on DioException catch (e) {
      throw AppFailure(_errorText(e, 'ส่ง OTP ไม่สำเร็จ'), e);
    }
  }

  /// Step 2 of phone auth: verify the OTP. On success the server returns a
  /// session (creating the restaurant account on first sign-up); we persist it
  /// and flip [isAuthenticated] so the router lands on the home shell.
  Future<void> confirmOtp({
    required String phone,
    required String otp,
    required String refId,
    String fullName = '',
  }) async {
    try {
      final tokens = await _repository.verifyOtp(
        phone: _toE164(phone),
        otp: otp,
        refId: refId,
        fullName: fullName,
      );
      final claims = AuthClaims.tryParse(tokens.accessToken);
      if (claims == null) throw const AppFailure('ยืนยัน OTP ไม่สำเร็จ');
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
      rethrow;
    } on DioException catch (e) {
      throw AppFailure(_errorText(e, 'รหัส OTP ไม่ถูกต้อง'), e);
    }
  }

  /// Backend errors come back as `{error: …}` (OTP) or `{message: …}` (auth);
  /// fall back to a Thai default so nothing raw ever reaches the UI.
  /// Turns a [DioException] into something worth showing.
  ///
  /// A request that never reached the server is called out as such: without
  /// this, a backend that is simply not running looks identical to one that
  /// rejected the input, and there is nothing on screen to tell them apart.
  String _errorText(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['error'] ?? data['message'] ?? fallback).toString();
    }
    if (e.response == null) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'เซิร์ฟเวอร์ไม่ตอบสนอง กรุณาลองใหม่',
        _ => 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
      };
    }
    return fallback;
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

  /// Permanently deletes the account (SCRUM-114). Unlike [logout], the local
  /// session is cleared only on success — a failed call rethrows and leaves
  /// the merchant signed in, because their account still exists and they may
  /// want to retry.
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    await _repository.forgetSession();
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

/// Carries the in-progress phone number + `ref_id` from the phone screen to the
/// OTP screen (set by [AuthNotifier.requestOtp], read on OTP submit).
class OtpFlow {
  const OtpFlow({
    required this.phone,
    required this.refId,
    required this.isRegistered,
    required this.isLogin,
  });

  final String phone;
  final String refId;
  final bool isRegistered;
  final bool isLogin;
}

final otpFlowProvider = StateProvider<OtpFlow?>((ref) => null);
