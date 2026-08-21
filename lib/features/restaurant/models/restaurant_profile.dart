enum RestaurantStatus { open, busy, paused }

/// Profile-level KYC outcome (SCRUM-53 §3).
///
/// Casing trap: these are **uppercase**, while an individual document's own
/// `status` is lowercase. Two enums, two casings — see [DocumentStatus].
class VerificationStatus {
  const VerificationStatus._();

  static const String pending = 'PENDING';
  static const String verified = 'VERIFIED';
  static const String rejected = 'REJECTED';
}

class RestaurantProfile {
  final String name;
  final String branch;
  final String platform;
  final bool isOpen;
  final bool isBusy;
  final RestaurantStatus status;
  final String? description;
  final String? cuisineType;
  final double? lat;
  final double? lng;
  /// PENDING | VERIFIED | REJECTED — **uppercase**, unlike the per-document
  /// status which is lowercase (SCRUM-53 §3, §8).
  final String? verificationStatus;
  final String? verifiedAt;
  final String? userId;
  final String? nameTh;
  final String? descriptionTh;
  final String? cuisineTypeTh;
  final double? rating;
  final bool isActive;
  final String? openingTime;
  final String? closingTime;
  final String? timezone;

  /// Only ever returned on the merchant's own profile — stripped from every
  /// customer-facing read.
  final String? bankCode;
  final String? bankAccountNumber;
  final double? minOrderAmount;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
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
    this.lat,
    this.lng,
    this.verificationStatus,
    this.verifiedAt,
    this.userId,
    this.nameTh,
    this.descriptionTh,
    this.cuisineTypeTh,
    this.rating,
    this.isActive = true,
    this.openingTime,
    this.closingTime,
    this.timezone,
    this.bankCode,
    this.bankAccountNumber,
    this.minOrderAmount,
    this.logoUrl,
    this.coverImageUrl,
    this.address,
    this.phone,
    this.email,
    this.managerName,
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
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      verificationStatus: json['verification_status'],
      verifiedAt: json['verified_at'],
      userId: json['user_id'],
      nameTh: json['restaurant_name_th'],
      descriptionTh: json['description_th'],
      cuisineTypeTh: json['cuisine_type_th'],
      rating: (json['rating'] as num?)?.toDouble(),
      isActive: json['is_active'] ?? true,
      openingTime: json['opening_time'],
      closingTime: json['closing_time'],
      timezone: json['timezone'],
      bankCode: json['bank_code'],
      bankAccountNumber: json['bank_account_number'],
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      logoUrl: json['logo_url'],
      coverImageUrl: json['cover_image_url'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      managerName: json['manager_name'],
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

  /// Registration inserts a placeholder row in the same transaction, so
  /// `GET /profile` never 404s — "not onboarded" has to be read off the
  /// contents instead (SCRUM-53 §2).
  ///
  /// Coordinates matter most: at 0,0 the restaurant is filtered out of customer
  /// search entirely and receives no orders at all, silently.
  bool get isPlaceholder =>
      name == 'New Restaurant' || address == 'Pending Address' || !hasLocation;

  bool get hasLocation => lat != null && lng != null && !(lat == 0 && lng == 0);

  bool get isVerified => verificationStatus == VerificationStatus.verified;

  RestaurantProfile copyWith({
    String? name,
    String? description,
    String? cuisineType,
    double? minOrderAmount,
    String? address,
    double? lat,
    double? lng,
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
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      verificationStatus: verificationStatus,
      verifiedAt: verifiedAt,
      userId: userId,
      nameTh: nameTh,
      descriptionTh: descriptionTh,
      cuisineTypeTh: cuisineTypeTh,
      rating: rating,
      isActive: isActive,
      openingTime: openingTime,
      closingTime: closingTime,
      timezone: timezone,
      bankCode: bankCode,
      bankAccountNumber: bankAccountNumber,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      logoUrl: logoUrl,
      coverImageUrl: coverImageUrl,
      address: address ?? this.address,
      phone: phone,
      email: email,
      managerName: managerName,
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
