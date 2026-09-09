import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant_app/core/media/image_pick.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';

/// A square "menu photo" field: shows the picked image, the existing hosted
/// image, or a placeholder, and lets the merchant pick a new one from the
/// camera or gallery. Reports the pick to the parent via [onPicked]; the parent
/// uploads it (MediaRepository, category `menu`) on save.
class MenuImageField extends StatefulWidget {
  const MenuImageField({
    super.key,
    this.initialImageUrl,
    required this.onPicked,
    this.enabled = true,
  });

  final String? initialImageUrl;
  final ValueChanged<PickedImage?> onPicked;
  final bool enabled;

  @override
  State<MenuImageField> createState() => _MenuImageFieldState();
}

class _MenuImageFieldState extends State<MenuImageField> {
  PickedImage? _picked;

  Future<void> _choose() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await pickImage(source);
    if (picked == null || !mounted) return;
    setState(() => _picked = picked);
    widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting =
        widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: widget.enabled ? _choose : null,
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          image: _picked != null
              ? DecorationImage(
                  image: MemoryImage(_picked!.bytes), fit: BoxFit.cover)
              : hasExisting
                  ? DecorationImage(
                      image: NetworkImage(widget.initialImageUrl!),
                      fit: BoxFit.cover)
                  : null,
        ),
        child: (_picked == null && !hasExisting)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo,
                      color: Color(0xFF94A3B8), size: 28),
                  const SizedBox(height: 6),
                  Text('เพิ่มรูป',
                      style: AppTypography.caption5
                          .copyWith(color: const Color(0xFF94A3B8))),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
      ),
    );
  }
}
