import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/ads/models/ad_campaign.dart';

class AdRepository {
  AdRepository(this._api);

  final ApiClient _api;

  /// Returns null when the restaurant has no campaign yet — the API answers
  /// 404 rather than an empty body.
  Future<AdCampaign?> fetchAd() async {
    try {
      final response = await _api.dio.get('/restaurant/ads');
      return AdCampaign.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> createAd({
    required double dailyBudget,
    required double bidPerClick,
  }) =>
      _api.dio.post('/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
      });

  Future<void> updateAd({
    required double dailyBudget,
    required double bidPerClick,
    required bool isActive,
  }) =>
      _api.dio.put('/restaurant/ads', data: {
        'daily_budget': dailyBudget,
        'bid_per_click': bidPerClick,
        'is_active': isActive,
      });
}

final adRepositoryProvider = Provider<AdRepository>(
  (ref) => AdRepository(ref.watch(apiClientProvider)),
);
