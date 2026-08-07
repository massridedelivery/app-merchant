import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';

class RestaurantRepository {
  RestaurantRepository(this._api);

  final ApiClient _api;

  Future<RestaurantProfile> fetchProfile() async {
    final response = await _api.dio.get('/api/food/restaurant/profile');
    return RestaurantProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PUT /restaurant/profile` (1.2). The guide's body has no phone or manager
  /// fields, so those stay read-only in the app even though the app's model
  /// carries them.
  Future<void> updateProfile({
    required String name,
    String? description,
    String? cuisineType,
    String? address,
    double? minOrderAmount,
  }) =>
      _api.dio.put('/api/food/restaurant/profile', data: {
        'restaurant_name': name,
        'description': ?description,
        'cuisine_type': ?cuisineType,
        'address': ?address,
        'min_order_amount': ?minOrderAmount,
      });

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
    return (response.data as List)
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
