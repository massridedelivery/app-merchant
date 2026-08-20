import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/auth/models/auth_session.dart';

/// Auth lives outside the `/api` prefix — `{host}/auth/...` (SCRUM-53 §1, §2).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<TokenPair> login({
    required String email,
    required String password,
    String? deviceId,
    String? appVersion,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_id': ?deviceId,
      'app_version': ?appVersion,
    });
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  /// Registration also inserts a placeholder `restaurant_profiles` row in the
  /// same transaction, so `GET /profile` never 404s afterwards — incomplete
  /// onboarding has to be detected from the profile's contents instead.
  Future<TokenPair> register({
    required String email,
    required String phone,
    required String password,
    required String fullName,
    String? deviceId,
    String? appVersion,
  }) async {
    final response = await _api.dio.post('/auth/register', data: {
      'email': email,
      'phone': phone,
      'password': password,
      'full_name': fullName,
      'role': 'restaurant',
      'device_id': ?deviceId,
      'app_version': ?appVersion,
    });
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sends an SMS OTP to [phone] (E.164, e.g. `+66812345678`). The returned
  /// `ref_id` must be passed back to [verifyOtp]; `is_registered` says whether
  /// this is a login or a first-time sign-up.
  Future<SendOtpResult> sendOtp({
    required String phone,
    String? deviceId,
  }) async {
    final response = await _api.dio.post('/auth/otp/send', data: {
      'phone': phone,
      'device_id': ?deviceId,
    });
    return SendOtpResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Verifies the SMS [otp]. On success the server creates the session (and, for
  /// a new phone, the `restaurant` account + placeholder profile) and returns a
  /// token pair. [fullName] is only used when registering.
  Future<TokenPair> verifyOtp({
    required String phone,
    required String otp,
    required String refId,
    String fullName = '',
    String role = 'restaurant',
  }) async {
    final response = await _api.dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'otp': otp,
      'ref_id': refId,
      'full_name': fullName,
      'role': role,
    });
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final response = await _api.dio
        .post('/auth/refresh', data: {'refresh_token': refreshToken});
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  /// Revokes **every** refresh token for the account — this signs the merchant
  /// out on all their devices, not just this one.
  Future<void> logout() => _api.dio.post('/auth/logout');

  Future<String?> currentToken() => _api.readToken();

  Future<String?> currentRefreshToken() => _api.readRefreshToken();

  Future<void> persistSession(TokenPair tokens) => _api.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

  Future<void> forgetSession() => _api.clearSession();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
