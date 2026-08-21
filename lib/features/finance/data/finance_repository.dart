import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/finance/models/bank_account.dart';
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

  // ─── Bank account (SCRUM-60) ─────────────────────────────────────────────

  /// `GET /restaurant/bank-account`. Returns empty strings (not 404) when the
  /// shop has never linked an account.
  Future<BankAccount> fetchBankAccount() async {
    final response =
        await _api.dio.get('/api/food/restaurant/bank-account');
    return BankAccount.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PUT /restaurant/bank-account`. All three fields are REQUIRED every time —
  /// the account number can't be read back, so a change means re-typing it in
  /// full. Only the `bank_code` is sent (the server resolves the bank name).
  /// An unknown bank code is rejected with 400.
  Future<void> updateBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      await _api.dio.put('/api/food/restaurant/bank-account', data: {
        'bank_code': bankCode,
        'account_number': accountNumber,
        'account_name': accountName,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg =
          data is Map ? (data['message'] ?? data['error'])?.toString() : null;
      if (e.response?.statusCode == 400) {
        throw AppFailure(serverMsg ?? 'ข้อมูลบัญชีไม่ถูกต้อง กรุณาตรวจสอบ', e);
      }
      throw AppFailure('บันทึกบัญชีธนาคารไม่สำเร็จ', e);
    }
  }

  // ─── Auto-payout (SCRUM-77) ──────────────────────────────────────────────

  /// `GET /restaurant/finance/auto-payout`. Returns defaults (not 404) when
  /// never set.
  Future<AutoPayoutSettings> fetchAutoPayout() async {
    final response =
        await _api.dio.get('/api/food/restaurant/finance/auto-payout');
    return AutoPayoutSettings.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PUT /restaurant/finance/auto-payout` — patch: send only what changed.
  /// `min_amount` < 100 or `day_of_week` outside 0–6 is rejected with 400.
  Future<void> updateAutoPayout({
    bool? enabled,
    int? dayOfWeek,
    double? minAmount,
  }) async {
    try {
      await _api.dio.put('/api/food/restaurant/finance/auto-payout', data: {
        'enabled': ?enabled,
        'day_of_week': ?dayOfWeek,
        'min_amount': ?minAmount,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg =
          data is Map ? (data['message'] ?? data['error'])?.toString() : null;
      if (e.response?.statusCode == 400) {
        throw AppFailure(serverMsg ?? 'ตั้งค่าไม่ถูกต้อง กรุณาตรวจสอบ', e);
      }
      throw AppFailure('บันทึกการตั้งค่าไม่สำเร็จ', e);
    }
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
