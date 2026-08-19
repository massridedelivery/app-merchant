import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/models/store_hours.dart';

class RestaurantRepository {
  RestaurantRepository(this._api);

  final ApiClient _api;

  Future<RestaurantProfile> fetchProfile() async {
    final response = await _api.dio.get('/api/food/restaurant/profile');
    return RestaurantProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PUT /restaurant/profile` (SCRUM-53 §3). Send only what changed; the
  /// response echoes the request body rather than a full profile.
  ///
  /// The documented body has no phone or manager fields, so those stay
  /// read-only in the app even though the model carries them.
  Future<void> updateProfile({
    required String name,
    String? nameTh,
    String? description,
    String? cuisineType,
    String? address,
    double? lat,
    double? lng,
    double? minOrderAmount,
    String? openingTime,
    String? closingTime,
    String? timezone,
  }) =>
      _api.dio.put('/api/food/restaurant/profile', data: {
        'restaurant_name': name,
        'restaurant_name_th': ?nameTh,
        'description': ?description,
        'cuisine_type': ?cuisineType,
        'address': ?address,
        'lat': ?lat,
        'lng': ?lng,
        'min_order_amount': ?minOrderAmount,
        // HH:MM exactly, 24h, or the call 400s.
        'opening_time': ?openingTime,
        'closing_time': ?closingTime,
        'timezone': ?timezone,
      });

  // ─── Opening hours (SCRUM-63) ────────────────────────────────────────────

  Future<StoreHours> fetchHours() async {
    final response = await _api.dio.get('/api/food/restaurant/hours');
    return StoreHours.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PUT /restaurant/hours` — must send all 7 days or the call is rejected.
  Future<void> updateHours(StoreHours hours) =>
      _api.dio.put('/api/food/restaurant/hours', data: hours.toJson());

  Future<void> setOpen(bool isOpen) =>
      _api.dio.post('/api/food/restaurant/open', data: {'is_open': isOpen});

  Future<void> setBusy(bool isBusy, {int? durationMin}) =>
      _api.dio.post('/api/food/restaurant/busy', data: {
        // `is_busy` must be present or the call 400s (SCRUM-53 §4).
        'is_busy': isBusy,
        'duration_min': ?durationMin,
      });

  // ─── KYC documents (SCRUM-53 §8) ─────────────────────────────────────────

  Future<List<RestaurantDocument>> fetchDocuments() async {
    final response = await _api.dio.get('/api/food/restaurant/documents');
    // The endpoint returns `null` (not []) when there are no documents.
    return (response.data as List? ?? [])
        .map((j) => RestaurantDocument.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// [fileKey] comes from the media upload — it is not a URL or a local path,
  /// and KYC cannot be completed without going through MediaRepository first.
  Future<void> submitDocument({
    required String docType,
    required String fileKey,
    String? docNumber,
  }) =>
      _api.dio.post('/api/food/restaurant/documents', data: {
        'doc_type': docType,
        'file_key': fileKey,
        'doc_number': ?docNumber,
      });
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => RestaurantRepository(ref.watch(apiClientProvider)),
);
