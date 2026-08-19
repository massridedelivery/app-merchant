import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

class FinanceSummaryNotifier extends StateNotifier<AsyncValue<FinanceSummary>> {
  FinanceSummaryNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetch();
  }

  final FinanceRepository _repository;

  Future<void> fetch() async {
    state = const AsyncValue.loading();
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

/// Paginated transactions ledger. [loadMore] appends the next page.
class FinanceTransactionsNotifier
    extends StateNotifier<AsyncValue<TransactionsPage>> {
  FinanceTransactionsNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  final FinanceRepository _repository;
  static const _pageSize = 20;
  bool _loadingMore = false;

  Future<void> fetch() async {
    try {
      final page = await _repository.fetchTransactions(limit: _pageSize);
      if (!mounted) return;
      state = AsyncValue.data(page);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _repository.fetchTransactions(
        limit: _pageSize,
        offset: current.offset + current.items.length,
      );
      if (!mounted) return;
      state = AsyncValue.data(TransactionsPage(
        items: [...current.items, ...next.items],
        total: next.total,
        limit: next.limit,
        offset: current.offset,
        hasMore: next.hasMore,
      ));
    } catch (_) {
      // keep the pages already loaded
    } finally {
      _loadingMore = false;
    }
  }
}

final financeTransactionsProvider = StateNotifierProvider<
    FinanceTransactionsNotifier, AsyncValue<TransactionsPage>>(
  (ref) => FinanceTransactionsNotifier(ref.watch(financeRepositoryProvider)),
);

/// Withdrawal history (`GET /restaurant/withdrawals`).
final withdrawalsProvider =
    FutureProvider.autoDispose<List<WithdrawalRequest>>((ref) {
  return ref.watch(financeRepositoryProvider).fetchWithdrawals();
});
