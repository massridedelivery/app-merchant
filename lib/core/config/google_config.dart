import 'package:flutter/foundation.dart';

/// Configuration for direct Google Maps Platform (Places web service) calls.
///
/// NOTE: These keys must have the **Places API** enabled. For the Places web
/// service, restrict by API ("Places API") and optionally IP/HTTP-referrer —
/// application (bundle-id / package) restrictions do NOT apply to web-service
/// HTTP calls.
///
/// The Maps SDK keys that render the actual map live natively in
/// `android/app/build.gradle.kts` (manifestPlaceholders) and
/// `ios/Runner/Info.plist` (GOOGLE_MAPS_API_KEY) and are a separate concern.
/// Those render keys ARE app-restricted, so `com.mass.merchantApp(.dev)` /
/// the Android package must be whitelisted on the key in Google Cloud.
abstract class GoogleConfig {
  // Shared org Places-API keys (same as the customer app).
  static const String _androidPlacesApiKey =
      'AIzaSyBO2_0D2M89FTl1shkEczC1klunUrOqlFs';
  static const String _iosPlacesApiKey =
      'AIzaSyAlgz6GR3iQ-u0elel8OAnnGow0FlSMe2M';

  /// The Places API key for the current platform.
  static String get placesApiKey {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _iosPlacesApiKey;
      default:
        return _androidPlacesApiKey;
    }
  }

  /// Base URL for the legacy Places web service.
  static const String placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';

  /// Language + region bias for results (Thai / Thailand).
  static const String language = 'th';
  static const String components = 'country:th';

  /// Default map centre when the store has no location yet (central Bangkok).
  static const double defaultLat = 13.7563;
  static const double defaultLng = 100.5018;

  static bool get isConfigured => placesApiKey.isNotEmpty;
}
