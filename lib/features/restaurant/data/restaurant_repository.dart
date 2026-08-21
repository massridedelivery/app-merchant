import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
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
  /// [logoFileKey] / [coverFileKey] are media `file_key`s (from MediaRepository,
  /// category `restaurant`) — not URLs. Send them only when the image changed.
  ///
  /// Contact fields (phone / manager* / email / taxId) are accepted since
  /// v1.6.1-dev11 (SCRUM-80). Everything is patch-style: an omitted field keeps
  /// its stored value. The backend validates formats (400) and rejects editing
  /// `tax_id` once the shop is verified with a tax id on file (403) — surfaced
  /// as an [AppFailure] with a Thai message.
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
    String? logoFileKey,
    String? coverFileKey,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    String? taxId,
  }) async {
    try {
      await _api.dio.put('/api/food/restaurant/profile', data: {
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
        'logo_url': ?logoFileKey,
        'cover_image_url': ?coverFileKey,
        'phone': ?phone,
        'email': ?email,
        'manager_name': ?managerName,
        'manager_phone': ?managerPhone,
        'manager_email': ?managerEmail,
        'tax_id': ?taxId,
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final serverMsg =
          data is Map ? (data['message'] ?? data['error'])?.toString() : null;
      if (status == 403) {
        throw AppFailure(
          'แก้ไขเลขประจำตัวผู้เสียภาษีไม่ได้ เนื่องจากร้านผ่านการยืนยันแล้ว '
          'กรุณาติดต่อแอดมิน',
          e,
        );
      }
      if (status == 400) {
        throw AppFailure(serverMsg ?? 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง', e);
      }
      rethrow;
    }
  }

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
