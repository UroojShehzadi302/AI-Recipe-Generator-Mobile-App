import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_durations.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

/// Branded launch screen for CookMate AI.
///
/// The logo scales and fades in, then the wordmark and tagline follow, while
/// the session is restored in the background. Motion is deliberately short —
/// the splash is a brand moment, not a loading screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.long,
  );

  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.85,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _controller, curve: AppAnimations.emphasized),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppAnimations.enter,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Timer(AppDurations.splash, _decideNextScreen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Routes to Home when a session already exists, otherwise to Login.
  Future<void> _decideNextScreen() async {
    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.restoreSession();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      hasSession ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spaceXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: AppDimensions.brXl,
                        boxShadow: AppShadows.glow(AppColors.primary,
                            alpha: 0.22),
                      ),
                      // Rounded to match the logo artwork's own corner radius,
                      // so the asset doesn't read as a square on the cream
                      // background.
                      child: ClipRRect(
                        borderRadius: AppDimensions.brXl,
                        child: Image.asset(
                          AppAssets.logo,
                          height: 112,
                          width: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 112,
                            width: 112,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                            ),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 56,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceXl),

                FadeSlideIn(
                  delay: AppDurations.short,
                  child: Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceS),

                FadeSlideIn(
                  delay: AppDurations.medium,
                  child: Text(
                    AppStrings.tagline,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceHuge),

                FadeTransition(
                  opacity: _fade,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
