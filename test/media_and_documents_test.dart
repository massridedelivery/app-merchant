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
  _scrum54();

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

/// SCRUM-54 — the backend now rejects any image field that is not a bare media
/// `file_key` (enforcement merged as `a605ec4`), and the nightly orphan sweep
/// deletes the live object behind a row that stores a URL instead of a key.
/// These pin the merchant app's side of that contract.
void _scrum54() {
  group('SCRUM-54 file_key contract', () {
    test('upload returns the bare key, never a URL', () async {
      final api = _SpyApiClient()
        ..responses['/api/media/upload-url'] = {
          'upload_url': 'https://storage.test/restaurant/me/logo.jpg?sig=abc',
          'file_key': 'restaurant/me/logo.jpg',
          'max_bytes': 3145728,
        }
        ..responses['/api/media/confirm'] = {'confirmed': true};

      final key = await MediaRepository(api).upload(
        category: MediaCategory.restaurant,
        contentType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(key, 'restaurant/me/logo.jpg');
      expect(key, isNot(startsWith('http')));
    });

    test('confirm runs before the key is handed to a domain endpoint',
        () async {
      final api = _SpyApiClient()
        ..responses['/api/media/upload-url'] = {
          'upload_url': 'https://storage.test/x.jpg',
          'file_key': 'restaurant_doc/me/x.jpg',
          'max_bytes': 5242880,
        }
        ..responses['/api/media/confirm'] = {'confirmed': true}
        ..responses['/restaurant/documents'] = {'message': 'ok'};

      final media = MediaRepository(api);
      final restaurant = RestaurantRepository(api);
      final key = await media.upload(
        category: MediaCategory.restaurantDoc,
        contentType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );
      await restaurant.submitDocument(docType: 'tax_id', fileKey: key);

      final paths = api.requests.map((r) => r.path).toList();
      // Skipping confirm is how a key gets attached to a row before the object
      // is validated — the sweep then treats it as an orphan.
      expect(
        paths.indexWhere((p) => p.contains('/api/media/confirm')),
        lessThan(paths.indexWhere((p) => p.contains('/restaurant/documents'))),
      );
    });

    test('rejects an oversized file before asking for an upload URL', () async {
      final api = _SpyApiClient();

      await expectLater(
        MediaRepository(api).upload(
          // avatar caps at 2 MB.
          category: MediaCategory.avatar,
          contentType: 'image/png',
          bytes: Uint8List(3 * 1024 * 1024),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(api.requests, isEmpty, reason: 'should not have called the API');
    });

    test('rejects a content type the category does not allow', () async {
      final api = _SpyApiClient();

      await expectLater(
        // `restaurant` takes no webp, unlike `menu` and `avatar`.
        MediaRepository(api).upload(
          category: MediaCategory.restaurant,
          contentType: 'image/webp',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(api.requests, isEmpty);
    });

    test('profile keeps logo and cover absent when no new image was picked',
        () async {
      final api = _SpyApiClient()..responses['/restaurant/profile'] = {};

      await RestaurantRepository(api).updateProfile(name: 'ครัวสมชาย');

      // The read side returns logo_url as a full URL while the write side wants
      // a key, so a read-modify-write that echoes the profile back is exactly
      // what SCRUM-54 warns about. Omitting the field is what keeps that safe.
      final body = api.last.data as Map<String, dynamic>;
      expect(body.containsKey('logo_url'), isFalse);
      expect(body.containsKey('cover_image_url'), isFalse);
    });

    test('profile sends the file_key verbatim on both image fields', () async {
      final api = _SpyApiClient()..responses['/restaurant/profile'] = {};

      await RestaurantRepository(api).updateProfile(
        name: 'ครัวสมชาย',
        logoFileKey: 'restaurant/me/logo.jpg',
        coverFileKey: 'restaurant/me/cover.jpg',
      );

      final body = api.last.data as Map<String, dynamic>;
      expect(body['logo_url'], 'restaurant/me/logo.jpg');
      expect(body['cover_image_url'], 'restaurant/me/cover.jpg');
    });
  });
}
