import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/network/mock_interceptor.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';

/// Runs requests through the real MockInterceptor, so these tests fail if a
/// route the app calls is missing from it — which is exactly what broke the
/// OTP screen.
class _MockedApiClient extends ApiClient {
  late final Dio _mocked = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(MockInterceptor());

  @override
  Dio get dio => _mocked;

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

/// Never reaches a server — stands in for "the backend is not running".
class _UnreachableApiClient extends ApiClient {
  late final Dio _dead = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );

  @override
  Dio get dio => _dead;

  @override
  Future<String?> readToken() async => null;
}

void main() {
  Future<AuthNotifier> notifier(ApiClient api) async {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final n = container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    return n;
  }

  group('offline mock', () {
    test('sending an OTP is answered rather than escaping to the network',
        () async {
      final auth = await notifier(_MockedApiClient());

      final result = await auth.requestOtp('0651111111');

      expect(result.refId, isNotEmpty);
      expect(result.isRegistered, isFalse, reason: 'an unknown phone is new');
    });

    test('the canned number comes back as an existing account', () async {
      final auth = await notifier(_MockedApiClient());

      expect((await auth.requestOtp('0812345678')).isRegistered, isTrue);
    });

    test('verifying the right code signs in', () async {
      final auth = await notifier(_MockedApiClient());
      final sent = await auth.requestOtp('0651111111');

      await auth.confirmOtp(
        phone: '0651111111',
        otp: mockOtpCode,
        refId: sent.refId,
      );
    });

    test('a wrong code is rejected with the server text', () async {
      final auth = await notifier(_MockedApiClient());
      final sent = await auth.requestOtp('0651111111');

      await expectLater(
        auth.confirmOtp(
          phone: '0651111111',
          otp: '000000',
          refId: sent.refId,
        ),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            'invalid or expired OTP',
          ),
        ),
      );
    });
  });

  group('unreachable backend', () {
    test('says the connection failed, not that the OTP was refused', () async {
      // The generic fallback made a dead server look like a rejected phone
      // number, which is what sent this bug hunting in the wrong place.
      final auth = await notifier(_UnreachableApiClient());

      await expectLater(
        auth.requestOtp('0651111111'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            contains('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'),
          ),
        ),
      );
    });

    test('a timeout is reported as a timeout', () async {
      final api = _UnreachableApiClient();
      api.dio.interceptors.clear();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        ),
      );
      final auth = await notifier(api);

      await expectLater(
        auth.requestOtp('0651111111'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            contains('ไม่ตอบสนอง'),
          ),
        ),
      );
    });
  });
}
