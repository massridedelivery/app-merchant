import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/network/api_logger.dart';

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

  /// Step 2 cannot go through [ApiClient] — an Authorization header breaks the
  /// presigned signature — but it is also the step most likely to fail, so it
  /// gets the logger on its own. Bodies are off: these are raw image bytes.
  late final Dio _storage = Dio()
    ..interceptors.add(ApiLogInterceptor(logBodies: false));

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
      throw AppFailure('ไฟล์ใหญ่เกิน ${_mb(ticket.maxBytes)} MB');
    }
    // This step deliberately bypasses ApiClient, which also means it bypasses
    // MockInterceptor: the signed URL points at storage, not at our API, so no
    // mock route can match it and the request would escape to a host that does
    // not exist. Stop here in mock mode — the size check above has already run,
    // which is the only part worth exercising offline.
    if (ApiClient.useMock) return;
    await _storage.put(
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

  /// Runs all three steps and returns the `file_key` to store (SCRUM-54).
  ///
  /// The returned value is the **bare key**, and it is what every image field
  /// must be given — `logo_url`, `cover_image_url`, a menu item's `image_url`,
  /// a document's `file_key`. The backend now rejects anything else with a
  /// `400`, and a stored URL also makes the nightly orphan sweep delete the
  /// live object it points at, because that job matches on exact key equality.
  Future<String> upload({
    required MediaCategory category,
    required String contentType,
    required Uint8List bytes,
  }) async {
    // Fail before the round trip: the server would reject an oversized file at
    // step 3 anyway, and asking for a URL we cannot use wastes the merchant's
    // data as well as their time.
    if (bytes.lengthInBytes > category.maxBytes) {
      throw AppFailure(
        'ไฟล์ใหญ่เกิน ${_mb(category.maxBytes)} MB',
      );
    }
    try {
      final ticket =
          await createUploadUrl(category: category, contentType: contentType);
      await uploadBytes(
          ticket: ticket, bytes: bytes, contentType: contentType);
      await confirm(ticket.fileKey);
      return ticket.fileKey;
    } on AppFailure {
      rethrow;
    } on DioException catch (e) {
      throw AppFailure(_uploadError(e), e);
    } catch (e) {
      throw AppFailure('อัปโหลดไฟล์ไม่สำเร็จ', e);
    }
  }

  /// The two failures worth naming: a signed URL that sat unused for more than
  /// its 15 minutes, and a key the server would not accept at confirm time.
  /// Everything else stays generic.
  String _uploadError(DioException e) {
    // No response at all: nothing was reached. Reads identically to a rejection
    // in the UI unless it is named, and the fix is completely different.
    if (e.response == null) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'อัปโหลดนานเกินไป กรุณาลองใหม่ (ไฟล์อาจใหญ่หรือเน็ตช้า)',
        _ => 'เชื่อมต่อที่เก็บไฟล์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
      };
    }
    final status = e.response!.statusCode;
    if (status == 403 || status == 401) {
      return 'ลิงก์อัปโหลดหมดอายุ กรุณาเลือกไฟล์ใหม่อีกครั้ง';
    }
    if (status == 404) {
      return 'เซิร์ฟเวอร์ไม่มีบริการอัปโหลดไฟล์ (404) แจ้งทีมหลังบ้าน';
    }
    if (status == 413) {
      return 'ไฟล์ใหญ่เกินที่เซิร์ฟเวอร์รับได้';
    }
    if (status == 400 || status == 422) {
      final data = e.response!.data;
      final message =
          data is Map ? (data['error'] ?? data['message'])?.toString() : null;
      return message?.isNotEmpty == true
          ? message!
          : 'เซิร์ฟเวอร์ไม่รับไฟล์นี้ กรุณาลองไฟล์อื่น';
    }
    return 'อัปโหลดไฟล์ไม่สำเร็จ (HTTP $status)';
  }

  static String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(0);

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
