enum RestaurantStatus { open, busy, paused }

class RestaurantProfile {
  final String name;
  final String branch;
  final String platform;
  final bool isOpen;
  final bool isBusy;
  final RestaurantStatus status;
  final String? description;
  final String? cuisineType;
  final double? minOrderAmount;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerPhone;
  final String? managerEmail;
  final String? restaurantCode;
  final String? taxId;
  final String? pausedUntil;
  final int todayOrders;
  final double todayRevenue;
  final int preparingCount;

  RestaurantProfile({
    required this.name,
    required this.branch,
    required this.platform,
    required this.isOpen,
    required this.isBusy,
    required this.status,
    this.description,
    this.cuisineType,
    this.minOrderAmount,
    this.logoUrl,
    this.coverImageUrl,
    this.address,
    this.phone,
    this.email,
    this.managerPhone,
    this.managerEmail,
    this.restaurantCode,
    this.taxId,
    this.pausedUntil,
    this.todayOrders = 0,
    this.todayRevenue = 0.0,
    this.preparingCount = 0,
  });

  factory RestaurantProfile.fromJson(Map<String, dynamic> json) {
    RestaurantStatus status;
    final statusStr = json['status'] as String? ?? 'OPEN';
    if (statusStr == 'PAUSED') {
      status = RestaurantStatus.paused;
    } else if (statusStr == 'BUSY' || json['is_busy'] == true) {
      status = RestaurantStatus.busy;
    } else {
      status = RestaurantStatus.open;
    }

    return RestaurantProfile(
      name: json['restaurant_name'] ?? 'ร้านของคุณ',
      branch: json['branch'] ?? '',
      platform: json['platform'] ?? 'GrabFood',
      isOpen: json['is_open'] ?? false,
      isBusy: json['is_busy'] ?? false,
      status: status,
      description: json['description'],
      cuisineType: json['cuisine_type'],
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      logoUrl: json['logo_url'],
      coverImageUrl: json['cover_image_url'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      managerPhone: json['manager_phone'],
      managerEmail: json['manager_email'],
      restaurantCode: json['restaurant_code'],
      taxId: json['tax_id'],
      pausedUntil: json['paused_until'],
      todayOrders: json['today_orders'] ?? 0,
      todayRevenue: (json['today_revenue'] ?? 0.0).toDouble(),
      preparingCount: json['preparing_count'] ?? 0,
    );
  }

  RestaurantProfile copyWith({
    String? name,
    String? description,
    String? cuisineType,
    double? minOrderAmount,
    String? address,
    bool? isOpen,
    bool? isBusy,
    RestaurantStatus? status,
    String? pausedUntil,
    int? todayOrders,
    double? todayRevenue,
    int? preparingCount,
  }) {
    return RestaurantProfile(
      name: name ?? this.name,
      branch: branch,
      platform: platform,
      isOpen: isOpen ?? this.isOpen,
      isBusy: isBusy ?? this.isBusy,
      status: status ?? this.status,
      description: description ?? this.description,
      cuisineType: cuisineType ?? this.cuisineType,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      logoUrl: logoUrl,
      coverImageUrl: coverImageUrl,
      address: address ?? this.address,
      phone: phone,
      email: email,
      managerPhone: managerPhone,
      managerEmail: managerEmail,
      restaurantCode: restaurantCode,
      taxId: taxId,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      todayOrders: todayOrders ?? this.todayOrders,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      preparingCount: preparingCount ?? this.preparingCount,
    );
  }
}
