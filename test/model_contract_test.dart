import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';

/// Parses the sample payloads from SCRUM-53 verbatim, so a field the spec
/// documents cannot quietly stop being read.
void main() {
  group('Order (§4)', () {
    final order = Order.fromJson(const {
      'id': '3f2a7c11-88de-4d0b-9a41-2b6e5f0c1a77',
      'customer_id': 'c0ffee00-1111-2222-3333-444455556666',
      'customer_name': 'Nid Wattana',
      'customer_phone': '+66898887777',
      'driver_id': '7b1d9e22-aaaa-bbbb-cccc-dddddddddddd',
      'status': 'PREPARING',
      'delivery_address': '55/3 Soi Ruamrudee, Lumphini, Bangkok',
      'delivery_notes': 'Call on arrival, gate code 1234',
      'food_total': 250.0,
      'delivery_fee': 45.0,
      'total_amount': 295.0,
      'payment_method': 'CASH',
      'payment_status': 'PAID',
      'placed_at': '2026-08-07T11:02:19Z',
      'delivered_at': '2026-08-07T11:41:52Z',
      'tier': 'STANDARD',
      'prep_time_adjustment_min': 10,
      'oos_items': ['22222222-2222-2222-2222-222222222222'],
      'promo_discount': 0.0,
      'platform_commission': 37.5,
      'items': [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'menu_item_id': 'aaaaaaa1-0000-0000-0000-000000000001',
          'name': 'Som Tam Thai',
          'quantity': 2,
          'unit_price': 60.0,
          'variant_options': '{"spice":"medium"}',
          'selected_modifiers': [
            {
              'id': 'm0000001-0000-0000-0000-000000000001',
              'name': 'Extra Peanuts',
              'price': 10.0,
            }
          ],
          'subtotal': 140.0,
          'notes': 'no fish sauce',
        },
      ],
      'driver_info': {
        'full_name': 'Anan Chaiwong',
        'phone': '+66877776666',
        'rating': 4.8,
        'vehicle_plate': 'กง 1234',
        'vehicle_model': 'Honda Wave 125',
      },
    });

    test('reads the customer contact details', () {
      expect(order.customerName, 'Nid Wattana');
      expect(order.customerPhone, '+66898887777');
      expect(order.deliveryNotes, 'Call on arrival, gate code 1234');
    });

    test('reads payment status and tier', () {
      expect(order.paymentStatus, 'PAID');
      expect(order.tier, 'STANDARD');
      expect(order.isPrepaid, isFalse, reason: 'CASH is collected on delivery');
    });

    test('reads the driver block once one is assigned', () {
      expect(order.driverId, isNotNull);
      expect(order.driverInfo?.fullName, 'Anan Chaiwong');
      expect(order.driverInfo?.vehiclePlate, 'กง 1234');
    });

    test('variant_options stays an unparsed JSON string', () {
      // The column is JSONB but every read casts it to text (SCRUM-53 §4).
      expect(order.items.single.variantOptions, '{"spice":"medium"}');
      expect(order.items.single.variantOptions, isA<String>());
    });

    test('subtotal maths matches the documented formula', () {
      expect(order.items.single.computedSubtotal, 140.0);
      expect(order.platformCommission, 37.5);
    });

    test('driver_info is absent before assignment', () {
      expect(Order.fromJson(const {'id': 'x'}).driverInfo, isNull);
      expect(Order.fromJson(const {'id': 'x'}).paymentStatus, isNull);
    });

    test('a PROMPTPAY order reads as prepaid', () {
      expect(
        Order.fromJson(const {'id': 'x', 'payment_method': 'PROMPTPAY'})
            .isPrepaid,
        isTrue,
      );
    });
  });

  group('Menu (§5)', () {
    final category = MenuCategory.fromJson(const {
      'id': 'cat00001-0000-0000-0000-000000000001',
      'name': 'Salads',
      'name_th': 'ยำ/ส้มตำ',
      'sort_order': 1,
      'is_active': true,
      'style': 'GRID',
      'items': [
        {
          'id': 'aaaaaaa1-0000-0000-0000-000000000001',
          'category_id': 'cat00001-0000-0000-0000-000000000001',
          'name': 'Som Tam Thai',
          'name_th': 'ส้มตำไทย',
          'description': 'Green papaya salad',
          'description_th': 'ส้มตำมะละกอ',
          'price': 60.0,
          'original_price': 75.0,
          'is_available': true,
          'options': '{"spice":["mild","medium","hot"]}',
          'modifier_groups': [
            {
              'id': 'grp00001-0000-0000-0000-000000000001',
              'name': 'Add-ons',
              'name_th': 'เพิ่มเติม',
              'min_select': 0,
              'max_select': 3,
              'is_active': true,
              'modifiers': [
                {
                  'id': 'm0000001-0000-0000-0000-000000000001',
                  'name': 'Extra Peanuts',
                  'name_th': 'เพิ่มถั่ว',
                  'price': 10.0,
                  'is_available': true,
                }
              ],
            }
          ],
        }
      ],
    });

    test('keeps the Thai variants alongside the resolved name', () {
      expect(category.nameTh, 'ยำ/ส้มตำ');
      expect(category.items.single.nameTh, 'ส้มตำไทย');
      expect(category.items.single.descriptionTh, 'ส้มตำมะละกอ');
    });

    test('style defaults to uppercase GRID', () {
      expect(category.style, 'GRID');
      expect(MenuCategory.fromJson(const {'id': 'c'}).style, 'GRID');
    });

    test('options stays a string — it is JSONB cast to text', () {
      expect(
        category.items.single.options,
        '{"spice":["mild","medium","hot"]}',
      );
    });

    test('modifier groups are read nested, the only source available', () {
      // §6 defines no list endpoint for them.
      final group = category.items.single.modifierGroups.single;
      expect(group.name, 'Add-ons');
      expect(group.maxSelect, 3);
      expect(group.modifiers.single.nameTh, 'เพิ่มถั่ว');
    });

    test('original_price is read for strike-through pricing', () {
      expect(category.items.single.originalPrice, 75.0);
    });
  });

  group('Profile (§3)', () {
    final profile = RestaurantProfile.fromJson(const {
      'user_id': '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10',
      'restaurant_name': 'Somchai Kitchen',
      'restaurant_name_th': 'ครัวสมชาย',
      'description_th': 'อาหารอีสานแท้',
      'cuisine_type': 'Thai',
      'cuisine_type_th': 'ไทย',
      'address': '123 Sukhumvit Rd, Bangkok 10110',
      'lat': 13.7245,
      'lng': 100.5692,
      'rating': 4.6,
      'is_active': true,
      'is_open': true,
      'min_order_amount': 100,
      'bank_code': '014',
      'bank_account_number': '1234567890',
      'verification_status': 'VERIFIED',
      'verified_at': '2026-06-14T09:12:33Z',
      'opening_time': '09:00',
      'closing_time': '21:30',
      'timezone': 'Asia/Bangkok',
    });

    test('reads the fields the merchant screen shows', () {
      expect(profile.userId, '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10');
      expect(profile.nameTh, 'ครัวสมชาย');
      expect(profile.rating, 4.6);
      expect(profile.openingTime, '09:00');
      expect(profile.timezone, 'Asia/Bangkok');
    });

    test('bank details come through only on the merchant read', () {
      expect(profile.bankCode, '014');
      expect(profile.bankAccountNumber, '1234567890');
    });

    test('verification status is uppercase', () {
      expect(profile.verificationStatus, 'VERIFIED');
      expect(profile.isVerified, isTrue);
    });

    test('a real address and coordinates are not a placeholder', () {
      expect(profile.isPlaceholder, isFalse);
      expect(profile.hasLocation, isTrue);
    });

    test('the row registration creates is detected as not onboarded', () {
      final placeholder = RestaurantProfile.fromJson(const {
        'restaurant_name': 'New Restaurant',
        'address': 'Pending Address',
        'lat': 0,
        'lng': 0,
      });

      expect(placeholder.isPlaceholder, isTrue);
      // 0,0 is the dangerous part: invisible to customer search.
      expect(placeholder.hasLocation, isFalse);
    });

    test('a filled-in name with no coordinates is still not onboarded', () {
      final noCoords = RestaurantProfile.fromJson(const {
        'restaurant_name': 'Somchai Kitchen',
        'address': '123 Sukhumvit Rd',
      });

      expect(noCoords.isPlaceholder, isTrue);
    });
  });
}
