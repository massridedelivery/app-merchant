import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

/// Merchant finance + withdrawal endpoints (SCRUM-60), live on driver-api.
class FinanceRepository {
  FinanceRepository(this._api);

  final ApiClient _api;

  Future<FinanceSummary> fetchSummary() async {
    final response =
        await _api.dio.get('/api/food/restaurant/finance/summary');
    return FinanceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinanceEarnings> fetchEarnings() async {
    final response =
        await _api.dio.get('/api/food/restaurant/finance/earnings');
    return FinanceEarnings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TransactionsPage> fetchTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.dio.get(
      '/api/food/restaurant/finance/transactions',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return TransactionsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<WithdrawalRequest>> fetchWithdrawals() async {
    final response = await _api.dio.get('/api/food/restaurant/withdrawals');
    return (response.data as List? ?? [])
        .map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /restaurant/withdraw` — minimum 100 THB. The backend rejects when
  /// the available balance is too low or a withdrawal is already pending;
  /// surface that message rather than a raw Dio error.
  Future<void> requestWithdrawal(double amount) async {
    try {
      await _api.dio
          .post('/api/food/restaurant/withdraw', data: {'amount': amount});
    } on DioException catch (e) {
      throw AppFailure(_withdrawError(e), e);
    }
  }

  String _withdrawError(DioException e) {
    final data = e.response?.data;
    final serverMsg = data is Map
        ? (data['message'] ?? data['error'])?.toString()
        : null;
    if (serverMsg != null && serverMsg.isNotEmpty) {
      final lower = serverMsg.toLowerCase();
      if (lower.contains('insufficient') || lower.contains('balance')) {
        return 'ยอดเงินที่ถอนได้ไม่เพียงพอ';
      }
      if (lower.contains('pending') || lower.contains('existing')) {
        return 'มีคำขอถอนเงินที่รอดำเนินการอยู่แล้ว';
      }
      if (lower.contains('min') || lower.contains('100')) {
        return 'ถอนขั้นต่ำ 100 บาท';
      }
      return serverMsg;
    }
    return 'ส่งคำขอถอนเงินไม่สำเร็จ';
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(apiClientProvider)),
);
