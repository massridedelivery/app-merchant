import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant_app/core/media/media_repository.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

/// A locally-picked image kept until the merchant saves: the raw bytes plus the
/// content type (the media upload's signature covers it, so we can't guess).
class _PickedImage {
  const _PickedImage(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// Full-page store editor (replaces the old dialog). Edits the text fields
/// `PUT /restaurant/profile` accepts plus the logo and cover images (uploaded
/// via MediaRepository, category `restaurant`). Phone / manager / tax id are
/// shown read-only on the details screen — the endpoint doesn't accept them
/// yet (see SCRUM-80).
class EditStoreScreen extends ConsumerStatefulWidget {
  const EditStoreScreen({super.key, required this.profile});

  final RestaurantProfile profile;

  @override
  ConsumerState<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends ConsumerState<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _descController =
      TextEditingController(text: widget.profile.description ?? '');
  late final _cuisineController =
      TextEditingController(text: widget.profile.cuisineType ?? '');
  late final _addressController =
      TextEditingController(text: widget.profile.address ?? '');
  late final _minOrderController = TextEditingController(
    text: widget.profile.minOrderAmount?.toStringAsFixed(0) ?? '',
  );

  _PickedImage? _newLogo;
  _PickedImage? _newCover;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _cuisineController.dispose();
    _addressController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// image_picker doesn't always report a mime type; infer from the extension.
  /// Category `restaurant` accepts only jpeg/png (no webp).
  String? _contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime == 'image/jpeg' || mime == 'image/png') return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  Future<void> _pick(bool isLogo) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    final contentType = _contentTypeFor(file);
    if (contentType == null) {
      _snack('รองรับเฉพาะรูป JPG หรือ PNG', AppColors.error);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      final picked = _PickedImage(bytes, contentType);
      if (isLogo) {
        _newLogo = picked;
      } else {
        _newCover = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final media = ref.read(mediaRepositoryProvider);
      String? logoKey;
      String? coverKey;
      if (_newLogo != null) {
        logoKey = await media.upload(
          category: MediaCategory.restaurant,
          contentType: _newLogo!.contentType,
          bytes: _newLogo!.bytes,
        );
      }
      if (_newCover != null) {
        coverKey = await media.upload(
          category: MediaCategory.restaurant,
          contentType: _newCover!.contentType,
          bytes: _newCover!.bytes,
        );
      }

      await ref.read(restaurantProfileProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            description: _trimmedOrNull(_descController),
            cuisineType: _trimmedOrNull(_cuisineController),
            address: _trimmedOrNull(_addressController),
            minOrderAmount: double.tryParse(_minOrderController.text.trim()),
            logoFileKey: logoKey,
            coverFileKey: coverKey,
          );
      if (!mounted) return;
      _snack('บันทึกข้อมูลร้านแล้ว', AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('เกิดข้อผิดพลาด: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF333333)),
        title: Text(
          'แก้ไขข้อมูลร้าน',
          style: AppTypography.heading5.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _imagesHeader(),
            const SizedBox(height: 8),
            _section([
              _field(
                controller: _nameController,
                label: 'ชื่อร้าน',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'กรุณากรอกชื่อร้าน'
                    : null,
              ),
              _field(controller: _cuisineController, label: 'ประเภทอาหาร'),
              _field(
                  controller: _addressController,
                  label: 'ที่อยู่',
                  maxLines: 2),
              _field(
                  controller: _descController,
                  label: 'คำอธิบายร้าน',
                  maxLines: 3),
              _field(
                controller: _minOrderController,
                label: 'ยอดสั่งซื้อขั้นต่ำ (บาท)',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null) return 'ยอดขั้นต่ำต้องเป็นตัวเลข';
                  if (parsed < 0) return 'ยอดขั้นต่ำต้องไม่ติดลบ';
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('บันทึก',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagesHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Cover
          GestureDetector(
            onTap: () => _pick(false),
            child: Stack(
              children: [
                _coverImage(),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _editBadge('เปลี่ยนรูปหน้าปก'),
                ),
              ],
            ),
          ),
          // Logo, overlapping the cover
          Transform.translate(
            offset: const Offset(0, -40),
            child: GestureDetector(
              onTap: () => _pick(true),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _logoImage(),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Text('แตะรูปเพื่อเปลี่ยน',
                style: AppTypography.caption5
                    .copyWith(color: const Color(0xFF888888))),
          ),
        ],
      ),
    );
  }

  Widget _coverImage() {
    const height = 160.0;
    if (_newCover != null) {
      return Image.memory(_newCover!.bytes,
          width: double.infinity, height: height, fit: BoxFit.cover);
    }
    final url = widget.profile.coverImageUrl;
    if (url != null) {
      return Image.network(url,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _coverPlaceholder(height));
    }
    return _coverPlaceholder(height);
  }

  Widget _coverPlaceholder(double height) => Container(
        width: double.infinity,
        height: height,
        color: const Color(0xFFECEFF3),
        child: const Icon(Icons.image_outlined,
            color: Color(0xFFB0B8C1), size: 40),
      );

  Widget _logoImage() {
    const radius = 44.0;
    if (_newLogo != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(_newLogo!.bytes));
    }
    final url = widget.profile.logoUrl;
    if (url != null) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }
    return const CircleAvatar(
      radius: radius,
      backgroundColor: Color(0xFFECEFF3),
      child: Icon(Icons.storefront, color: Color(0xFFB0B8C1), size: 32),
    );
  }

  Widget _editBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption5.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _section(List<Widget> children) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        style: AppTypography.body1
            .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: !_isSaving,
      ),
    );
  }
}
