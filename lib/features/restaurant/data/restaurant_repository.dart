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

  Future<void> setOpen(bool isOpen) =>
      _api.dio.post('/restaurant/open', data: {'is_open': isOpen});

  Future<void> setBusy(bool isBusy) =>
      _api.dio.post('/restaurant/busy', data: {'is_busy': isBusy});
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => RestaurantRepository(ref.watch(apiClientProvider)),
);
