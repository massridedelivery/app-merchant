import 'package:go_router/go_router.dart';

/// Global handle to the app's [GoRouter], set once in `main.dart` after the
/// router is built. Lets non-widget code (notification taps) navigate.
GoRouter? appRouter;

/// A tab index the main screen should switch to after routing to `/` — set by a
/// notification tap so tapping a new-order push lands on the Orders tab. The
/// main screen consumes and clears it. `null` means no pending switch.
int? pendingTabIndex;

/// The order id carried by the tapped push, kept for the Orders screen to
/// highlight/open once per-order detail exists. Consumed with [pendingTabIndex].
String? pendingOrderId;
