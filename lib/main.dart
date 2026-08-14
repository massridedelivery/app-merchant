import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
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
import 'package:merchant_app/core/widgets/mass_loading_m.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final splashReady = ref.watch(splashReadyProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
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
    final authState = ref.watch(authProvider);

    if (authState.isLoading && !authState.isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: MassLoadingM(size: 96))),
      );
    }

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
