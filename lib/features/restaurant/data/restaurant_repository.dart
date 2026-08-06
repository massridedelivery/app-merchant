import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';

class RestaurantRepository {
  RestaurantRepository(this._api);

  final ApiClient _api;

  Future<RestaurantProfile> fetchProfile() async {
    final response = await _api.dio.get('/restaurant/profile');
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
      _api.dio.put('/restaurant/profile', data: {
        'restaurant_name': name,
        'description': ?description,
        'cuisine_type': ?cuisineType,
        'address': ?address,
        'min_order_amount': ?minOrderAmount,
      });

  Future<void> setOpen(bool isOpen) =>
      _api.dio.post('/restaurant/open', data: {'is_open': isOpen});

  Future<void> setBusy(bool isBusy) =>
      _api.dio.post('/restaurant/busy', data: {'is_busy': isBusy});
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => RestaurantRepository(ref.watch(apiClientProvider)),
);
