import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/errors/failure_snack_bar.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_document.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/document_provider.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

/// KYC document upload and review status (SCRUM-53 §8).
///
/// The screen is built around one fact the API makes easy to get wrong: there
/// are **two** verification states with **two** casings. The banner at the top
/// is the profile's uppercase `verification_status` — the only thing that
/// decides whether the restaurant is live. Each card below is a document's
/// lowercase `status`. Every document can be approved and the profile still sit
/// at PENDING, because approval is a separate admin action.
class KycDocumentsScreen extends ConsumerWidget {
  const KycDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(restaurantDocumentsProvider);
    final profileAsync = ref.watch(restaurantProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.semanticGrayNeutralBgWhite,
        elevation: 0,
        title: Text(
          'เอกสารยืนยันตัวตน',
          style: AppTypography.heading5.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(restaurantDocumentsProvider.notifier).fetchDocuments(),
        child: documentsAsync.when(
          loading: () => const Center(child: MassLoadingM(size: 64)),
          error: (_, __) => _RetryBody(
            onRetry: () =>
                ref.read(restaurantDocumentsProvider.notifier).fetchDocuments(),
          ),
          data: (documents) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _VerificationBanner(
                status: profileAsync.valueOrNull?.verificationStatus,
              ),
              const SizedBox(height: 20),
              for (final type in DocumentType.all) ...[
                _DocumentCard(
                  docType: type,
                  document: documents.latestFor(type),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Text(
                'ทีมงานจะตรวจเอกสารภายใน 1–2 วันทำการ '
                'สถานะจะอัปเดตเองเมื่อตรวจเสร็จ',
                style: AppTypography.caption5
                    .copyWith(color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryBody extends StatelessWidget {
  const _RetryBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Inside a RefreshIndicator the child has to stay scrollable, otherwise
    // pull-to-retry stops working on the error state.
    return ListView(
      padding: const EdgeInsets.only(top: 120),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'โหลดเอกสารไม่สำเร็จ',
                style: AppTypography.body2
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
            ],
          ),
        ),
      ],
    );
  }
}

/// The profile-level outcome — uppercase `PENDING | VERIFIED | REJECTED`.
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = switch (status) {
      VerificationStatus.verified => (
          AppColors.success,
          AppIcons.shieldCircleCheckFill,
          'ร้านผ่านการยืนยันแล้ว',
          'ร้านของคุณเปิดรับออเดอร์ได้ตามปกติ',
        ),
      VerificationStatus.rejected => (
          AppColors.error,
          AppIcons.crossXInvalid,
          'การยืนยันไม่ผ่าน',
          'ดูเหตุผลในเอกสารด้านล่าง แล้วอัปโหลดใหม่',
        ),
      _ => (
          AppColors.warning,
          AppIcons.shieldCircleCheckLine,
          'รอการตรวจสอบ',
          'อัปโหลดเอกสารให้ครบเพื่อให้ทีมงานตรวจสอบ',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          AppIcon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label2.copyWith(
                    color: AppColors.semanticGrayNeutralFgHigh,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.caption5
                      .copyWith(color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends ConsumerStatefulWidget {
  const _DocumentCard({required this.docType, required this.document});

  final String docType;
  final RestaurantDocument? document;

  @override
  ConsumerState<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends ConsumerState<_DocumentCard> {
  bool _busy = false;

  /// `menu_sample` is a photo of the menu — there is no number to type.
  bool get _wantsNumber => widget.docType != DocumentType.menuSample;

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final uploaded = document != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppIcon(
                  AppIcons.stackPaperLine,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  DocumentType.label(widget.docType),
                  style: AppTypography.label2.copyWith(
                    color: AppColors.semanticGrayNeutralFgHigh,
                  ),
                ),
              ),
              _StatusChip(status: document?.status),
            ],
          ),
          if (uploaded && (document.docNumber?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Text(
              'เลขที่ ${document.docNumber}',
              style: AppTypography.caption5
                  .copyWith(color: const Color(0xFF64748B)),
            ),
          ],
          if (uploaded && document.isRejected) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                document.rejectionReason?.isNotEmpty == true
                    ? document.rejectionReason!
                    : 'เอกสารไม่ผ่านการตรวจสอบ',
                style: AppTypography.caption5.copyWith(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (uploaded && document.fileKey != null)
                TextButton(
                  onPressed: _busy ? null : _openDocument,
                  child: const Text('ดูเอกสาร'),
                ),
              const Spacer(),
              // An approved document is final — offering "upload again" would
              // invite a merchant to reset a passed check for no reason.
              if (!(uploaded && document.isApproved))
                FilledButton(
                  onPressed: _busy ? null : _pickAndUpload,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(uploaded ? 'อัปโหลดใหม่' : 'อัปโหลด'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument() async {
    final document = widget.document;
    if (document == null) return;
    setState(() => _busy = true);
    final url =
        await ref.read(restaurantDocumentsProvider.notifier).viewUrl(document);
    if (!mounted) return;
    setState(() => _busy = false);
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('เปิดเอกสารไม่ได้'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูปเอกสาร'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    final contentType = _contentTypeFor(file);
    if (contentType == null) {
      _snack('รองรับเฉพาะรูป JPG หรือ PNG');
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > _maxBytes) {
      _snack('ไฟล์ใหญ่เกิน 5 MB');
      return;
    }

    String? docNumber;
    if (_wantsNumber) {
      docNumber = await _askDocNumber();
      if (!mounted) return;
    }

    setState(() => _busy = true);
    await runGuarded(
      context,
      () => ref.read(restaurantDocumentsProvider.notifier).submitDocument(
            docType: widget.docType,
            bytes: bytes,
            contentType: contentType,
            docNumber: docNumber,
          ),
      successMessage: 'ส่งเอกสารเรียบร้อย รอทีมงานตรวจสอบ',
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  /// The number is optional server-side, so an empty answer is submitted as
  /// absent rather than as an empty string.
  Future<String?> _askDocNumber() async {
    final controller =
        TextEditingController(text: widget.document?.docNumber ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เลขที่${DocumentType.label(widget.docType)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'ไม่ระบุก็ได้'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('ข้าม'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// Category `restaurant_doc` also accepts `application/pdf`, but image_picker
  /// cannot return one — picking a PDF needs a file picker dependency the app
  /// does not have yet.
  static const int _maxBytes = 5 * 1024 * 1024;

  String? _contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime == 'image/jpeg' || mime == 'image/png') return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  /// Null means nothing has been filed for this type yet.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      DocumentStatus.approved => (AppColors.success, 'ผ่านแล้ว'),
      DocumentStatus.rejected => (AppColors.error, 'ไม่ผ่าน'),
      DocumentStatus.pending => (AppColors.warning, 'รอตรวจสอบ'),
      _ => (const Color(0xFF94A3B8), 'ยังไม่อัปโหลด'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption5
            .copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
