import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:dio/dio.dart';

class AdCampaign {
  final String id;
  final double dailyBudget;
  final double currentSpend;
  final double bidPerClick;
  final bool isActive;

  AdCampaign({
    required this.id,
    required this.dailyBudget,
    required this.currentSpend,
    required this.bidPerClick,
    required this.isActive,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: json['id'] ?? '',
      dailyBudget: json['daily_budget']?.toDouble() ?? 0.0,
      currentSpend: json['current_spend']?.toDouble() ?? 0.0,
      bidPerClick: json['bid_per_click']?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? false,
    );
  }
}

class AdNotifier extends StateNotifier<AsyncValue<AdCampaign?>> {
  AdNotifier(this._api) : super(const AsyncValue.loading());

  final ApiClient _api;

  Future<void> fetchAd() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.dio.get('/restaurant/ads');
      state = AsyncValue.data(AdCampaign.fromJson(response.data));
    } catch (e, st) {
      if (e is DioException && e.response?.statusCode == 404) {
        state = const AsyncValue.data(null); // No ad yet
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> createAd(double dailyBudget, double bidPerClick) async {
    try {
      await _api.dio.post('/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
      });
      fetchAd(); // Reload
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAd(double dailyBudget, double bidPerClick, bool isActive) async {
    try {
      await _api.dio.put('/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
        'is_active': isActive,
      });
      fetchAd(); // Reload
      return true;
    } catch (e) {
      return false;
    }
  }
}

final adProvider = StateNotifierProvider<AdNotifier, AsyncValue<AdCampaign?>>((ref) {
  return AdNotifier(ref.watch(apiClientProvider))..fetchAd();
});
