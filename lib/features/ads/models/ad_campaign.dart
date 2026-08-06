class AdCampaign {
  final String id;
  final double dailyBudget;
  final double currentSpend;
  final double bidPerClick;
  final bool isActive;

  AdCampaign({
    required this.id,
    required this.dailyBudget,
    required this.currentSpend,
    required this.bidPerClick,
    required this.isActive,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: json['id'] ?? '',
      dailyBudget: json['daily_budget']?.toDouble() ?? 0.0,
      currentSpend: json['current_spend']?.toDouble() ?? 0.0,
      bidPerClick: json['bid_per_click']?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? false,
    );
  }
}
