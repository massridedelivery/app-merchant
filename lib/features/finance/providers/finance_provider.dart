import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class FinanceSummary {
  final double totalRevenue;
  final int totalOrders;
  final double avgOrderValue;
  final double pendingPayout;

  FinanceSummary({
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.pendingPayout,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      totalRevenue: (json['total_revenue'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      avgOrderValue: (json['avg_order_value'] ?? 0.0).toDouble(),
      pendingPayout: (json['pending_payout'] ?? 0.0).toDouble(),
    );
  }
}

class FinanceEarnings {
  final double balance;
  final double pending;
  final List<Map<String, dynamic>> transactions;

  FinanceEarnings({
    required this.balance,
    required this.pending,
    required this.transactions,
  });

  factory FinanceEarnings.fromJson(Map<String, dynamic> json) {
    return FinanceEarnings(
      balance: (json['balance'] ?? 0.0).toDouble(),
      pending: (json['pending'] ?? 0.0).toDouble(),
      transactions: List<Map<String, dynamic>>.from(json['transactions'] ?? []),
    );
  }
}

// ─── Providers ──────────────────────────────────────────────────────────────

class FinanceSummaryNotifier
    extends StateNotifier<AsyncValue<FinanceSummary>> {
  FinanceSummaryNotifier(this._api) : super(const AsyncValue.loading()) {
    fetch();
  }

  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final response =
          await _api.dio.get('/restaurant/finance/summary');
      state = AsyncValue.data(FinanceSummary.fromJson(
          response.data as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final financeSummaryProvider =
    StateNotifierProvider<FinanceSummaryNotifier, AsyncValue<FinanceSummary>>(
        (ref) => FinanceSummaryNotifier(ref.watch(apiClientProvider)));

class FinanceTransactionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  FinanceTransactionsNotifier(this._api) : super(const AsyncValue.loading()) {
    fetch();
  }

  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final response =
          await _api.dio.get('/restaurant/finance/transactions');
      state =
          AsyncValue.data(List<Map<String, dynamic>>.from(response.data as List));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final financeTransactionsProvider = StateNotifierProvider<
    FinanceTransactionsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => FinanceTransactionsNotifier(ref.watch(apiClientProvider)),
);

class FinanceEarningsNotifier
    extends StateNotifier<AsyncValue<FinanceEarnings>> {
  FinanceEarningsNotifier(this._api) : super(const AsyncValue.loading()) {
    fetch();
  }

  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final response =
          await _api.dio.get('/restaurant/finance/earnings');
      state = AsyncValue.data(
          FinanceEarnings.fromJson(response.data as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final financeEarningsProvider =
    StateNotifierProvider<FinanceEarningsNotifier, AsyncValue<FinanceEarnings>>(
        (ref) => FinanceEarningsNotifier(ref.watch(apiClientProvider)));
