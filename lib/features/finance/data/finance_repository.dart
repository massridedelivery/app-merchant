import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

/// Note: none of these paths appear in RESTAURANT_API_GUIDE.md. They are served
/// by MockInterceptor today and will 404 against a real backend until the
/// endpoints exist.
class FinanceRepository {
  FinanceRepository(this._api);

  final ApiClient _api;

  Future<FinanceSummary> fetchSummary() async {
    final response = await _api.dio.get('/restaurant/finance/summary');
    return FinanceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final response = await _api.dio.get('/restaurant/finance/transactions');
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<FinanceEarnings> fetchEarnings() async {
    final response = await _api.dio.get('/restaurant/finance/earnings');
    return FinanceEarnings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> requestWithdrawal(double amount) =>
      _api.dio.post('/restaurant/withdraw', data: {'amount': amount});
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(apiClientProvider)),
);
