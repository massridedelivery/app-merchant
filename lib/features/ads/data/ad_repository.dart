import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/ads/models/ad_campaign.dart';

class AdRepository {
  AdRepository(this._api);

  final ApiClient _api;

  /// Returns null when the restaurant has no campaign yet — the API answers
  /// either a 404 or a 200 with a `null` body.
  Future<AdCampaign?> fetchAd() async {
    try {
      final response = await _api.dio.get('/api/food/restaurant/ads');
      final data = response.data;
      if (data == null) return null;
      return AdCampaign.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> createAd({
    required double dailyBudget,
    required double bidPerClick,
  }) =>
      _api.dio.post('/api/food/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
      });

  Future<void> updateAd({
    required double dailyBudget,
    required double bidPerClick,
    required bool isActive,
  }) =>
      _api.dio.put('/api/food/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
        'is_active': isActive,
      });
}

final adRepositoryProvider = Provider<AdRepository>(
  (ref) => AdRepository(ref.watch(apiClientProvider)),
);
