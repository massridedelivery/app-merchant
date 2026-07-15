// Smoke test: verifies the app boots without throwing.
//
// The default Flutter counter template test was replaced because this app has
// no counter UI. This test wraps the app in a ProviderScope (required, since
// MyApp is a ConsumerWidget) and mocks SharedPreferences so auth initialization
// can run in the test environment.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:merchant_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App boots and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Let async auth initialization settle.
    await tester.pump(const Duration(milliseconds: 100));

    // The app should render without throwing. A MaterialApp is always present,
    // whether the loading spinner or the router is shown.
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
