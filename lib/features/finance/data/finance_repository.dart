import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

/// None of these endpoints exist. SCRUM-53 §16.1 is explicit: "No
/// merchant-facing earnings/wallet endpoint exists" — merchant money is
/// admin-side only today, and an earnings screen needs new backend work.
/// Everything here is served by MockInterceptor and will 404 for real.
class FinanceRepository {
  FinanceRepository(this._api);

  final ApiClient _api;

  Future<FinanceSummary> fetchSummary() async {
    final response = await _api.dio.get('/api/food/restaurant/finance/summary');
    return FinanceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final response = await _api.dio.get('/api/food/restaurant/finance/transactions');
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<FinanceEarnings> fetchEarnings() async {
    final response = await _api.dio.get('/api/food/restaurant/finance/earnings');
    return FinanceEarnings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> requestWithdrawal(double amount) =>
      _api.dio.post('/api/food/restaurant/withdraw', data: {'amount': amount});
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(apiClientProvider)),
);
