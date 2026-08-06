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
