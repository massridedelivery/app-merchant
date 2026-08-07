import 'dart:convert';

/// The token pair returned by `/auth/login`, `/auth/register` and
/// `/auth/refresh` (SCRUM-53 §2).
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;

  /// Seconds. Defaults to 24h server-side but is env-configurable, so this is
  /// always read rather than assumed.
  final int expiresIn;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}

/// Claims carried by the HS256 access token.
///
/// There is no `/me` endpoint — the user id and role are only available by
/// decoding the token, and `user_id` **is** the `restaurant_id` used across the
/// food API (SCRUM-53 §2).
class AuthClaims {
  const AuthClaims({
    required this.userId,
    required this.role,
    this.sessionId,
    this.expiresAt,
  });

  final String userId;
  final String role;
  final String? sessionId;
  final DateTime? expiresAt;

  bool get isRestaurant => role == 'restaurant';

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Reads the payload segment. **Not** a signature check — the server is the
  /// only party that can validate the token; this is purely to learn who we are.
  static AuthClaims? tryParse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;

      final userId = payload['user_id'];
      final role = payload['role'];
      if (userId is! String || role is! String) return null;

      final exp = payload['exp'];
      return AuthClaims(
        userId: userId,
        role: role,
        sessionId: payload['sid'] as String?,
        expiresAt: exp is int
            ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
