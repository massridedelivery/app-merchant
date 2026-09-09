import 'package:dio/dio.dart';

import 'api_logger.dart';

/// Access token handed out by the mock `/auth/*` routes. Decodes to
/// `{user_id, role: restaurant, exp: 2030}` so the whole session flow — claims,
/// role check, restaurant id — works with no server.
const String mockAccessToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiOWYxYzBmNmUtM2IzYS00YTFlLTljMmQtNmE1ZTRiM2MyZDEwIiwicm9sZSI6InJlc3RhdXJhbnQiLCJzaWQiOiJtb2NrLXNlc3Npb24iLCJleHAiOjE4OTM0NTYwMDAsImlhdCI6MTc4NTkxMzYwMH0.mock-signature';

/// The only OTP the mock accepts, so the wrong-code path stays testable
/// without a server.
const String mockOtpCode = '123456';

class MockInterceptor extends Interceptor {

  /// Answers with canned data.
  ///
  /// `callFollowingResponseInterceptor: true` matters: the default skips every
  /// response interceptor, which would hide mock traffic from [ApiLogInterceptor]
  /// — the exact thing that makes mock and network indistinguishable.
  void _serve(
    RequestOptions options,
    RequestInterceptorHandler handler,
    Response response,
  ) {
    options.extra[ApiLogInterceptor.mockedKey] = true;
    handler.resolve(response, true);
  }

  /// Same, for the paths where the mock refuses.
  void _fail(
    RequestOptions options,
    RequestInterceptorHandler handler,
    DioException error,
  ) {
    options.extra[ApiLogInterceptor.mockedKey] = true;
    handler.reject(error, true);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final method = options.method;

    // ─── AUTH ───────────────────────────────────────────────
    // A structurally real JWT so AuthClaims.tryParse works offline: role
    // `restaurant`, user_id doubling as the restaurant_id, exp in 2030.
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'access_token': mockAccessToken,
          'refresh_token': 'mock-refresh-token',
          'expires_in': 86400,
        },
        statusCode: path.contains('/auth/register') ? 201 : 200,
      ));
    }
    // Phone OTP. `is_registered` decides whether the app routes to login or to
    // the 7-step signup, so one canned number answers as an existing account
    // and everything else as a new one.
    if (path.contains('/auth/otp/send')) {
      final phone = (options.data as Map?)?['phone']?.toString() ?? '';
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'ref_id': 'mock-ref-${DateTime.now().millisecondsSinceEpoch}',
          'is_registered': phone.endsWith('812345678'),
          'message': 'OTP sent',
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/auth/otp/verify')) {
      final otp = (options.data as Map?)?['otp']?.toString() ?? '';
      // Accepting only one code keeps the wrong-OTP path reachable offline.
      if (otp != mockOtpCode) {
        return _fail(options, handler,
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              data: {'error': 'invalid or expired OTP'},
              statusCode: 400,
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      }
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'access_token': mockAccessToken,
          'refresh_token': 'mock-refresh-token',
          'expires_in': 86400,
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/auth/logout')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'message': 'logged out successfully'},
        statusCode: 200,
      ));
    }
    // Account deletion (SCRUM-114).
    if (path.contains('/auth/account') && method == 'DELETE') {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'message': 'account deleted successfully'},
        statusCode: 200,
      ));
    }

    // ─── RESTAURANT PROFILE ─────────────────────────────────
    if (path.contains('/restaurant/profile')) {
      if (method == 'PUT') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'Profile updated successfully'},
          statusCode: 200,
        ));
      }
      return _serve(options, handler, Response(
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
          'phone': '0649426362',
          'email': 'may_7781@hotmail.com',
          'manager_name': 'เมย์ ใจดี',
          'manager_phone': '0649426362',
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
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'is_open': true},
        statusCode: 200,
      ));
    }

    // ─── BUSY MODE ──────────────────────────────────────────
    if (path.contains('/restaurant/busy')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'message': 'Busy mode updated'},
        statusCode: 200,
      ));
    }

    // ─── STORE HOURS ────────────────────────────────────────
    if (path.contains('/restaurant/hours')) {
      if (method == 'PUT') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'Hours updated successfully'},
          statusCode: 200,
        ));
      }
      return _serve(options, handler, Response(
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

    // ─── MENU (GET /api/food/restaurant/{id}/menu) ──────────
    // endsWith('/menu') keeps this off `/menu/categories` and `/menu/items`,
    // which are handled further down.
    if (path.contains('/restaurant/') && path.endsWith('/menu')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: _mockMenuData(),
        statusCode: 200,
      ));
    }

    // ─── MENU: MERCHANT READ (categories + nested items) ────
    // GET /api/food/restaurant/{id}/menu — the merchant menu screen's read.
    // Matches after the customer path above so it only catches the merchant
    // form (/restaurants/ plural never matches /restaurant/).
    if (path.contains('/restaurant/') && path.endsWith('/menu')) {
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
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
          requestOptions: options,
          data: _mockMenuData()['categories'],
          statusCode: 200,
        ));
      }
      if (method == 'PUT') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'updated successfully'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'item updated successfully'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'modifier updated'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'modifier group linked to item'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── MODIFIER GROUPS ─────────────────────────────────────
    if (path.contains('/modifier-groups') && !path.contains('/modifiers')) {
      if (method == 'GET') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: _mockModifierGroups(),
          statusCode: 200,
        ));
      }
      if (method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        return _serve(options, handler, Response(
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
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'modifier group updated'},
          statusCode: 200,
        ));
      }
      if (method == 'DELETE') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: null,
          statusCode: 204,
        ));
      }
    }

    // ─── ORDERS: PENDING ────────────────────────────────────
    if (path.contains('/restaurant/orders/pending')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: _mockPendingOrders(),
        statusCode: 200,
      ));
    }

    // ─── ORDERS: HISTORY ────────────────────────────────────
    if (path.contains('/restaurant/orders/history')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: _mockOrderHistory(),
        statusCode: 200,
      ));
    }

    // ─── ORDER ACTIONS ──────────────────────────────────────
    if (path.contains('/restaurant/orders/') && path.contains('/ops')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'message': 'order updated successfully'},
        statusCode: 200,
      ));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/accept')) {
      return _serve(options, handler, Response(requestOptions: options, data: {'message': 'RESTAURANT_ACCEPTED'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/reject')) {
      return _serve(options, handler, Response(requestOptions: options, data: {'message': 'RESTAURANT_REJECTED'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/preparing')) {
      return _serve(options, handler, Response(requestOptions: options, data: {'message': 'PREPARING'}, statusCode: 200));
    }
    if (path.contains('/restaurant/orders/') && path.contains('/ready')) {
      return _serve(options, handler, Response(requestOptions: options, data: {'message': 'READY_FOR_PICKUP'}, statusCode: 200));
    }

    // ─── FINANCE ────────────────────────────────────────────
    // Auto-payout (SCRUM-77) — must precede the generic finance branches.
    if (path.contains('/restaurant/finance/auto-payout')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'enabled': false, 'day_of_week': 1, 'min_amount': 100},
        statusCode: 200,
      ));
    }
    if (path.contains('/restaurant/finance/summary')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'balance': 5250.0,
          'available_balance': 5250.0,
          'pending_withdrawal': 0.0,
          'lifetime_earnings': 42000.0,
          'total_withdrawn': 36750.0,
          'can_withdraw': true,
          // Fee model (SCRUM-78) — currently free.
          'withdrawal_fee_flat': 0,
          'withdrawal_fee_rate': 0,
          'withholding_tax_rate': 0,
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/restaurant/finance/transactions')) {
      return _serve(options, handler, Response(requestOptions: options, data: [], statusCode: 200));
    }
    if (path.contains('/restaurant/finance/earnings')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'balance': 0.0, 'pending': 0.0, 'transactions': []},
        statusCode: 200,
      ));
    }

    // ─── WITHDRAW ────────────────────────────────────────────
    if (path.contains('/restaurant/withdraw') && method == 'POST') {
      final amount = (options.data is Map)
          ? ((options.data as Map)['amount'] as num?)?.toDouble() ?? 0
          : 0.0;
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'id': 'wd_${DateTime.now().millisecondsSinceEpoch}',
          'amount': amount,
          'fee': 0,
          'net_amount': amount,
          'status': 'pending',
        },
        statusCode: 200,
      ));
    }

    // ─── WITHDRAWAL HISTORY ──────────────────────────────────
    if (path.endsWith('/restaurant/withdrawals')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: [
          {'id': 'wd_1', 'amount': 1250, 'fee': 0, 'net_amount': 1250, 'status': 'completed', 'created_at': '2026-08-18T10:00:00Z'},
          {'id': 'wd_2', 'amount': 800, 'fee': 0, 'net_amount': 800, 'status': 'pending', 'created_at': '2026-08-20T09:00:00Z'},
        ],
        statusCode: 200,
      ));
    }

    // ─── BANK ACCOUNT (SCRUM-60) ─────────────────────────────
    if (path.contains('/restaurant/bank-account')) {
      if (method == 'PUT') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'bank account updated successfully'},
          statusCode: 200,
        ));
      }
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'bank_name': 'ธนาคารไทยพาณิชย์',
          'bank_code': '014',
          'account_number_masked': '•••• 1234',
          'account_name': 'เมย์ ใจดี',
        },
        statusCode: 200,
      ));
    }

    // ─── ADS ────────────────────────────────────────────────
    if (path.contains('/restaurant/ads')) {
      return _serve(options, handler, Response(
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

    // ─── KYC DOCUMENTS ──────────────────────────────────────
    if (path.contains('/restaurant/documents')) {
      if (method == 'POST') {
        return _serve(options, handler, Response(
          requestOptions: options,
          data: {'message': 'document uploaded successfully'},
          statusCode: 200,
        ));
      }
      return _serve(options, handler, Response(
        requestOptions: options,
        data: [
          {
            'id': 'doc_1',
            'doc_type': 'business_license',
            'doc_number': '0105558123456',
            'image_url': 'restaurant_doc/mock-user/licence.jpg',
            'status': 'approved',
            'uploaded_at': '2026-06-10T02:45:11Z',
            'verified_at': '2026-06-14T09:12:33Z',
          },
          {
            'id': 'doc_2',
            'doc_type': 'tax_id',
            'image_url': 'restaurant_doc/mock-user/tax.jpg',
            'status': 'rejected',
            'rejection_reason': 'เอกสารเบลอ อ่านไม่ออก',
            'uploaded_at': '2026-06-11T03:10:00Z',
          },
        ],
        statusCode: 200,
      ));
    }

    // ─── PUSH DEVICE REGISTRATION ───────────────────────────
    if (path.contains('/api/notifications/register-device') ||
        path.contains('/api/notifications/unregister-device')) {
      final token = (options.data as Map?)?['token'];
      if (token == null || (token is String && token.isEmpty)) {
        return _fail(
          options,
          handler,
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              data: {'error': 'token is required'},
              statusCode: 422,
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      }
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {'status': 'success'},
        statusCode: 200,
      ));
    }

    // ─── MEDIA (3-step upload) ──────────────────────────────
    if (path.contains('/api/media/upload-url')) {
      final category = options.queryParameters['category'] ?? 'restaurant';
      final key =
          '$category/mock-user/${DateTime.now().millisecondsSinceEpoch}.jpg';
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'upload_url': 'https://storage.mock.local/$key?signature=mock',
          'file_key': key,
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
          'max_bytes': category == 'restaurant_doc' ? 5242880 : 3145728,
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/api/media/confirm')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'file_key': (options.data as Map)['file_key'],
          'confirmed': true,
        },
        statusCode: 200,
      ));
    }
    if (path.contains('/api/media/view')) {
      return _serve(options, handler, Response(
        requestOptions: options,
        data: {
          'view_url':
              'https://storage.mock.local/${options.queryParameters['key']}?signed=mock',
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
