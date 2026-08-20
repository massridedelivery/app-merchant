import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Merchant payout preferences.
///
/// Right now only "auto payout" (Grab-style weekly automatic transfer) is
/// captured, and it is stored **locally** on the device: the merchant's intent
/// is recorded so the UI reflects it, but the actual scheduled transfer has to
/// run server-side. When the backend ships an auto-payout endpoint (SCRUM-60),
/// swap [_persist]/[_read] for a repository call — the rest of the UI stays.
class PayoutSettings {
  const PayoutSettings({this.autoPayout = false});

  /// Transfer the available balance automatically on a weekly cycle.
  final bool autoPayout;

  PayoutSettings copyWith({bool? autoPayout}) =>
      PayoutSettings(autoPayout: autoPayout ?? this.autoPayout);
}

class PayoutSettingsNotifier extends StateNotifier<PayoutSettings> {
  PayoutSettingsNotifier() : super(const PayoutSettings()) {
    _read();
  }

  static const _kAutoPayout = 'payout.auto_enabled';

  Future<void> _read() async {
    final prefs = await SharedPreferences.getInstance();
    state = PayoutSettings(autoPayout: prefs.getBool(_kAutoPayout) ?? false);
  }

  Future<void> setAutoPayout(bool enabled) async {
    state = state.copyWith(autoPayout: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPayout, enabled);
  }
}

final payoutSettingsProvider =
    StateNotifierProvider<PayoutSettingsNotifier, PayoutSettings>(
        (ref) => PayoutSettingsNotifier());
