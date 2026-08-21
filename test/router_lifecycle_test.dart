import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:merchant_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Startup is splash → welcome, and the hop between them is driven by
/// `splashReadyProvider` flipping while the splash is on screen.
///
/// That single flip is enough to trip the framework if the router is rebuilt
/// with it: `MaterialApp.router` would be handed a different `routerConfig`,
/// which tears down the `Router` — and its inherited scope — underneath the
/// splash that is still mounted and still depends on it. The framework catches
/// that as `'_dependents.isEmpty': is not true` and paints the red screen.
void main() {
  setUp(() {
    // No session on disk: auth resolves to "signed out" without any network.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('splash hands over to welcome without tearing down the router',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Let auth finish initialising and the splash mount.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);

    // The splash releases the gate after its minimum hold.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the router instance survives a redirect-triggering state change',
      (tester) async {
    late final ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MyApp();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final before = container.read(goRouterProvider);
    container.read(splashReadyProvider.notifier).state = true;
    await tester.pumpAndSettle();
    final after = container.read(goRouterProvider);

    // Rebuilding the router on every navigation-relevant state change is what
    // breaks the tree. `redirect` reads the state itself, so one instance has
    // to outlive every flip.
    expect(identical(before, after), isTrue,
        reason: 'goRouterProvider rebuilt a new GoRouter');

    // Let the splash's own 2s hold elapse; leaving it pending fails the test
    // binding's timer check.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
