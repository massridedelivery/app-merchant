import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';

class RestaurantProfileNotifier
    extends StateNotifier<AsyncValue<RestaurantProfile>> {
  RestaurantProfileNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  final ApiClient _api;

  Future<void> fetchProfile() async {
    try {
      final response = await _api.dio.get('/restaurant/profile');
      state = AsyncValue.data(
          RestaurantProfile.fromJson(response.data as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setStatus(RestaurantStatus newStatus) async {
    try {
      final isOpen = newStatus == RestaurantStatus.open;
      final isBusy = newStatus == RestaurantStatus.busy;

      if (newStatus == RestaurantStatus.open || newStatus == RestaurantStatus.paused) {
        await _api.dio.post('/restaurant/open', data: {'is_open': isOpen});
      }
      if (newStatus == RestaurantStatus.busy) {
        await _api.dio
            .post('/restaurant/busy', data: {'is_busy': isBusy});
      }

      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(
            isOpen: isOpen,
            isBusy: isBusy,
            status: newStatus,
          ),
        );
      }
    } catch (e) {
      // Handle gracefully
    }
  }

  Future<void> toggleOpenStatus(bool isOpen) async {
    await setStatus(
        isOpen ? RestaurantStatus.open : RestaurantStatus.paused);
  }

  Future<void> toggleBusyMode(bool isBusy, {int? durationMin}) async {
    await setStatus(
        isBusy ? RestaurantStatus.busy : RestaurantStatus.open);
  }

  void incrementPreparingCount() {
    if (state.hasValue) {
      state = AsyncValue.data(
          state.value!.copyWith(preparingCount: state.value!.preparingCount + 1));
    }
  }
}

final restaurantProfileProvider = StateNotifierProvider<
    RestaurantProfileNotifier, AsyncValue<RestaurantProfile>>(
  (ref) => RestaurantProfileNotifier(ref.watch(apiClientProvider)),
);
