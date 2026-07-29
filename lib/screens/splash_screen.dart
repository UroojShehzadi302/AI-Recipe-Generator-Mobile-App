import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_durations.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(AppDurations.splash, _decideNextScreen);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rounded to match the logo artwork's own corner radius, so the
            // asset doesn't read as a square sitting on the cream background.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Image.asset(
                AppAssets.logo,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.restaurant_menu,
                  size: 90,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.spaceL),

            Text(
              AppStrings.appName,
              style: AppTextStyles.heading.copyWith(color: AppColors.primary),
            ),

            const SizedBox(height: AppDimensions.spaceS),

            Text(AppStrings.splashTagline, style: AppTextStyles.body),

            const SizedBox(height: AppDimensions.spaceXxl),

            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
