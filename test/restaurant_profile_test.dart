import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

class _SpyApiClient extends ApiClient {
  final List<RequestOptions> requests = [];

  late final Dio _spy = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, data: {}, statusCode: 200),
          );
        },
      ),
    );

  @override
  Dio get dio => _spy;

  RequestOptions get last => requests.last;
}

/// Serves one profile and records what the notifier sends back.
class _FakeRestaurantRepository extends RestaurantRepository {
  _FakeRestaurantRepository() : super(ApiClient());

  Map<String, Object?>? lastUpdate;

  @override
  Future<RestaurantProfile> fetchProfile() async =>
      RestaurantProfile.fromJson(const {
        'restaurant_name': 'Thai Delight',
        'description': 'Authentic Thai',
        'cuisine_type': 'Thai',
        'address': '123 Main St',
        'min_order_amount': 100.0,
        'phone': '021234567',
        'is_open': true,
        'status': 'OPEN',
        'today_revenue': 4200.0,
      });

  @override
  Future<void> updateProfile({
    required String name,
    String? nameTh,
    String? description,
    String? cuisineType,
    String? address,
    double? lat,
    double? lng,
    double? minOrderAmount,
    String? openingTime,
    String? closingTime,
    String? timezone,
    String? logoFileKey,
    String? coverFileKey,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    String? taxId,
  }) async {
    lastUpdate = {
      'name': name,
      'description': description,
      'cuisineType': cuisineType,
      'address': address,
      'minOrderAmount': minOrderAmount,
      'logoFileKey': logoFileKey,
      'coverFileKey': coverFileKey,
      'phone': phone,
      'email': email,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'managerEmail': managerEmail,
      'taxId': taxId,
    };
  }
}

void main() {
  group('RestaurantProfile', () {
    test('reads the spec fields that used to be dropped', () {
      final profile = RestaurantProfile.fromJson(const {
        'restaurant_name': 'Thai Delight',
        'description': 'Authentic Thai cuisine',
        'cuisine_type': 'Thai',
        'min_order_amount': 150,
      });

      expect(profile.description, 'Authentic Thai cuisine');
      expect(profile.cuisineType, 'Thai');
      expect(profile.minOrderAmount, 150.0);
    });

    test('min_order_amount survives arriving as an int', () {
      expect(
        RestaurantProfile.fromJson(const {'min_order_amount': 150})
            .minOrderAmount,
        150.0,
      );
    });

    test('parses the SCRUM-80 contact fields incl. manager_name', () {
      final p = RestaurantProfile.fromJson(const {
        'phone': '0812345678',
        'email': 'shop@example.com',
        'manager_name': 'สมชาย ใจดี',
        'manager_phone': '0898765432',
        'manager_email': 'somchai@example.com',
        'tax_id': '1234567890123',
      });
      expect(p.phone, '0812345678');
      expect(p.email, 'shop@example.com');
      expect(p.managerName, 'สมชาย ใจดี');
      expect(p.managerPhone, '0898765432');
      expect(p.managerEmail, 'somchai@example.com');
      expect(p.taxId, '1234567890123');
    });
  });

  group('RestaurantRepository.updateProfile', () {
    test('PUTs the documented body and omits empty optionals', () async {
      final api = _SpyApiClient();

      await RestaurantRepository(api).updateProfile(name: 'Thai Delight');

      expect(api.last.method, 'PUT');
      expect(api.last.path, '/api/food/restaurant/profile');
      expect(api.last.data, {'restaurant_name': 'Thai Delight'});
    });

    test('sends every field it was given', () async {
      final api = _SpyApiClient();

      await RestaurantRepository(api).updateProfile(
        name: 'Thai Delight Updated',
        description: 'Updated description',
        cuisineType: 'Thai Fusion',
        address: '456 New St, Bangkok',
        minOrderAmount: 150.0,
      );

      expect(api.last.data, {
        'restaurant_name': 'Thai Delight Updated',
        'description': 'Updated description',
        'cuisine_type': 'Thai Fusion',
        'address': '456 New St, Bangkok',
        'min_order_amount': 150.0,
      });
    });

    test('sends the SCRUM-80 contact fields', () async {
      final api = _SpyApiClient();

      await RestaurantRepository(api).updateProfile(
        name: 'Shop',
        phone: '0812345678',
        email: 'shop@example.com',
        managerName: 'สมชาย ใจดี',
        managerPhone: '0898765432',
        managerEmail: 'somchai@example.com',
        taxId: '1234567890123',
      );

      expect(api.last.data, {
        'restaurant_name': 'Shop',
        'phone': '0812345678',
        'email': 'shop@example.com',
        'manager_name': 'สมชาย ใจดี',
        'manager_phone': '0898765432',
        'manager_email': 'somchai@example.com',
        'tax_id': '1234567890123',
      });
    });
  });

  group('RestaurantProfileNotifier.updateProfile', () {
    late _FakeRestaurantRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = _FakeRestaurantRepository();
      container = ProviderContainer(
        overrides: [restaurantRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(restaurantProfileProvider);
      await Future<void>.delayed(Duration.zero);
    });

    test('folds the edit into the profile the app already holds', () async {
      await container.read(restaurantProfileProvider.notifier).updateProfile(
            name: 'Renamed',
            address: '456 New St',
            minOrderAmount: 250,
          );

      final profile = container.read(restaurantProfileProvider).value!;
      expect(profile.name, 'Renamed');
      expect(profile.address, '456 New St');
      expect(profile.minOrderAmount, 250);
      // Fields the endpoint never echoes back must survive the edit.
      expect(profile.phone, '021234567');
      expect(profile.todayRevenue, 4200.0);
      expect(profile.status, RestaurantStatus.open);
    });

    test('passes the edit straight through to the repository', () async {
      await container.read(restaurantProfileProvider.notifier).updateProfile(
            name: 'Renamed',
            cuisineType: 'Thai Fusion',
          );

      expect(repo.lastUpdate!['name'], 'Renamed');
      expect(repo.lastUpdate!['cuisineType'], 'Thai Fusion');
    });
  });
}
