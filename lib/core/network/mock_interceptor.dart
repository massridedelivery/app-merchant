import 'package:dio/dio.dart';

class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final method = options.method;

    // ─── AUTH ───────────────────────────────────────────────
    if (path.contains('/auth/login')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {'token': 'mock_jwt_token_12345'},
        statusCode: 200,
      ));
    }

    // ─── RESTAURANT PROFILE ─────────────────────────────────
    if (path.contains('/restaurant/profile')) {
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'Profile updated successfully'},
          statusCode: 200,
        ));
      }
      return handler.resolve(Response(
        requestOptions: options,
        data: {
          'user_id': 'rest-123',
          'restaurant_name': 'น้ำเงี้ยว ข้าวซอย By Momay',
          'description': 'ร้านอาหารเหนือแท้ รสชาติต้นตำรับ',
          'cuisine_type': 'Northern Thai',
          'address': 'โครงการเวิร์ฟ พระราม 5',
          'branch': '- พระราม 5',
          'platform': 'GrabFood',
          'lat': 13.7563,
          'lng': 100.5018,
          'logo_url': 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=200&q=80',
          'cover_image_url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80',
          'rating': 4.5,
          'is_active': true,
          'is_open': false,
          'is_busy': false,
          'status': 'PAUSED',
          'min_order_amount': 100.0,
          'is_sponsored': false,
          'bank_code': 'SCB',
          'bank_account_number': '***-*-*****-*',
          'restaurant_code': '3-C633AYDWR3T1V2',
          'tax_id': '1510100184948',
          'phone': '+66 649426362',
          'email': 'may_7781@hotmail.com',
          'manager_phone': '+66 649426362',
          'manager_email': 'may_7781@hotmail.com',
          'paused_until': '23:59, 31 ธ.ค.',
          'created_at': '2024-01-01T00:00:00Z',
          'today_orders': 0,
          'today_revenue': 0.0,
          'preparing_count': 0,
        },
        statusCode: 200,
      ));
    }

    // ─── TOGGLE OPEN ────────────────────────────────────────
    if (path.contains('/restaurant/open')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {'is_open': true},
        statusCode: 200,
      ));
    }

    // ─── BUSY MODE ──────────────────────────────────────────
    if (path.contains('/restaurant/busy')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {'message': 'Busy mode updated'},
        statusCode: 200,
      ));
    }

    // ─── STORE HOURS ────────────────────────────────────────
    if (path.contains('/restaurant/hours')) {
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'Hours updated successfully'},
          statusCode: 200,
        ));
      }
      return handler.resolve(Response(
        requestOptions: options,
        data: {
          'special_closures': [
            {
              'id': 'CAS-100020539816',
              'reason': 'ปิดร้านยกเลิกสัญญา',
              'status': 'PAUSED',
              'start_date': '2025-04-26',
              'end_date': '2099-04-26',
              'is_all_day': true,
            }
          ],
          'delivery_hours': [
            {'day': 'MON', 'day_th': 'จันทร์', 'is_open': true, 'is_24hr': false, 'slots': [{'open': '10:00', 'close': '18:00'}]},
            {'day': 'TUE', 'day_th': 'อังคาร', 'is_open': true, 'is_24hr': false, 'slots': [{'open': '10:00', 'close': '18:00'}]},
            {'day': 'WED', 'day_th': 'พุธ', 'is_open': true, 'is_24hr': false, 'slots': [{'open': '10:00', 'close': '18:00'}]},
            {'day': 'THU', 'day_th': 'พฤหัส', 'is_open': true, 'is_24hr': false, 'slots': [{'open': '10:00', 'close': '18:00'}]},
            {'day': 'FRI', 'day_th': 'ศุกร์', 'is_open': false, 'is_24hr': false, 'slots': []},
            {'day': 'SAT', 'day_th': 'เสาร์', 'is_open': false, 'is_24hr': false, 'slots': []},
            {'day': 'SUN', 'day_th': 'อาทิตย์', 'is_open': false, 'is_24hr': false, 'slots': []},
          ]
        },
        statusCode: 200,
      ));
    }

    // ─── MENU: CUSTOMER (for fetching display menu) ─────────
    if (path.contains('/customer/restaurants/') && path.endsWith('/menu')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: _mockMenuData(),
        statusCode: 200,
      ));
    }

    // ─── MENU: MERCHANT CATEGORIES ──────────────────────────
    if (path.contains('/restaurant/menu/categories')) {
      if (method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        return handler.resolve(Response(
          requestOptions: options,
          data: {
            'id': 'cat_new_${DateTime.now().millisecondsSinceEpoch}',
            'name': data['name'],
            'sort_order': data['sort_order'] ?? 99,
            'is_active': true,
            'items': [],
          },
          statusCode: 201,
        ));
      }
      if (method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          data: _mockMenuData()['categories'],
          statusCode: 200,
        ));
      }
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'updated successfully'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return handler.resolve(Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── MENU ITEMS ─────────────────────────────────────────
    if (path.contains('/restaurant/menu/items')) {
      if (method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        return handler.resolve(Response(
          requestOptions: options,
          data: {
            'id': 'item_new_${DateTime.now().millisecondsSinceEpoch}',
            'category_id': data['category_id'],
            'name': data['name'],
            'description': data['description'] ?? '',
            'price': data['price'],
            'is_available': true,
            'modifiers': [],
          },
          statusCode: 201,
        ));
      }
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'item updated successfully'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return handler.resolve(Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── MODIFIERS (inside a group, and standalone) ──────────
    if (path.contains('/modifiers')) {
      if (method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        return handler.resolve(Response(
          requestOptions: options,
          data: {
            'id': 'mod_new_${DateTime.now().millisecondsSinceEpoch}',
            'name': data['name'],
            'price': data['price'] ?? 0.0,
            'is_available': true,
            'sort_order': 1,
          },
          statusCode: 201,
        ));
      }
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'modifier updated'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return handler.resolve(Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── ITEM ↔ MODIFIER GROUP LINKS ─────────────────────────
    if (path.contains('/restaurant/items/') &&
        path.contains('/modifier-groups')) {
      if (method == 'POST') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'modifier group linked to item'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return handler.resolve(Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── MODIFIER GROUPS ─────────────────────────────────────
    if (path.contains('/modifier-groups') && !path.contains('/modifiers')) {
      if (method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          data: _mockModifierGroups(),
          statusCode: 200,
        ));
      }
      if (method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        return handler.resolve(Response(
          requestOptions: options,
          data: {
            'id': 'group_new_${DateTime.now().millisecondsSinceEpoch}',
            'name': data['name'],
            'min_select': data['min_select'] ?? 0,
            'max_select': data['max_select'] ?? 1,
            'is_active': true,
            'modifiers': [],
          },
          statusCode: 201,
        ));
      }
      if (method == 'PUT') {
        return handler.resolve(Response(
          requestOptions: options,
          data: {'message': 'modifier group updated'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return handler.resolve(Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── ORDERS: PENDING ────────────────────────────────────
    if (path.contains('/restaurant/orders/pending')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: _mockPendingOrders(),
        statusCode: 200,
      ));
    }

    // ─── ORDERS: HISTORY ────────────────────────────────────
    if (path.contains('/restaurant/orders/history')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: _mockOrderHistory(),
        statusCode: 200,
      ));
    }

    // ─── ORDER ACTIONS ──────────────────────────────────────
    if (path.contains('/restaurant/orders/') && path.contains('/ops')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {'message': 'order updated successfully'},
        statusCode: 200,
      ));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/accept')) {
      return handler.resolve(Response(requestOptions: options, data: {'message': 'RESTAURANT_ACCEPTED'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/reject')) {
      return handler.resolve(Response(requestOptions: options, data: {'message': 'RESTAURANT_REJECTED'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/preparing')) {
      return handler.resolve(Response(requestOptions: options, data: {'message': 'PREPARING'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/ready')) {
      return handler.resolve(Response(requestOptions: options, data: {'message': 'READY_FOR_PICKUP'}, statusCode: 200));
    }

    // ─── FINANCE ────────────────────────────────────────────
    if (path.contains('/restaurant/finance/summary')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {
          'total_revenue': 0.0,
          'total_orders': 0,
          'avg_order_value': 0.0,
          'pending_payout': 0.0,
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/restaurant/finance/transactions')) {
      return handler.resolve(Response(requestOptions: options, data: [], statusCode: 200));
    }
    if (path.contains('/restaurant/finance/earnings')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {'balance': 0.0, 'pending': 0.0, 'transactions': []},
        statusCode: 200,
      ));
    }

    // ─── WITHDRAW ────────────────────────────────────────────
    if (path.contains('/restaurant/withdraw') && method == 'POST') {
      return handler.resolve(Response(requestOptions: options, data: {'message': 'Withdrawal requested successfully'}, statusCode: 200));
    }

    // ─── ADS ────────────────────────────────────────────────
    if (path.contains('/restaurant/ads')) {
      return handler.resolve(Response(
        requestOptions: options,
        data: {
          'id': 'ad_current',
          'daily_budget': 500.0,
          'current_spend': 120.50,
          'bid_per_click': 2.5,
          'is_active': true,
        },
        statusCode: 200,
      ));
    }

    super.onRequest(options, handler);
  }

  // ─── MOCK DATA HELPERS ──────────────────────────────────────────────────────

  Map<String, dynamic> _mockMenuData() {
    return {
      'categories': [
        {
          'id': 'cat_1',
          'name': 'เมนูยอดนิยม',
          'sort_order': 1,
          'is_active': true,
          'items': [
            {
              'id': 'item_1',
              'category_id': 'cat_1',
              'name': 'แกงมัสมั่นไก่',
              'description': 'แกงมัสมั่นตำรับไทยแท้ รสชาติเข้มข้น',
              'price': 150.0,
              'is_available': true,
              'image_url': 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=200&q=80',
            },
            {
              'id': 'item_2',
              'category_id': 'cat_1',
              'name': 'ผัดไทยกุ้งแม่น้ำ',
              'description': 'ผัดไทยเส้นเหนียวนุ่ม พร้อมกุ้งแม่น้ำตัวโต',
              'price': 250.0,
              'is_available': true,
              'image_url': 'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=200&q=80',
            },
          ]
        },
        {
          'id': 'cat_snack',
          'name': 'ของทานเล่น',
          'sort_order': 2,
          'is_active': true,
          'items': [
            {
              'id': 'item_snack_1',
              'category_id': 'cat_snack',
              'name': 'เปาะเปี๊ยะทอด',
              'description': 'เปาะเปี๊ยะไส้ผักทอดกรอบ',
              'price': 85.0,
              'is_available': true,
              'image_url': null,
            },
          ]
        },
        {
          'id': 'cat_drink',
          'name': 'เครื่องดื่ม',
          'sort_order': 3,
          'is_active': true,
          'items': [
            {
              'id': 'item_3',
              'category_id': 'cat_drink',
              'name': 'ชาไทยนมสด',
              'description': 'ชาไทยสีส้มเข้มข้น หอมกลิ่นชา',
              'price': 50.0,
              'is_available': true,
              'image_url': null,
            },
          ]
        },
        {
          'id': 'cat_dessert',
          'name': 'ของหวาน',
          'sort_order': 4,
          'is_active': true,
          'items': [
            {
              'id': 'item_dessert_1',
              'category_id': 'cat_dessert',
              'name': 'ข้าวเหนียวมะม่วง',
              'description': 'มะม่วงน้ำดอกไม้หวานฉ่ำ',
              'price': 160.0,
              'is_available': true,
              'image_url': null,
            },
          ]
        },
      ]
    };
  }

  List<Map<String, dynamic>> _mockModifierGroups() {
    return [
      {
        'id': 'group_1',
        'name': 'ผัก',
        'min_select': 0,
        'max_select': 3,
        'is_active': true,
        'item_count': 3,
        'modifiers': [
          {'id': 'mod_1', 'name': 'เพิ่มผักบุ้ง', 'price': 10.0, 'is_available': true},
          {'id': 'mod_2', 'name': 'เพิ่มถั่วงอก', 'price': 5.0, 'is_available': true},
          {'id': 'mod_3', 'name': 'ไม่เอาผัก', 'price': 0.0, 'is_available': true},
        ]
      },
      {
        'id': 'group_2',
        'name': 'ประเภท',
        'min_select': 1,
        'max_select': 1,
        'is_active': true,
        'item_count': 1,
        'modifiers': [
          {'id': 'mod_4', 'name': 'ปกติ', 'price': 0.0, 'is_available': true},
          {'id': 'mod_5', 'name': 'พิเศษ', 'price': 30.0, 'is_available': true},
        ]
      },
      {
        'id': 'group_3',
        'name': 'ประเภท',
        'min_select': 0,
        'max_select': 1,
        'is_active': true,
        'item_count': 0,
        'modifiers': [
          {'id': 'mod_6', 'name': 'หวาน', 'price': 0.0, 'is_available': true},
          {'id': 'mod_7', 'name': 'เค็ม', 'price': 0.0, 'is_available': true},
        ]
      },
      {
        'id': 'group_4',
        'name': 'ขนาด',
        'min_select': 1,
        'max_select': 1,
        'is_active': true,
        'item_count': 3,
        'modifiers': [
          {'id': 'mod_8', 'name': 'เล็ก', 'price': 0.0, 'is_available': true},
          {'id': 'mod_9', 'name': 'กลาง', 'price': 20.0, 'is_available': true},
          {'id': 'mod_10', 'name': 'ใหญ่', 'price': 40.0, 'is_available': true},
        ]
      },
      {
        'id': 'group_5',
        'name': 'ระดับความเผ็ด',
        'min_select': 0,
        'max_select': 1,
        'is_active': true,
        'item_count': 2,
        'modifiers': [
          {'id': 'mod_11', 'name': 'ไม่เผ็ด', 'price': 0.0, 'is_available': true},
          {'id': 'mod_12', 'name': 'เผ็ดน้อย', 'price': 0.0, 'is_available': true},
          {'id': 'mod_13', 'name': 'เผ็ดปกติ', 'price': 0.0, 'is_available': true},
          {'id': 'mod_14', 'name': 'เผ็ดมาก', 'price': 0.0, 'is_available': true},
        ]
      },
      {
        'id': 'group_6',
        'name': 'ท็อปปิ้ง',
        'min_select': 0,
        'max_select': 5,
        'is_active': true,
        'item_count': 3,
        'modifiers': [
          {'id': 'mod_15', 'name': 'เพิ่มไข่ดาว', 'price': 15.0, 'is_available': true},
          {'id': 'mod_16', 'name': 'เพิ่มข้าว', 'price': 20.0, 'is_available': true},
          {'id': 'mod_17', 'name': 'เพิ่มเนื้อ', 'price': 50.0, 'is_available': true},
        ]
      },
    ];
  }

  List<Map<String, dynamic>> _mockPendingOrders() {
    return [
      {
        'id': 'order_987654321',
        'customer_id': 'cust_1',
        'status': 'PLACED',
        'total_amount': 415.0,
        'food_total': 400.0,
        'delivery_fee': 15.0,
        'delivery_address': '456 ถนนพระราม 5, กรุงเทพฯ',
        'payment_method': 'credit_card',
        'original_eta_min': 25,
        'placed_at': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        'items': [
          {
            'id': 'oi_1',
            'menu_item_id': 'item_1',
            'name': 'แกงมัสมั่นไก่',
            'quantity': 1,
            'unit_price': 150.0,
            'subtotal': 150.0,
            'selected_modifiers': ['เพิ่มไข่ดาว', 'เผ็ดปกติ'],
          },
          {
            'id': 'oi_2',
            'menu_item_id': 'item_2',
            'name': 'ผัดไทยกุ้งแม่น้ำ',
            'quantity': 1,
            'unit_price': 250.0,
            'subtotal': 250.0,
            'selected_modifiers': ['พิเศษ'],
          },
        ],
      },
      {
        'id': 'order_112233445',
        'customer_id': 'cust_2',
        'status': 'PREPARING',
        'total_amount': 60.0,
        'food_total': 50.0,
        'delivery_fee': 10.0,
        'delivery_address': '789 ถนนนนทบุรี',
        'payment_method': 'cash',
        'original_eta_min': 15,
        'placed_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'items': [
          {
            'id': 'oi_3',
            'menu_item_id': 'item_3',
            'name': 'ชาไทยนมสด',
            'quantity': 1,
            'unit_price': 50.0,
            'subtotal': 50.0,
            'selected_modifiers': ['ความหวาน 50%'],
          },
        ],
      },
      {
        'id': 'order_556677889',
        'customer_id': 'cust_3',
        'status': 'READY_FOR_PICKUP',
        'total_amount': 245.0,
        'food_total': 230.0,
        'delivery_fee': 15.0,
        'delivery_address': '100 หมู่บ้านทองหล่อ',
        'payment_method': 'grab_pay',
        'original_eta_min': 20,
        'placed_at': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
        'items': [
          {
            'id': 'oi_4',
            'menu_item_id': 'item_snack_1',
            'name': 'เปาะเปี๊ยะทอด',
            'quantity': 1,
            'unit_price': 85.0,
            'subtotal': 85.0,
            'selected_modifiers': [],
          },
          {
            'id': 'oi_5',
            'menu_item_id': 'item_dessert_1',
            'name': 'ข้าวเหนียวมะม่วง',
            'quantity': 1,
            'unit_price': 160.0,
            'subtotal': 160.0,
            'selected_modifiers': [],
          },
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _mockOrderHistory() {
    return [
      {
        'id': 'order_hist_001',
        'status': 'DELIVERED',
        'total_amount': 350.0,
        'food_total': 330.0,
        'delivery_fee': 20.0,
        'placed_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'items': [
          {'id': 'oi_h1', 'name': 'แกงมัสมั่นไก่', 'quantity': 2, 'unit_price': 150.0, 'subtotal': 300.0},
        ],
      },
      {
        'id': 'order_hist_002',
        'status': 'DELIVERED',
        'total_amount': 175.0,
        'food_total': 160.0,
        'delivery_fee': 15.0,
        'placed_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'items': [
          {'id': 'oi_h2', 'name': 'ข้าวเหนียวมะม่วง', 'quantity': 1, 'unit_price': 160.0, 'subtotal': 160.0},
        ],
      },
    ];
  }
}
