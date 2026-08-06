import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';

enum RestaurantStatus { open, busy, paused }

class RestaurantProfile {
  final String name;
  final String branch;
  final String platform;
  final bool isOpen;
  final bool isBusy;
  final RestaurantStatus status;
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
    bool? isOpen,
    bool? isBusy,
    RestaurantStatus? status,
    String? pausedUntil,
    int? todayOrders,
    double? todayRevenue,
    int? preparingCount,
  }) {
    return RestaurantProfile(
      name: name,
      branch: branch,
      platform: platform,
      isOpen: isOpen ?? this.isOpen,
      isBusy: isBusy ?? this.isBusy,
      status: status ?? this.status,
      logoUrl: logoUrl,
      coverImageUrl: coverImageUrl,
      address: address,
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

class RestaurantProfileNotifier
    extends StateNotifier<AsyncValue<RestaurantProfile>> {
  RestaurantProfileNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  final ApiClient _api;

  Future<void> fetchProfile() async {
    try {
      final response = await _api.dio.get('/restaurant/profile');
      state = AsyncValue.data(
          RestaurantProfile.fromJson(response.data as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setStatus(RestaurantStatus newStatus) async {
    try {
      final isOpen = newStatus == RestaurantStatus.open;
      final isBusy = newStatus == RestaurantStatus.busy;

      if (newStatus == RestaurantStatus.open || newStatus == RestaurantStatus.paused) {
        await _api.dio.post('/restaurant/open', data: {'is_open': isOpen});
      }
      if (newStatus == RestaurantStatus.busy) {
        await _api.dio
            .post('/restaurant/busy', data: {'is_busy': isBusy});
      }

      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(
            isOpen: isOpen,
            isBusy: isBusy,
            status: newStatus,
          ),
        );
      }
    } catch (e) {
      // Handle gracefully
    }
  }

  Future<void> toggleOpenStatus(bool isOpen) async {
    await setStatus(
        isOpen ? RestaurantStatus.open : RestaurantStatus.paused);
  }

  Future<void> toggleBusyMode(bool isBusy, {int? durationMin}) async {
    await setStatus(
        isBusy ? RestaurantStatus.busy : RestaurantStatus.open);
  }

  void incrementPreparingCount() {
    if (state.hasValue) {
      state = AsyncValue.data(
          state.value!.copyWith(preparingCount: state.value!.preparingCount + 1));
    }
  }
}

final restaurantProfileProvider = StateNotifierProvider<
    RestaurantProfileNotifier, AsyncValue<RestaurantProfile>>(
  (ref) => RestaurantProfileNotifier(ref.watch(apiClientProvider)),
);
