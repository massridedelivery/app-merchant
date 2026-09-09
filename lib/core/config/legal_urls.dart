import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Org-hosted legal pages. The App Store and Google Play both require these to
/// be publicly reachable AND to contain the real policy/terms content — the
/// store listing must carry the same privacy URL. Keep these in sync with the
/// URLs entered in App Store Connect / Play Console.
class LegalUrls {
  LegalUrls._();

  static const String privacy = 'https://massridedelivery.com/privacy';
  static const String terms = 'https://massridedelivery.com/terms';
  static const String merchantTerms =
      'https://massridedelivery.com/merchant-terms';
}

/// Opens a legal page in the external browser. Falls back to a snackbar if the
/// device has no handler.
Future<void> openLegalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้ในขณะนี้')),
    );
  }
}
