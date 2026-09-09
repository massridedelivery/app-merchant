import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

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

  /// The endpoint echoes only the fields it accepts, so rather than rebuild the
  /// profile from the response the edited values are folded into the copy the
  /// app already holds.
  Future<void> updateProfile({
    required String name,
    String? description,
    String? cuisineType,
    String? address,
    double? lat,
    double? lng,
    double? minOrderAmount,
    String? logoFileKey,
    String? coverFileKey,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    String? taxId,
  }) async {
    final hasContact = phone != null ||
        email != null ||
        managerName != null ||
        managerPhone != null ||
        managerEmail != null ||
        taxId != null;
    try {
      await _repository.updateProfile(
        name: name,
        description: description,
        cuisineType: cuisineType,
        address: address,
        lat: lat,
        lng: lng,
        minOrderAmount: minOrderAmount,
        logoFileKey: logoFileKey,
        coverFileKey: coverFileKey,
        phone: phone,
        email: email,
        managerName: managerName,
        managerPhone: managerPhone,
        managerEmail: managerEmail,
        taxId: taxId,
      );
    } on AppFailure {
      rethrow; // keep the specific 403/400 message from the repository
    } catch (e) {
      throw AppFailure('ไม่สามารถบันทึกข้อมูลร้านได้', e);
    }
    if (!mounted || !state.hasValue) return;
    // Images are read back as URLs (not the file_key we sent) and contact fields
    // aren't carried by copyWith, so re-fetch to get the canonical values.
    if (logoFileKey != null || coverFileKey != null || hasContact) {
      await fetchProfile();
      return;
    }
    state = AsyncValue.data(state.value!.copyWith(
      name: name,
      description: description,
      cuisineType: cuisineType,
      address: address,
      lat: lat,
      lng: lng,
      minOrderAmount: minOrderAmount,
    ));
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
      throw AppFailure('ไม่สามารถเปลี่ยนสถานะร้านได้', e);
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
  (ref) {
    // Rebuild (and re-fetch) whenever the signed-in account changes, so a new
    // login never shows the previous merchant's cached profile.
    ref.watch(restaurantIdProvider);
    return RestaurantProfileNotifier(ref.watch(restaurantRepositoryProvider));
  },
);
