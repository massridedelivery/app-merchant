// Models for the merchant finance endpoints (SCRUM-60). Shapes verified against
// staging (driver-api-dev):
//   GET /restaurant/finance/summary       -> FinanceSummary
//   GET /restaurant/finance/earnings      -> FinanceEarnings (4 periods)
//   GET /restaurant/finance/transactions  -> TransactionsPage (paginated)
//   GET /restaurant/withdrawals           -> List<WithdrawalRequest>

double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// `GET /restaurant/finance/summary`.
class FinanceSummary {
  final double balance;
  final double availableBalance;
  final double pendingWithdrawal;
  final double lifetimeEarnings;
  final double totalWithdrawn;
  final bool canWithdraw;

  FinanceSummary({
    required this.balance,
    required this.availableBalance,
    required this.pendingWithdrawal,
    required this.lifetimeEarnings,
    required this.totalWithdrawn,
    required this.canWithdraw,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        balance: _toDouble(json['balance']),
        availableBalance: _toDouble(json['available_balance']),
        pendingWithdrawal: _toDouble(json['pending_withdrawal']),
        lifetimeEarnings: _toDouble(json['lifetime_earnings']),
        totalWithdrawn: _toDouble(json['total_withdrawn']),
        canWithdraw: json['can_withdraw'] == true,
      );
}

/// One earnings bucket inside [FinanceEarnings].
class EarningsPeriod {
  final double grossFood;
  final double commission;
  final double withholdingTax;
  final double netEarnings;
  final int orders;

  EarningsPeriod({
    required this.grossFood,
    required this.commission,
    required this.withholdingTax,
    required this.netEarnings,
    required this.orders,
  });

  factory EarningsPeriod.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return EarningsPeriod(
      grossFood: _toDouble(j['gross_food']),
      commission: _toDouble(j['commission']),
      withholdingTax: _toDouble(j['withholding_tax']),
      netEarnings: _toDouble(j['net_earnings']),
      orders: _toInt(j['orders']),
    );
  }

  static final zero = EarningsPeriod.fromJson(const {});
}

/// `GET /restaurant/finance/earnings` — four fixed periods.
class FinanceEarnings {
  final EarningsPeriod today;
  final EarningsPeriod thisWeek;
  final EarningsPeriod thisMonth;
  final EarningsPeriod thisYear;

  FinanceEarnings({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
  });

  factory FinanceEarnings.fromJson(Map<String, dynamic> json) =>
      FinanceEarnings(
        today: EarningsPeriod.fromJson(json['today'] as Map<String, dynamic>?),
        thisWeek:
            EarningsPeriod.fromJson(json['this_week'] as Map<String, dynamic>?),
        thisMonth:
            EarningsPeriod.fromJson(json['this_month'] as Map<String, dynamic>?),
        thisYear:
            EarningsPeriod.fromJson(json['this_year'] as Map<String, dynamic>?),
      );
}

/// One row in the transactions ledger. The item shape is parsed leniently — the
/// staging ledger was empty at integration time, so unknown keys degrade to
/// sensible fallbacks rather than throwing.
class FinanceTransaction {
  final String id;
  final String type;
  final double amount;
  final String description;
  final String status;
  final String? createdAt;

  FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> j) =>
      FinanceTransaction(
        id: j['id']?.toString() ?? '',
        type: (j['type'] ?? j['txn_type'] ?? '').toString(),
        amount: _toDouble(j['amount']),
        description: (j['description'] ?? j['note'] ?? j['title'] ?? '')
            .toString(),
        status: (j['status'] ?? '').toString(),
        createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),
      );
}

/// `GET /restaurant/finance/transactions` — paginated envelope.
class TransactionsPage {
  final List<FinanceTransaction> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  TransactionsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory TransactionsPage.fromJson(Map<String, dynamic> json) =>
      TransactionsPage(
        items: (json['transactions'] as List? ?? [])
            .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: _toInt(json['total']),
        limit: _toInt(json['limit']),
        offset: _toInt(json['offset']),
        hasMore: json['has_more'] == true,
      );
}

/// The money side of a withdrawal: what the merchant asked for, the fee, and
/// what actually lands in the bank. Standard payout is free (like Grab's weekly
/// transfer), so [fee] defaults to 0. When the backend starts returning a fee
/// (e.g. an instant-payout charge), compute it in [WithdrawalQuote.of] instead
/// of hard-coding zero — the UI already renders whatever this reports.
class WithdrawalQuote {
  final double amount;
  final double fee;

  const WithdrawalQuote({required this.amount, required this.fee});

  double get net => (amount - fee).clamp(0, double.infinity);

  bool get isFree => fee <= 0;

  /// Standard (free) payout quote for [amount].
  factory WithdrawalQuote.of(double amount) =>
      WithdrawalQuote(amount: amount, fee: 0);
}

/// One entry in `GET /restaurant/withdrawals`. Parsed leniently (empty at
/// integration time).
class WithdrawalRequest {
  final String id;
  final double amount;
  final String status;
  final String? createdAt;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> j) =>
      WithdrawalRequest(
        id: j['id']?.toString() ?? '',
        amount: _toDouble(j['amount']),
        status: (j['status'] ?? '').toString(),
        createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),
      );
}
