import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/kyc_documents_screen.dart';
import 'package:merchant_app/features/restaurant/providers/document_provider.dart';

/// Answers every request from [responses], keyed by a substring of the path,
/// and records what was asked. Nothing reaches the network.
class _StubApiClient extends ApiClient {
  _StubApiClient(this.responses);

  final Map<String, Object?> responses;
  final List<RequestOptions> requests = [];

  late final Dio _stub = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final key = responses.keys.firstWhere(
            (k) => options.path.contains(k),
            orElse: () => '',
          );
          handler.resolve(Response(
            requestOptions: options,
            data: responses[key] ?? {},
            statusCode: 200,
          ));
        },
      ),
    );

  @override
  Dio get dio => _stub;

  /// The notifier fetches on construction, so `/documents` matches a GET
  /// before it ever matches the POST under test — always say which.
  RequestOptions requestTo(String fragment, {String method = 'GET'}) =>
      requests.firstWhere(
        (r) => r.path.contains(fragment) && r.method == method,
      );
}

const _approvedLicence = {
  'id': 'doc_1',
  'doc_type': 'business_license',
  'doc_number': '0105558123456',
  'image_url': 'restaurant_doc/me/licence.jpg',
  'status': 'approved',
  'uploaded_at': '2026-06-10T02:45:11Z',
};

const _rejectedTaxId = {
  'id': 'doc_2',
  'doc_type': 'tax_id',
  'image_url': 'restaurant_doc/me/tax.jpg',
  'status': 'rejected',
  'rejection_reason': 'เอกสารเบลอ อ่านไม่ออก',
  'uploaded_at': '2026-06-11T03:10:00Z',
};

ProviderContainer _container(_StubApiClient api) {
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _screen(_StubApiClient api) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: const MaterialApp(home: KycDocumentsScreen()),
  );
}

void main() {
  group('latestFor', () {
    test('picks the newest upload when a type was filed more than once', () {
      final documents = [
        RestaurantDocument.fromJson({
          ..._rejectedTaxId,
          'id': 'old',
          'uploaded_at': '2026-06-01T00:00:00Z',
        }),
        RestaurantDocument.fromJson({
          ..._rejectedTaxId,
          'id': 'new',
          'status': 'pending',
          'uploaded_at': '2026-07-01T00:00:00Z',
        }),
      ];

      // Re-uploading appends rather than replaces, so showing the first match
      // would leave a merchant staring at the rejection they just fixed.
      expect(documents.latestFor(DocumentType.taxId)?.id, 'new');
    });

    test('returns null for a type that was never filed', () {
      final documents = [RestaurantDocument.fromJson(_approvedLicence)];
      expect(documents.latestFor(DocumentType.menuSample), isNull);
    });

    test('a document without uploaded_at never outranks one that has it', () {
      final documents = [
        RestaurantDocument.fromJson({
          ..._approvedLicence,
          'id': 'dated',
          'uploaded_at': '2026-06-10T00:00:00Z',
        }),
        RestaurantDocument.fromJson({
          ..._approvedLicence,
          'id': 'undated',
          'uploaded_at': null,
        }),
      ];
      expect(documents.latestFor(DocumentType.businessLicense)?.id, 'dated');
    });
  });

  group('submitDocument', () {
    test('uploads to the private bucket, then files the returned file_key',
        () async {
      final api = _StubApiClient({
        '/api/media/upload-url': {
          'upload_url': 'https://storage.test/restaurant_doc/me/x.jpg?sig=1',
          'file_key': 'restaurant_doc/me/x.jpg',
          'max_bytes': 5242880,
        },
        '/api/media/confirm': {'confirmed': true},
        '/restaurant/documents': <Map<String, dynamic>>[],
      });
      final container = _container(api);
      final notifier = container.read(restaurantDocumentsProvider.notifier);

      await notifier.submitDocument(
        docType: DocumentType.businessLicense,
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        docNumber: '0105558123456',
      );

      // Category decides the bucket and the size cap; a KYC file uploaded as
      // `restaurant` would land in the public bucket.
      expect(
        api.requestTo('/api/media/upload-url').queryParameters['category'],
        'restaurant_doc',
      );

      final post =
          api.requestTo('/restaurant/documents', method: 'POST');
      final body = post.data as Map<String, dynamic>;
      expect(body['doc_type'], 'business_license');
      expect(body['doc_number'], '0105558123456');
      // The domain call takes the key from step 1 — never a URL or a path.
      expect(body['file_key'], 'restaurant_doc/me/x.jpg');
    });

    test('omits doc_number rather than sending an empty one', () async {
      final api = _StubApiClient({
        '/api/media/upload-url': {
          'upload_url': 'https://storage.test/x.jpg',
          'file_key': 'restaurant_doc/me/menu.jpg',
          'max_bytes': 5242880,
        },
        '/api/media/confirm': {'confirmed': true},
        '/restaurant/documents': <Map<String, dynamic>>[],
      });
      final container = _container(api);

      await container.read(restaurantDocumentsProvider.notifier).submitDocument(
            docType: DocumentType.menuSample,
            bytes: Uint8List.fromList([1]),
            contentType: 'image/png',
          );

      final body = api
          .requestTo('/restaurant/documents', method: 'POST')
          .data as Map<String, dynamic>;
      expect(body.containsKey('doc_number'), isFalse);
    });

    test('refetches after filing, so the new status comes from the server',
        () async {
      final api = _StubApiClient({
        '/api/media/upload-url': {
          'upload_url': 'https://storage.test/x.jpg',
          'file_key': 'restaurant_doc/me/x.jpg',
          'max_bytes': 5242880,
        },
        '/api/media/confirm': {'confirmed': true},
        '/restaurant/documents': [_approvedLicence],
      });
      final container = _container(api);
      final notifier = container.read(restaurantDocumentsProvider.notifier);
      await notifier.fetchDocuments();

      final before =
          api.requests.where((r) => r.path.contains('/documents')).length;
      await notifier.submitDocument(
        docType: DocumentType.taxId,
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );
      final after =
          api.requests.where((r) => r.path.contains('/documents')).length;

      // Approval is admin-side and asynchronous — the client never invents a
      // status, it asks again.
      expect(after, greaterThan(before + 1));
    });
  });

  group('viewUrl', () {
    test('exchanges the file key for a signed URL', () async {
      final api = _StubApiClient({
        '/restaurant/documents': [_approvedLicence],
        '/api/media/view': {'view_url': 'https://signed.test/licence.jpg?s=1'},
      });
      final container = _container(api);
      final notifier = container.read(restaurantDocumentsProvider.notifier);

      final url = await notifier
          .viewUrl(RestaurantDocument.fromJson(_approvedLicence));

      expect(url, 'https://signed.test/licence.jpg?s=1');
      expect(
        api.requestTo('/api/media/view').queryParameters['key'],
        'restaurant_doc/me/licence.jpg',
      );
    });

    test('does not call the API for a document with no key', () async {
      final api = _StubApiClient({'/restaurant/documents': []});
      final container = _container(api);
      final notifier = container.read(restaurantDocumentsProvider.notifier);
      await notifier.fetchDocuments();

      final url = await notifier.viewUrl(
        RestaurantDocument.fromJson({
          'id': 'x',
          'doc_type': 'tax_id',
          'status': 'pending',
        }),
      );

      expect(url, isNull);
      expect(api.requests.any((r) => r.path.contains('/media/view')), isFalse);
    });
  });

  group('KycDocumentsScreen', () {
    testWidgets('shows every required type, including ones never filed',
        (tester) async {
      final api = _StubApiClient({
        '/restaurant/documents': [_approvedLicence, _rejectedTaxId],
        '/restaurant/profile': {'verification_status': 'PENDING'},
      });

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      for (final type in DocumentType.all) {
        expect(find.text(DocumentType.label(type)), findsOneWidget);
      }
      // menu_sample was never uploaded and must still be offered.
      expect(find.text('ยังไม่อัปโหลด'), findsOneWidget);
    });

    testWidgets('surfaces the rejection reason so it can be acted on',
        (tester) async {
      final api = _StubApiClient({
        '/restaurant/documents': [_rejectedTaxId],
        '/restaurant/profile': {'verification_status': 'REJECTED'},
      });

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.text('เอกสารเบลอ อ่านไม่ออก'), findsOneWidget);
      expect(find.text('การยืนยันไม่ผ่าน'), findsOneWidget);
    });

    testWidgets('offers re-upload for a rejected document but not an approved one',
        (tester) async {
      final api = _StubApiClient({
        '/restaurant/documents': [_approvedLicence, _rejectedTaxId],
        '/restaurant/profile': {'verification_status': 'PENDING'},
      });

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      // business_license is approved → no button at all; tax_id is rejected and
      // menu_sample is missing → one 'อัปโหลดใหม่' and one 'อัปโหลด'.
      expect(find.text('อัปโหลดใหม่'), findsOneWidget);
      expect(find.text('อัปโหลด'), findsOneWidget);
    });

    testWidgets('the banner reads the profile status, not a document status',
        (tester) async {
      final api = _StubApiClient({
        // Every document approved, yet the profile is still PENDING — the two
        // are separate, and only the profile decides whether the store is live.
        '/restaurant/documents': [_approvedLicence],
        '/restaurant/profile': {'verification_status': 'PENDING'},
      });

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.text('รอการตรวจสอบ'), findsOneWidget);
      expect(find.text('ร้านผ่านการยืนยันแล้ว'), findsNothing);
    });

    testWidgets('shows the verified banner once the profile says VERIFIED',
        (tester) async {
      final api = _StubApiClient({
        '/restaurant/documents': [_approvedLicence],
        '/restaurant/profile': {'verification_status': 'VERIFIED'},
      });

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.text('ร้านผ่านการยืนยันแล้ว'), findsOneWidget);
    });
  });

  group('casing contract', () {
    test('document status is lowercase, profile status is uppercase', () {
      // SCRUM-53 §8 calls this out as a trap: two enums, two casings. A shared
      // constant would be wrong here, so pin both.
      expect(DocumentStatus.pending, 'pending');
      expect(DocumentStatus.approved, 'approved');
      expect(DocumentStatus.rejected, 'rejected');

      expect(VerificationStatus.pending, 'PENDING');
      expect(VerificationStatus.verified, 'VERIFIED');
      expect(VerificationStatus.rejected, 'REJECTED');
    });
  });
}
