import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

class FinanceSummaryNotifier extends StateNotifier<AsyncValue<FinanceSummary>> {
  FinanceSummaryNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetch();
  }

  final FinanceRepository _repository;

  Future<void> fetch() async {
    try {
      final summary = await _repository.fetchSummary();
      if (!mounted) return;
      state = AsyncValue.data(summary);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final financeSummaryProvider =
    StateNotifierProvider<FinanceSummaryNotifier, AsyncValue<FinanceSummary>>(
        (ref) => FinanceSummaryNotifier(ref.watch(financeRepositoryProvider)));

class FinanceTransactionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  FinanceTransactionsNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  final FinanceRepository _repository;

  Future<void> fetch() async {
    try {
      final transactions = await _repository.fetchTransactions();
      if (!mounted) return;
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final financeTransactionsProvider = StateNotifierProvider<
    FinanceTransactionsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => FinanceTransactionsNotifier(ref.watch(financeRepositoryProvider)),
);

class FinanceEarningsNotifier
    extends StateNotifier<AsyncValue<FinanceEarnings>> {
  FinanceEarningsNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  final FinanceRepository _repository;

  Future<void> fetch() async {
    try {
      final earnings = await _repository.fetchEarnings();
      if (!mounted) return;
      state = AsyncValue.data(earnings);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final financeEarningsProvider =
    StateNotifierProvider<FinanceEarningsNotifier, AsyncValue<FinanceEarnings>>(
        (ref) => FinanceEarningsNotifier(ref.watch(financeRepositoryProvider)));
