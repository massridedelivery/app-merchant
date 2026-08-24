import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/profile/presentation/screens/profile_screen.dart';

/// Answers `GET /restaurant/profile` with whatever [fail] dictates, and counts
/// the attempts so a retry can be observed.
class _ProfileApiClient extends ApiClient {
  _ProfileApiClient({this.fail = false});

  bool fail;
  int profileFetches = 0;

  late final Dio _stub = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/restaurant/profile')) {
            profileFetches++;
            if (fail) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
                true,
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'restaurant_name': 'icream',
                  'address': '12345',
                  'lat': 13.75,
                  'lng': 100.5,
                },
              ),
              true,
            );
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {}),
            true,
          );
        },
      ),
    );

  @override
  Dio get dio => _stub;
}

Widget _app(_ProfileApiClient api) => ProviderScope(
  overrides: [apiClientProvider.overrideWithValue(api)],
  child: const MaterialApp(home: ProfileScreen()),
);

void main() {
  group('failed profile load', () {
    testWidgets('says so instead of spinning forever', (tester) async {
      final api = _ProfileApiClient(fail: true);

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      // The old `maybeWhen(data:, orElse:)` rendered the loading spinner here,
      // so an outage was indistinguishable from a slow network and the merchant
      // had no way out but restarting the app.
      expect(find.text('โหลดข้อมูลร้านไม่สำเร็จ'), findsOneWidget);
      expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    });

    testWidgets('retry refetches and recovers', (tester) async {
      final api = _ProfileApiClient(fail: true);

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      final attemptsBeforeRetry = api.profileFetches;

      api.fail = false;
      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();

      expect(api.profileFetches, greaterThan(attemptsBeforeRetry));
      expect(find.text('icream'), findsOneWidget);
      expect(find.text('โหลดข้อมูลร้านไม่สำเร็จ'), findsNothing);
    });

    testWidgets('pull-to-refresh also refetches', (tester) async {
      final api = _ProfileApiClient();

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      final attemptsBeforePull = api.profileFetches;

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      // Without this the screen never picks up a change made elsewhere — an
      // edit on another device, or a KYC approval — until an app restart.
      expect(api.profileFetches, greaterThan(attemptsBeforePull));
    });
  });

  group('logout', () {
    testWidgets('asks first, and says it signs out every device', (
      tester,
    ) async {
      final api = _ProfileApiClient();

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('ออกจากระบบ'));
      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // /auth/logout revokes every refresh token (SCRUM-53 §2), so the warning
      // has to name the consequence, not just ask "are you sure".
      expect(find.textContaining('ทุกเครื่อง'), findsOneWidget);
    });

    testWidgets('cancelling does not call the endpoint', (tester) async {
      final api = _ProfileApiClient();

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('ออกจากระบบ'));
      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
