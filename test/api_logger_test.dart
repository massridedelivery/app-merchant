import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/network/api_logger.dart';
import 'package:merchant_app/core/network/mock_interceptor.dart';



/// The interceptor writes through dart:developer, which a test cannot read
/// back, so this mirrors its decisions on the same inputs.
void main() {
  group('mock traffic is labelled', () {
    late Dio dio;
    late List<RequestOptions> seen;

    setUp(() {
      seen = [];
      dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: false))
        ..interceptors.add(MockInterceptor())
        ..interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              seen.add(response.requestOptions);
              handler.next(response);
            },
            onError: (error, handler) {
              seen.add(error.requestOptions);
              handler.next(error);
            },
          ),
        );
    });

    test('a mock-served response still reaches later interceptors', () async {
      // Before this, MockInterceptor resolved with the default flag and every
      // response interceptor after it was skipped — so nothing could observe
      // mock traffic at all.
      final response = await dio.post('/auth/otp/send', data: {'phone': '+66'});

      expect(response.statusCode, 200);
      expect(seen, hasLength(1));
      expect(seen.single.extra[ApiLogInterceptor.mockedKey], isTrue);
    });

    test('a mock rejection is labelled too', () async {
      await expectLater(
        dio.post('/auth/otp/verify', data: {'otp': 'wrong'}),
        throwsA(isA<DioException>()),
      );

      expect(seen, hasLength(1));
      expect(seen.single.extra[ApiLogInterceptor.mockedKey], isTrue);
    });

    test('a route the mock does not know is not labelled as mock', () async {
      // This is the shape of the OTP bug: unmatched paths fall through to the
      // network, and the log has to show that rather than imply mock served it.
      await expectLater(
        dio.get('/api/food/restaurant/not-a-real-route'),
        throwsA(isA<DioException>()),
      );

      expect(seen, hasLength(1));
      expect(seen.single.extra[ApiLogInterceptor.mockedKey], isNull);
    });
  });

  group('logging is opt-out', () {
    test('a disabled logger records no timing marker', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: false))
        ..interceptors.add(MockInterceptor());

      final response = await dio.get('/api/food/restaurant/profile');

      expect(response.requestOptions.extra.containsKey('log_started_at'),
          isFalse);
    });

    test('an enabled logger stamps the start time it measures against',
        () async {
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: true))
        ..interceptors.add(MockInterceptor());

      final response = await dio.get('/api/food/restaurant/profile');

      expect(response.requestOptions.extra['log_started_at'], isA<DateTime>());
    });
  });

  group('the lines actually reach the console', () {
    late List<String> printed;
    late DebugPrintCallback original;

    setUp(() {
      printed = [];
      original = debugPrint;
      // debugPrint is what `flutter run` shows; swapping it is how a test can
      // prove the log really goes there rather than to DevTools only.
      debugPrint = (message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
    });

    tearDown(() => debugPrint = original);

    Dio dioWithLogger() => Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
      ..interceptors.add(ApiLogInterceptor(enabled: true))
      ..interceptors.add(MockInterceptor());

    test('a request and its response are both printed, tagged', () async {
      await dioWithLogger().post('/auth/otp/send', data: {'phone': '+66123'});

      expect(printed.every((l) => l.startsWith('[API]')), isTrue);
      expect(printed.any((l) => l.contains('→ POST')), isTrue);
      expect(printed.any((l) => l.contains('"phone":"+66123"')), isTrue);
      expect(printed.any((l) => l.contains('← 200')), isTrue);
    });

    test('the line says who answered and how long it took', () async {
      await dioWithLogger().get('/api/food/restaurant/profile');

      final response = printed.firstWhere((l) => l.contains('← 200'));
      expect(response, contains('[MOCK]'));
      expect(response, contains('ms'));
      expect(response, contains('/api/food/restaurant/profile'));
    });

    test('a failure prints why, not just that it failed', () async {
      await expectLater(
        dioWithLogger().post('/auth/otp/verify', data: {'otp': 'nope'}),
        throwsA(isA<DioException>()),
      );

      expect(printed.any((l) => l.contains('✗ 400')), isTrue);
      expect(printed.any((l) => l.contains('invalid or expired OTP')), isTrue);
    });

    test('a long body is truncated rather than flooding the console', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: true, maxBodyChars: 40))
        ..interceptors.add(MockInterceptor());

      await dio.get('/api/food/restaurant/profile');

      expect(printed.any((l) => l.contains('chars)')), isTrue);
      expect(printed.every((l) => l.length < 200), isTrue);
    });

    test('nothing is printed when logging is off', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: false))
        ..interceptors.add(MockInterceptor());

      await dio.get('/api/food/restaurant/profile');

      expect(printed, isEmpty);
    });
  });

  group('every endpoint the app calls is answered offline', () {
    // A route the mock does not know silently escapes to the network and fails
    // like an outage. That has now bitten twice — the OTP screen, then the menu
    // tab after its path moved — so the coverage is asserted rather than
    // eyeballed.
    late Dio dio;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
        ..interceptors.add(ApiLogInterceptor(enabled: false))
        ..interceptors.add(MockInterceptor());
    });

    Future<Response<dynamic>> call(String method, String path) => dio.request(
          path,
          data: const <String, dynamic>{'token': 'x', 'otp': '123456'},
          options: Options(method: method),
        );

    for (final route in const [
      ['GET', '/api/food/restaurant/rest-1/menu'],
      ['GET', '/api/food/restaurant/menu/categories'],
      ['GET', '/api/food/restaurant/profile'],
      ['GET', '/api/food/restaurant/orders/pending'],
      ['GET', '/api/food/restaurant/documents'],
      ['GET', '/api/food/restaurant/ads'],
      ['GET', '/api/media/upload-url'],
      ['POST', '/api/notifications/register-device'],
      ['POST', '/api/notifications/unregister-device'],
      ['POST', '/auth/otp/send'],
      ['POST', '/auth/login'],
    ]) {
      test('${route[0]} ${route[1]} is served by the mock', () async {
        final response = await call(route[0], route[1]);
        expect(
          response.requestOptions.extra[ApiLogInterceptor.mockedKey],
          isTrue,
          reason: '${route[1]} escaped to the network',
        );
      });
    }

    test('the menu read is not confused with menu/categories', () async {
      // endsWith('/menu') is what keeps these apart.
      final menu = await call('GET', '/api/food/restaurant/rest-1/menu');
      expect((menu.data as Map).containsKey('categories'), isTrue);

      final categories =
          await call('GET', '/api/food/restaurant/menu/categories');
      expect(categories.data, isA<List<dynamic>>());
    });

    test('device registration without a token is refused', () async {
      await expectLater(
        dio.post('/api/notifications/register-device', data: {'token': ''}),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            422,
          ),
        ),
      );
    });
  });
}
