import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/notifications/push_notification_service.dart';
import 'package:merchant_app/core/notifications/push_token_registrar.dart';
import 'package:merchant_app/core/router/app_router_holder.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/firebase_options.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_bank_info_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_business_info_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_business_type_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_confirmation_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_email_password_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_register_otp_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_login_otp_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_personal_info_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/auth_phone_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:merchant_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/home/presentation/screens/main_screen.dart';

/// True once Firebase initialised. Guards FCM token registration so a build
/// without Firebase config simply runs without push (never crashes).
bool _firebaseReady = false;
bool _initialPushChecked = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase options come from --dart-define (see firebase_options.dart). A
  // build without those defines leaves every field empty; on iOS native FIRApp
  // configuration would then abort with an uncatchable Obj-C exception, so skip
  // init entirely when the required fields are absent — the app runs without
  // push. Guarded so a Firebase failure can never block startup.
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.appId.isNotEmpty && options.projectId.isNotEmpty) {
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance.init();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('main: Firebase init failed: $e');
    }
  } else {
    debugPrint('main: Firebase options empty (no --dart-define) — push off');
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Turns the Riverpod state the redirect depends on into the single
/// `Listenable` go_router understands, so a state change re-runs `redirect`
/// on the router that already exists.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(splashReadyProvider, (_, __) => notifyListeners());
  }
}

/// Built once and kept for the life of the app.
///
/// This provider must not `watch` anything: watching would hand
/// `MaterialApp.router` a different `routerConfig` every time auth or the
/// splash gate changed, which tears down the `Router` — and the inherited
/// scope every routed page depends on — while those pages are still mounted.
/// The framework catches that as `'_dependents.isEmpty': is not true` and
/// paints the red screen. `refreshListenable` + `ref.read` inside `redirect`
/// gets the same behaviour from one long-lived instance.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read, never watch — see the note on the provider.
      final authState = ref.read(authProvider);
      final splashReady = ref.read(splashReadyProvider);

      // Hold on the splash until auth has initialized AND the splash has been
      // shown for its minimum duration (splashReadyProvider), so it never
      // flashes past when init is fast.
      if (authState.isLoading || !splashReady) return null;

      final isAuth = authState.isAuthenticated;
      final isSplash = state.matchedLocation == '/splash';
      
      // If we are on splash screen, we must redirect once loading is done
      if (isSplash) {
        return isAuth ? '/' : '/welcome';
      }

      final authRoutes = [
        '/welcome',
        '/login/phone',
        '/login/email',
        '/login/otp',
        '/forgot-password',
        '/register/phone',
        '/register/otp',
        '/register/email_password',
        '/register/business_info',
        '/register/business_type',
        '/register/personal_info',
        '/register/bank_info',
        '/register/confirmation',
      ];
      final isAuthRoute = authRoutes.contains(state.matchedLocation);

      if (!isAuth && !isAuthRoute) return '/welcome';
      if (isAuth && isAuthRoute) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login/phone',
        builder: (context, state) => const AuthPhoneScreen(flow: 'login'),
      ),
      GoRoute(
        path: '/login/email',
        builder: (context, state) => const AuthEmailPasswordScreen(flow: 'login'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register/phone',
        builder: (context, state) => const AuthPhoneScreen(flow: 'register'),
      ),
      GoRoute(
        path: '/login/otp',
        builder: (context, state) => const AuthLoginOtpScreen(),
      ),
      GoRoute(
        path: '/register/otp',
        builder: (context, state) => const AuthRegisterOtpScreen(),
      ),
      GoRoute(
        path: '/register/email_password',
        builder: (context, state) => const AuthEmailPasswordScreen(flow: 'register'),
      ),
      GoRoute(
        path: '/register/business_info',
        builder: (context, state) => const AuthBusinessInfoScreen(),
      ),
      GoRoute(
        path: '/register/business_type',
        builder: (context, state) => const AuthBusinessTypeScreen(),
      ),
      GoRoute(
        path: '/register/personal_info',
        builder: (context, state) => const AuthPersonalInfoScreen(),
      ),
      GoRoute(
        path: '/register/bank_info',
        builder: (context, state) => const AuthBankInfoScreen(),
      ),
      GoRoute(
        path: '/register/confirmation',
        builder: (context, state) => const AuthConfirmationScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // Only the flag the FCM block below needs. Watching the whole AuthState
    // would rebuild this widget on every field change for no benefit.
    final isAuthenticated =
        ref.watch(authProvider.select((s) => s.isAuthenticated));

    // Let notification taps navigate.
    appRouter = router;

    // Mirror the FCM device token onto the backend for whoever is signed in.
    // No-op unless Firebase is configured (see main). ref.listen catches
    // login/logout transitions; the block below covers a cold start that is
    // already authenticated (no transition fires).
    if (_firebaseReady) {
      ref.listen<bool>(authProvider.select((s) => s.isAuthenticated),
          (prev, next) {
        final registrar = ref.read(pushTokenRegistrarProvider);
        next ? registrar.onAuthenticated() : registrar.onLoggedOut();
      });
      if (!_initialPushChecked && isAuthenticated) {
        _initialPushChecked = true;
        final registrar = ref.read(pushTokenRegistrarProvider);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => registrar.onAuthenticated());
      }
    }

    // No separate loading MaterialApp: swapping a home-based app for a
    // router-based one replaces the Navigator with a Router mid-flight, the
    // same teardown the provider note above describes. The router already
    // holds on `/splash` while auth is loading, which covers the same beat.
    return MaterialApp.router(
      title: 'Mass Merchant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      // Global "tap empty space to dismiss the keyboard". Wrapping every routed
      // page here means individual screens don't each need their own handler.
      // translucent → taps on blank areas dismiss; taps on fields/buttons still
      // reach them (they win the gesture arena).
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Unfocus whatever field is active (no-op when nothing is focused),
          // which drops the keyboard.
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
