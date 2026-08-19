import 'package:go_router/go_router.dart';

/// Global handle to the app's [GoRouter], set once in `main.dart` after the
/// router is built. Lets non-widget code (notification taps) navigate.
GoRouter? appRouter;
