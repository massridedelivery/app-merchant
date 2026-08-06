import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';

class RestaurantProfileNotifier
    extends StateNotifier<AsyncValue<RestaurantProfile>> {
  RestaurantProfileNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  final RestaurantRepository _repository;

  Future<void> fetchProfile() async {
    try {
      final profile = await _repository.fetchProfile();
      if (!mounted) return;
      state = AsyncValue.data(profile);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setStatus(RestaurantStatus newStatus) async {
    try {
      final isOpen = newStatus == RestaurantStatus.open;
      final isBusy = newStatus == RestaurantStatus.busy;

      if (newStatus == RestaurantStatus.open ||
          newStatus == RestaurantStatus.paused) {
        await _repository.setOpen(isOpen);
      }
      if (newStatus == RestaurantStatus.busy) {
        await _repository.setBusy(isBusy);
      }

      if (!mounted || !state.hasValue) return;
      state = AsyncValue.data(
        state.value!.copyWith(
          isOpen: isOpen,
          isBusy: isBusy,
          status: newStatus,
        ),
      );
    } catch (e) {
      // Handle gracefully
    }
  }

  Future<void> toggleOpenStatus(bool isOpen) async {
    await setStatus(isOpen ? RestaurantStatus.open : RestaurantStatus.paused);
  }

  Future<void> toggleBusyMode(bool isBusy, {int? durationMin}) async {
    await setStatus(isBusy ? RestaurantStatus.busy : RestaurantStatus.open);
  }

  void incrementPreparingCount() {
    if (state.hasValue) {
      state = AsyncValue.data(state.value!
          .copyWith(preparingCount: state.value!.preparingCount + 1));
    }
  }
}

final restaurantProfileProvider = StateNotifierProvider<
    RestaurantProfileNotifier, AsyncValue<RestaurantProfile>>(
  (ref) => RestaurantProfileNotifier(ref.watch(restaurantRepositoryProvider)),
);
