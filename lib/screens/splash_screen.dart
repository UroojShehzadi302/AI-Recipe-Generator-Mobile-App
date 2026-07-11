import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_durations.dart';
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
            const Icon(
              Icons.restaurant_menu,
              size: 90,
              color: AppColors.primary,
            ),

            const SizedBox(height: 20),

            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              AppStrings.splashTagline,
              style: TextStyle(fontSize: 17, color: Colors.black54),
            ),

            const SizedBox(height: 40),

            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
