import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/store_onboarding_screen.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

class _FakeRestaurantRepository extends RestaurantRepository {
  _FakeRestaurantRepository(this._profile) : super(ApiClient());

  final Map<String, dynamic> _profile;
  Map<String, Object?>? lastUpdate;

  @override
  Future<RestaurantProfile> fetchProfile() async =>
      RestaurantProfile.fromJson(_profile);

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
  }) async {
    lastUpdate = {'name': name, 'address': address, 'lat': lat, 'lng': lng};
  }
}

/// The row registration leaves behind (SCRUM-53 §2).
const placeholderProfile = {
  'restaurant_name': 'New Restaurant',
  'address': 'Pending Address',
  'lat': 0,
  'lng': 0,
};

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _FakeRestaurantRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [restaurantRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(restaurantProfileProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final profile = ref.watch(restaurantProfileProvider).valueOrNull;
              if (profile == null) return const SizedBox();
              return profile.isPlaceholder
                  ? StoreOnboardingScreen(profile: profile)
                  : const Scaffold(body: Text('the app'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a placeholder profile is held at onboarding', (tester) async {
    await pump(tester, _FakeRestaurantRepository(placeholderProfile));

    expect(find.text('ตั้งค่าร้านให้เสร็จก่อนเริ่มขาย'), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a real profile goes straight through', (tester) async {
    await pump(
      tester,
      _FakeRestaurantRepository(const {
        'restaurant_name': 'Somchai Kitchen',
        'address': '123 Sukhumvit Rd',
        'lat': 13.7245,
        'lng': 100.5692,
      }),
    );

    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a named restaurant with no coordinates is still held',
      (tester) async {
    // The dangerous case: looks configured, but distance filtering hides it.
    await pump(
      tester,
      _FakeRestaurantRepository(const {
        'restaurant_name': 'Somchai Kitchen',
        'address': '123 Sukhumvit Rd',
      }),
    );

    expect(find.text('ตั้งค่าร้านให้เสร็จก่อนเริ่มขาย'), findsOneWidget);
  });

  testWidgets('the placeholder text is cleared rather than presented as real',
      (tester) async {
    await pump(tester, _FakeRestaurantRepository(placeholderProfile));

    expect(find.text('New Restaurant'), findsNothing);
    expect(find.text('Pending Address'), findsNothing);
  });

  testWidgets('zero coordinates are refused with a reason', (tester) async {
    final repo = _FakeRestaurantRepository(placeholderProfile);
    await pump(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อร้าน'), 'Somchai Kitchen');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ที่อยู่ร้าน'), '123 Sukhumvit');
    await tester.enterText(find.widgetWithText(TextFormField, 'ละติจูด'), '0');
    await tester.enterText(find.widgetWithText(TextFormField, 'ลองจิจูด'), '0');
    // The form is taller than the test viewport; the button must be on
    // screen for the tap to land.
    await tester.ensureVisible(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();

    expect(find.text('พิกัด 0 ทำให้ลูกค้าหาร้านไม่เจอ'), findsWidgets);
    expect(repo.lastUpdate, isNull);
  });

  testWidgets('an out-of-range latitude is refused', (tester) async {
    final repo = _FakeRestaurantRepository(placeholderProfile);
    await pump(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อร้าน'), 'Somchai Kitchen');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ที่อยู่ร้าน'), '123 Sukhumvit');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ละติจูด'), '999');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ลองจิจูด'), '100.5');
    // The form is taller than the test viewport; the button must be on
    // screen for the tap to land.
    await tester.ensureVisible(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();

    expect(find.text('พิกัดอยู่นอกช่วงที่เป็นไปได้'), findsOneWidget);
    expect(repo.lastUpdate, isNull);
  });

  testWidgets('a real location saves and releases the gate', (tester) async {
    final repo = _FakeRestaurantRepository(placeholderProfile);
    final container = await pump(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อร้าน'), 'Somchai Kitchen');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ที่อยู่ร้าน'), '123 Sukhumvit Rd');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ละติจูด'), '13.7245');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ลองจิจูด'), '100.5692');
    // The form is taller than the test viewport; the button must be on
    // screen for the tap to land.
    await tester.ensureVisible(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกและเริ่มใช้งาน'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdate, {
      'name': 'Somchai Kitchen',
      'address': '123 Sukhumvit Rd',
      'lat': 13.7245,
      'lng': 100.5692,
    });

    final profile = container.read(restaurantProfileProvider).value!;
    expect(profile.isPlaceholder, isFalse);
    expect(find.text('the app'), findsOneWidget);
  });
}
