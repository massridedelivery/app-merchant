import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/media/media_repository.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';

/// KYC paperwork (SCRUM-53 §8).
///
/// `POST /documents` takes a `file_key`, never a file, so submitting one is
/// really two calls: the three-step media upload first (category
/// `restaurant_doc`, the only private bucket), then the domain call. Approval
/// happens admin-side and asynchronously, so the list is refetched afterwards
/// rather than patched locally — the server decides the status, not us.
class RestaurantDocumentsNotifier
    extends StateNotifier<AsyncValue<List<RestaurantDocument>>> {
  RestaurantDocumentsNotifier(this._repository, this._media)
      : super(const AsyncValue.loading()) {
    fetchDocuments();
  }

  final RestaurantRepository _repository;
  final MediaRepository _media;

  Future<void> fetchDocuments() async {
    try {
      final documents = await _repository.fetchDocuments();
      if (!mounted) return;
      state = AsyncValue.data(documents);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Uploads [bytes] and files it under [docType].
  ///
  /// Re-submitting a rejected document goes through this same path — the
  /// endpoint takes a new row each time and the reviewer sees the latest.
  Future<void> submitDocument({
    required String docType,
    required Uint8List bytes,
    required String contentType,
    String? docNumber,
  }) async {
    try {
      final fileKey = await _media.upload(
        category: MediaCategory.restaurantDoc,
        contentType: contentType,
        bytes: bytes,
      );
      await _repository.submitDocument(
        docType: docType,
        fileKey: fileKey,
        docNumber: docNumber,
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('ส่งเอกสารไม่สำเร็จ', e);
    }
    await fetchDocuments();
  }

  /// A signed, time-limited URL for a private-bucket file. Returns null when
  /// the document has no key yet.
  Future<String?> viewUrl(RestaurantDocument document) {
    final key = document.fileKey;
    if (key == null || key.isEmpty) return Future.value(null);
    return _media.viewUrl(key);
  }
}

final restaurantDocumentsProvider = StateNotifierProvider<
    RestaurantDocumentsNotifier, AsyncValue<List<RestaurantDocument>>>(
  (ref) {
    // Rebuild on account change so KYC docs never carry over between logins.
    ref.watch(restaurantIdProvider);
    return RestaurantDocumentsNotifier(
      ref.watch(restaurantRepositoryProvider),
      ref.watch(mediaRepositoryProvider),
    );
  },
);

/// The newest document filed under each type.
///
/// The endpoint returns a flat list and re-uploading appends rather than
/// replaces, so a type can appear more than once; the latest `uploaded_at`
/// wins, and entries without one are treated as oldest.
extension LatestByType on List<RestaurantDocument> {
  RestaurantDocument? latestFor(String docType) {
    RestaurantDocument? best;
    for (final doc in this) {
      if (doc.docType != docType) continue;
      if (best == null) {
        best = doc;
        continue;
      }
      final a = doc.uploadedAt;
      final b = best.uploadedAt;
      if (b == null || (a != null && a.isAfter(b))) best = doc;
    }
    return best;
  }
}
