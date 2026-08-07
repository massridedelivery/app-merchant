/// KYC document types.
///
/// These come from a SQL comment, not a constraint — the column is a free-form
/// VARCHAR(50) (SCRUM-53 §8) — so the list is an agreed convention rather than
/// something the server enforces.
class DocumentType {
  const DocumentType._();

  static const String businessLicense = 'business_license';
  static const String taxId = 'tax_id';
  static const String menuSample = 'menu_sample';

  static const List<String> all = [businessLicense, taxId, menuSample];

  static String label(String type) => switch (type) {
        businessLicense => 'ทะเบียนพาณิชย์',
        taxId => 'เลขประจำตัวผู้เสียภาษี',
        menuSample => 'ตัวอย่างเมนู',
        _ => type,
      };
}

/// Review outcome for one document.
///
/// Casing trap: this is **lowercase**, while the profile's
/// `verification_status` is uppercase. Two enums, two casings (SCRUM-53 §8).
class DocumentStatus {
  const DocumentStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

class RestaurantDocument {
  const RestaurantDocument({
    required this.id,
    required this.docType,
    required this.status,
    this.docNumber,
    this.fileKey,
    this.rejectionReason,
    this.uploadedAt,
    this.verifiedAt,
  });

  final String id;
  final String docType;
  final String status;
  final String? docNumber;

  /// The API calls this `image_url`, but it holds a **file key**, not a URL —
  /// dropping it into an `<img src>` 404s. Exchange it via
  /// `MediaRepository.viewUrl` (SCRUM-53 §8).
  final String? fileKey;

  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? verifiedAt;

  bool get isPending => status == DocumentStatus.pending;
  bool get isApproved => status == DocumentStatus.approved;
  bool get isRejected => status == DocumentStatus.rejected;

  factory RestaurantDocument.fromJson(Map<String, dynamic> json) {
    return RestaurantDocument(
      id: json['id'] ?? '',
      docType: json['doc_type'] ?? '',
      status: json['status'] ?? DocumentStatus.pending,
      docNumber: json['doc_number'],
      fileKey: json['image_url'],
      rejectionReason: json['rejection_reason'],
      uploadedAt: DateTime.tryParse(json['uploaded_at'] ?? ''),
      verifiedAt: DateTime.tryParse(json['verified_at'] ?? ''),
    );
  }
}
