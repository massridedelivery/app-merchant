import 'package:dio/dio.dart';
import 'package:merchant_app/core/config/google_config.dart';

/// A single Google Places Autocomplete prediction. Coordinates are resolved
/// lazily via [GooglePlacesService.placeDetails] only when the user selects it.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    this.description = '',
    this.mainText = '',
    this.secondaryText = '',
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

/// A resolved place with coordinates.
class PlaceResult {
  const PlaceResult({
    required this.lat,
    required this.lng,
    this.name = '',
    this.address = '',
    this.placeId,
  });

  final double lat;
  final double lng;
  final String name;
  final String address;
  final String? placeId;
}

/// Thin client for the Google Places web service (Autocomplete + Details).
///
/// Uses its own [Dio] so it never inherits the app's base URL or the
/// `Authorization` interceptor — Google rejects requests carrying an
/// unexpected bearer token.
class GooglePlacesService {
  GooglePlacesService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: GoogleConfig.placesBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  /// Autocomplete predictions for [input], biased around [lat]/[lng] when given.
  /// [sessionToken] groups Autocomplete + Details calls for billing.
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    double? lat,
    double? lng,
    String? sessionToken,
  }) async {
    _ensureConfigured();
    final response = await _dio.get(
      '/autocomplete/json',
      queryParameters: {
        'input': input,
        'key': GoogleConfig.placesApiKey,
        'language': GoogleConfig.language,
        'components': GoogleConfig.components,
        if (lat != null && lng != null) 'location': '$lat,$lng',
        if (lat != null && lng != null) 'radius': 30000,
        if (sessionToken != null) 'sessiontoken': sessionToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    _checkStatus(data);

    final predictions = (data['predictions'] as List<dynamic>? ?? []);
    return predictions
        .map((e) => _mapPrediction(e as Map<String, dynamic>))
        .toList();
  }

  /// Resolves a [placeId] into a [PlaceResult] with coordinates.
  Future<PlaceResult> placeDetails(String placeId, {String? sessionToken}) async {
    _ensureConfigured();
    final response = await _dio.get(
      '/details/json',
      queryParameters: {
        'place_id': placeId,
        'key': GoogleConfig.placesApiKey,
        'language': GoogleConfig.language,
        'fields': 'place_id,name,formatted_address,geometry/location',
        if (sessionToken != null) 'sessiontoken': sessionToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    _checkStatus(data);

    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw Exception('ไม่พบข้อมูลสถานที่');
    }
    return _mapDetails(result);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _ensureConfigured() {
    if (!GoogleConfig.isConfigured) {
      throw Exception('ยังไม่ได้ตั้งค่า Google Places API key (google_config.dart)');
    }
  }

  /// Google returns HTTP 200 even for logical errors; the real state is in
  /// the `status` field.
  void _checkStatus(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    if (status == 'OK' || status == 'ZERO_RESULTS') return;
    final msg = data['error_message'] as String?;
    throw Exception(msg ?? 'Google Places error: $status');
  }

  PlacePrediction _mapPrediction(Map<String, dynamic> json) {
    final structured =
        json['structured_formatting'] as Map<String, dynamic>? ?? const {};
    return PlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mainText: structured['main_text']?.toString() ??
          json['description']?.toString() ??
          '',
      secondaryText: structured['secondary_text']?.toString() ?? '',
    );
  }

  PlaceResult _mapDetails(Map<String, dynamic> json) {
    final location = (json['geometry'] as Map<String, dynamic>?)?['location']
        as Map<String, dynamic>?;
    return PlaceResult(
      placeId: json['place_id']?.toString(),
      name: json['name']?.toString() ?? '',
      address: json['formatted_address']?.toString() ?? '',
      lat: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location?['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
