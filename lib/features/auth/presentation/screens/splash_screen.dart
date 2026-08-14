import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';

/// Flips to `true` once the splash has been shown for its minimum duration.
/// The router (see `main.dart`) holds on `/splash` until this is `true`, so the
/// splash always shows for a beat even when auth initializes instantly.
final splashReadyProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    // Gentle breathing scale on the logo tile.
    _scale = Tween<double>(begin: 0.97, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _holdThenContinue();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _holdThenContinue() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Release the router's redirect gate; GoRouter takes it from here.
    ref.read(splashReadyProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.foundationGrayscale75,
      body: Stack(
        children: [
          // Brand-red aura blurs for a soft, premium backdrop.
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.1,
            child: _AuraBlur(color: AppColors.primary, size: size.width * 0.8),
          ),
          Positioned(
            top: size.height * 0.35,
            right: -size.width * 0.2,
            child:
                _AuraBlur(color: AppColors.primaryDark, size: size.width * 0.7),
          ),
          Positioned(
            bottom: -size.height * 0.05,
            left: size.width * 0.1,
            child: _AuraBlur(color: AppColors.primary, size: size.width * 0.6),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App-icon tile: the white MassFood mark on a brand-red tile,
                // gently breathing.
                ScaleTransition(
                  scale: _scale,
                  child: Transform.rotate(
                    angle: -4 * math.pi / 180,
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icon/icon_foreground.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                Text(
                  'Mass Merchant',
                  style: AppTypography.heading1.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Slogan
                Text(
                  'ยกระดับการให้บริการในเมือง',
                  style: AppTypography.label2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.foundationGrayscale700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraBlur extends StatelessWidget {
  final Color color;
  final double size;

  const _AuraBlur({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
