import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/media/media_repository.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/notifications/notification_repository.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';

class _SpyApiClient extends ApiClient {
  final List<RequestOptions> requests = [];
  final Map<String, Object?> responses = {};

  late final Dio _spy = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final match = responses.keys.firstWhere(
            (k) => options.path.contains(k),
            orElse: () => '',
          );
          handler.resolve(Response(
            requestOptions: options,
            data: responses[match] ?? {},
            statusCode: 200,
          ));
        },
      ),
    );

  @override
  Dio get dio => _spy;

  RequestOptions get last => requests.last;
}

void main() {
  group('MediaCategory', () {
    test('carries the server-side limits', () {
      expect(MediaCategory.restaurant.maxBytes, 3 * 1024 * 1024);
      expect(MediaCategory.restaurantDoc.maxBytes, 5 * 1024 * 1024);
      expect(MediaCategory.avatar.maxBytes, 2 * 1024 * 1024);
    });

    test('logo/cover refuses webp, menu photos allow it', () {
      // The restaurant bucket really is the odd one out (SCRUM-53 §13).
      expect(MediaCategory.restaurant.accepts('image/webp'), isFalse);
      expect(MediaCategory.menu.accepts('image/webp'), isTrue);
    });

    test('only KYC accepts a PDF', () {
      expect(MediaCategory.restaurantDoc.accepts('application/pdf'), isTrue);
      expect(MediaCategory.menu.accepts('application/pdf'), isFalse);
    });
  });

  group('MediaRepository', () {
    test('asks for a signed URL with category and content type', () async {
      final api = _SpyApiClient()
        ..responses['upload-url'] = {
          'upload_url': 'https://storage.test/put',
          'file_key': 'restaurant_doc/u1/abc.jpg',
          'max_bytes': 5242880,
        };

      final ticket = await MediaRepository(api).createUploadUrl(
        category: MediaCategory.restaurantDoc,
        contentType: 'image/jpeg',
      );

      expect(api.last.path, '/api/media/upload-url');
      expect(api.last.queryParameters, {
        'category': 'restaurant_doc',
        'content_type': 'image/jpeg',
      });
      expect(ticket.fileKey, 'restaurant_doc/u1/abc.jpg');
    });

    test('a content type the bucket rejects never reaches the network',
        () async {
      final api = _SpyApiClient();

      await expectLater(
        MediaRepository(api).createUploadUrl(
          category: MediaCategory.restaurant,
          contentType: 'image/webp',
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(api.requests, isEmpty);
    });

    test('an oversized file is refused before uploading', () async {
      final api = _SpyApiClient();

      await expectLater(
        MediaRepository(api).uploadBytes(
          ticket: const UploadTicket(
            uploadUrl: 'https://storage.test/put',
            fileKey: 'menu/u1/a.jpg',
            maxBytes: 10,
          ),
          bytes: Uint8List(11),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('confirm posts the key back', () async {
      final api = _SpyApiClient();
      await MediaRepository(api).confirm('menu/u1/a.jpg');

      expect(api.last.method, 'POST');
      expect(api.last.path, '/api/media/confirm');
      expect(api.last.data, {'file_key': 'menu/u1/a.jpg'});
    });

    test('viewUrl exchanges a private key for a signed URL', () async {
      final api = _SpyApiClient()
        ..responses['media/view'] = {'view_url': 'https://signed.test/x'};

      final url = await MediaRepository(api).viewUrl('restaurant_doc/u1/a.jpg');

      expect(api.last.queryParameters, {'key': 'restaurant_doc/u1/a.jpg'});
      expect(url, 'https://signed.test/x');
    });
  });

  group('KYC documents', () {
    test('submitDocument sends the file key, not a URL', () async {
      final api = _SpyApiClient();

      await RestaurantRepository(api).submitDocument(
        docType: DocumentType.businessLicense,
        fileKey: 'restaurant_doc/u1/licence.jpg',
        docNumber: '0105558123456',
      );

      expect(api.last.method, 'POST');
      expect(api.last.path, '/api/food/restaurant/documents');
      expect(api.last.data, {
        'doc_type': 'business_license',
        'file_key': 'restaurant_doc/u1/licence.jpg',
        'doc_number': '0105558123456',
      });
    });

    test('an absent doc_number is omitted', () async {
      final api = _SpyApiClient();

      await RestaurantRepository(api).submitDocument(
        docType: DocumentType.taxId,
        fileKey: 'restaurant_doc/u1/tax.jpg',
      );

      expect((api.last.data as Map).containsKey('doc_number'), isFalse);
    });

    test('image_url is read as a file key and status is lowercase', () {
      final doc = RestaurantDocument.fromJson(const {
        'id': 'doc-1',
        'doc_type': 'business_license',
        'image_url': 'restaurant_doc/u1/licence.jpg',
        'status': 'rejected',
        'rejection_reason': 'Document is blurry',
      });

      expect(doc.fileKey, 'restaurant_doc/u1/licence.jpg');
      expect(doc.isRejected, isTrue);
      expect(doc.rejectionReason, 'Document is blurry');
    });
  });

  group('busy mode', () {
    test('duration_min is only sent when given', () async {
      final api = _SpyApiClient();
      final repo = RestaurantRepository(api);

      await repo.setBusy(true);
      expect((api.last.data as Map).containsKey('duration_min'), isFalse);

      await repo.setBusy(true, durationMin: 30);
      expect(api.last.data, {'is_busy': true, 'duration_min': 30});
    });
  });

  group('device registration', () {
    test('device_type is lowercased for the server', () async {
      final api = _SpyApiClient();

      await NotificationRepository(api)
          .registerDevice(token: 'fcm-token', deviceType: 'Android');

      expect(api.last.path, '/api/notifications/register-device');
      expect(api.last.data, {'token': 'fcm-token', 'device_type': 'android'});
    });

    test('unregister hits its own endpoint', () async {
      final api = _SpyApiClient();

      await NotificationRepository(api)
          .unregisterDevice(token: 'fcm-token', deviceType: 'ios');

      expect(api.last.path, '/api/notifications/unregister-device');
    });
  });
}
