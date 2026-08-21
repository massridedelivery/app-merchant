import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';

/// Upload buckets, with the limits the server enforces (SCRUM-53 §13).
enum MediaCategory {
  /// Logo and cover. Public bucket — note: **no webp**.
  restaurant('restaurant', 3 * 1024 * 1024, ['image/jpeg', 'image/png']),

  /// Menu item photos. Public bucket.
  menu('menu', 3 * 1024 * 1024, ['image/jpeg', 'image/png', 'image/webp']),

  /// KYC paperwork. Private bucket — reading one back needs a signed view URL.
  restaurantDoc('restaurant_doc', 5 * 1024 * 1024,
      ['image/jpeg', 'image/png', 'application/pdf']),

  /// Owner or staff avatar. Public bucket.
  avatar('avatar', 2 * 1024 * 1024,
      ['image/jpeg', 'image/png', 'image/webp']);


  const MediaCategory(this.wireName, this.maxBytes, this.allowedContentTypes);

  final String wireName;
  final int maxBytes;
  final List<String> allowedContentTypes;

  bool accepts(String contentType) => allowedContentTypes.contains(contentType);
}

/// Step 1's answer: where to PUT the bytes, and the key to hand to the domain
/// endpoint afterwards.
class UploadTicket {
  const UploadTicket({
    required this.uploadUrl,
    required this.fileKey,
    required this.maxBytes,
    this.expiresAt,
  });

  final String uploadUrl;
  final String fileKey;
  final int maxBytes;
  final DateTime? expiresAt;

  factory UploadTicket.fromJson(Map<String, dynamic> json) {
    return UploadTicket(
      uploadUrl: json['upload_url'] ?? '',
      fileKey: json['file_key'] ?? '',
      maxBytes: json['max_bytes'] ?? 0,
      expiresAt: DateTime.tryParse(json['expires_at'] ?? ''),
    );
  }
}

/// The three-step upload every image in the app goes through (SCRUM-53 §13):
/// ask for a signed URL, PUT the bytes straight at storage, then confirm.
///
/// `file_key` — not a URL — is what the domain endpoints want afterwards:
/// `POST /documents`, `PUT /profile` logo/cover, `POST /menu/items` image.
class MediaRepository {
  MediaRepository(this._api);

  final ApiClient _api;

  /// Signed PUT URLs are short-lived (15 min) and the signature covers the
  /// content type, so the upload must use exactly what was requested here.
  Future<UploadTicket> createUploadUrl({
    required MediaCategory category,
    required String contentType,
  }) async {
    if (!category.accepts(contentType)) {
      throw AppFailure(
          'ไฟล์ชนิด $contentType ใช้กับ ${category.wireName} ไม่ได้');
    }
    final response = await _api.dio.get(
      '/api/media/upload-url',
      queryParameters: {
        'category': category.wireName,
        'content_type': contentType,
      },
    );
    return UploadTicket.fromJson(response.data as Map<String, dynamic>);
  }

  /// Step 2 goes straight to storage: a bare client, no Authorization header
  /// (it would break the signature), and the exact content type from step 1.
  Future<void> uploadBytes({
    required UploadTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (ticket.maxBytes > 0 && bytes.length > ticket.maxBytes) {
      throw AppFailure(
        'ไฟล์ใหญ่เกิน ${(ticket.maxBytes / 1024 / 1024).toStringAsFixed(0)} MB',
      );
    }
    // This step deliberately bypasses ApiClient, which also means it bypasses
    // MockInterceptor: the signed URL points at storage, not at our API, so no
    // mock route can match it and the request would escape to a host that does
    // not exist. Stop here in mock mode — the size check above has already run,
    // which is the only part worth exercising offline.
    if (ApiClient.useMock) return;
    await Dio().put(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  /// Step 3 — the server checks the object actually landed.
  Future<void> confirm(String fileKey) =>
      _api.dio.post('/api/media/confirm', data: {'file_key': fileKey});

  /// Runs all three steps and returns the `file_key` to store.
  Future<String> upload({
    required MediaCategory category,
    required String contentType,
    required Uint8List bytes,
  }) async {
    try {
      final ticket =
          await createUploadUrl(category: category, contentType: contentType);
      await uploadBytes(
          ticket: ticket, bytes: bytes, contentType: contentType);
      await confirm(ticket.fileKey);
      return ticket.fileKey;
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('อัปโหลดไฟล์ไม่สำเร็จ', e);
    }
  }

  /// Private-bucket files (KYC) are not directly linkable — putting the key in
  /// an `<img src>` 404s. This exchanges it for a signed, time-limited URL.
  Future<String?> viewUrl(String fileKey) async {
    final response = await _api.dio
        .get('/api/media/view', queryParameters: {'key': fileKey});
    return (response.data as Map<String, dynamic>)['view_url'] as String?;
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(apiClientProvider)),
);
