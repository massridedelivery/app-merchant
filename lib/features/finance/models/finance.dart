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

  /// Withdrawal fee model (SCRUM-78). Read every time — finance can change these
  /// without a deploy. The current policy is free (all zero), so never hardcode.
  final double withdrawalFeeFlat;
  final double withdrawalFeeRate; // fraction, 0.01 = 1%
  final double withholdingTaxRate; // fraction

  FinanceSummary({
    required this.balance,
    required this.availableBalance,
    required this.pendingWithdrawal,
    required this.lifetimeEarnings,
    required this.totalWithdrawn,
    required this.canWithdraw,
    this.withdrawalFeeFlat = 0,
    this.withdrawalFeeRate = 0,
    this.withholdingTaxRate = 0,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        balance: _toDouble(json['balance']),
        availableBalance: _toDouble(json['available_balance']),
        pendingWithdrawal: _toDouble(json['pending_withdrawal']),
        lifetimeEarnings: _toDouble(json['lifetime_earnings']),
        totalWithdrawn: _toDouble(json['total_withdrawn']),
        canWithdraw: json['can_withdraw'] == true,
        withdrawalFeeFlat: _toDouble(json['withdrawal_fee_flat']),
        withdrawalFeeRate: _toDouble(json['withdrawal_fee_rate']),
        withholdingTaxRate: _toDouble(json['withholding_tax_rate']),
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
/// what actually lands in the bank. The fee comes from the finance summary's
/// rate model (SCRUM-78) so it stays in sync with backend policy — the current
/// policy is free (all rates 0), but never hardcode that.
class WithdrawalQuote {
  final double amount;
  final double fee;

  const WithdrawalQuote({required this.amount, required this.fee});

  double get net => (amount - fee).clamp(0, double.infinity);

  bool get isFree => fee <= 0;

  /// Quote for [amount] using the summary's fee rates:
  /// `fee = flat + amount × (feeRate + whtRate)`.
  factory WithdrawalQuote.from(double amount, FinanceSummary s) {
    final fee = s.withdrawalFeeFlat +
        amount * (s.withdrawalFeeRate + s.withholdingTaxRate);
    return WithdrawalQuote(amount: amount, fee: fee < 0 ? 0 : fee);
  }
}

/// One entry in `GET /restaurant/withdrawals`. Carries the fee/net breakdown
/// (SCRUM-78). Parsed leniently.
class WithdrawalRequest {
  final String id;
  final double amount;
  final double fee;
  final double netAmount;
  final String status;
  final String? createdAt;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.status,
    required this.createdAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> j) {
    final amount = _toDouble(j['amount']);
    final fee = _toDouble(j['fee']);
    // net_amount may be absent on older rows — fall back to amount - fee.
    final net = j['net_amount'] != null ? _toDouble(j['net_amount']) : amount - fee;
    return WithdrawalRequest(
      id: j['id']?.toString() ?? '',
      amount: amount,
      fee: fee,
      netAmount: net,
      status: (j['status'] ?? '').toString(),
      createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),
    );
  }
}

/// `GET`/`PUT /restaurant/finance/auto-payout` (SCRUM-77). Weekly automatic
/// withdrawal. [dayOfWeek] is 0=Sunday … 6=Saturday (same as the store-hours
/// weekday). A shop that never set it gets these defaults (not a 404).
class AutoPayoutSettings {
  final bool enabled;
  final int dayOfWeek;
  final double minAmount;

  const AutoPayoutSettings({
    this.enabled = false,
    this.dayOfWeek = 1,
    this.minAmount = 100,
  });

  factory AutoPayoutSettings.fromJson(Map<String, dynamic> json) =>
      AutoPayoutSettings(
        enabled: json['enabled'] == true,
        dayOfWeek: _toInt(json['day_of_week']),
        minAmount: json['min_amount'] != null ? _toDouble(json['min_amount']) : 100,
      );

  AutoPayoutSettings copyWith({bool? enabled, int? dayOfWeek, double? minAmount}) =>
      AutoPayoutSettings(
        enabled: enabled ?? this.enabled,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        minAmount: minAmount ?? this.minAmount,
      );
}
