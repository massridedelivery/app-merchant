import 'package:flutter/material.dart';
import 'package:merchant_app/core/theme/app_colors.dart';

import 'app_failure.dart';

/// Runs [action] and surfaces an [AppFailure] as a SnackBar.
///
/// Exists for the call sites that only fire a mutation and have nothing else to
/// do with the result — a button on a card, a toggle in a sheet. Screens that
/// need to close themselves or reset a form should catch [AppFailure]
/// themselves instead.
///
/// Returns true when [action] completed without an [AppFailure].
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (context.mounted && successMessage != null) {
      _show(context, successMessage, AppColors.success);
    }
    return true;
  } on AppFailure catch (failure) {
    if (context.mounted) _show(context, failure.message, AppColors.error);
    return false;
  }
}

void _show(BuildContext context, String message, Color background) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: background),
  );
}
