import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/ads/data/ad_repository.dart';
import 'package:merchant_app/features/ads/models/ad_campaign.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

class AdNotifier extends StateNotifier<AsyncValue<AdCampaign?>> {
  AdNotifier(this._repository) : super(const AsyncValue.loading());

  final AdRepository _repository;

  Future<void> fetchAd() async {
    state = const AsyncValue.loading();
    try {
      // null means the restaurant has no campaign yet, not a failure.
      final campaign = await _repository.fetchAd();
      if (!mounted) return;
      state = AsyncValue.data(campaign);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createAd(double dailyBudget, double bidPerClick) async {
    try {
      await _repository.createAd(
        dailyBudget: dailyBudget,
        bidPerClick: bidPerClick,
      );
      fetchAd(); // Reload
    } catch (e) {
      throw AppFailure('ไม่สามารถสร้างแคมเปญโฆษณาได้', e);
    }
  }

  Future<void> updateAd(
      double dailyBudget, double bidPerClick, bool isActive) async {
    try {
      await _repository.updateAd(
        dailyBudget: dailyBudget,
        bidPerClick: bidPerClick,
        isActive: isActive,
      );
      fetchAd(); // Reload
    } catch (e) {
      throw AppFailure('ไม่สามารถแก้ไขแคมเปญโฆษณาได้', e);
    }
  }
}

final adProvider =
    StateNotifierProvider<AdNotifier, AsyncValue<AdCampaign?>>((ref) {
  // Rebuild on account change so the ad campaign never carries over.
  ref.watch(restaurantIdProvider);
  return AdNotifier(ref.watch(adRepositoryProvider))..fetchAd();
});
