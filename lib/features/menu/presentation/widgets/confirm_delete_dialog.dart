import 'package:flutter/material.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';

/// Asks before a delete that cannot be undone. Resolves to true only when the
/// merchant taps the destructive action.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'ลบ',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      title: Text(
        title,
        style: AppTypography.heading6
            .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
      ),
      content: Text(
        message,
        style: AppTypography.body2
            .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'ยกเลิก',
            style: AppTypography.label2
                .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.semanticErrorFgHigh,
            foregroundColor: Colors.white,
          ),
          child: Text(
            confirmLabel,
            style: AppTypography.label2.copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
