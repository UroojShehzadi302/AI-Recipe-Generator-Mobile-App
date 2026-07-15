import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for the AI Recipe Generator.
///
/// Poppins-based hierarchy (heading / title / subtitle / body / button /
/// caption). Screens should use these instead of hardcoding font sizes.
///
/// NOTE: Poppins is bundled locally under `assets/fonts/` (weights
/// 400/500/600/700, declared in `pubspec.yaml`) and referenced by the
/// `'Poppins'` family name — no `google_fonts` runtime network fetch, so
/// typography is correct offline and at first paint.
class AppTextStyles {
  AppTextStyles._();

  /// Font family bundled under `assets/fonts/` (see `pubspec.yaml`).
  static const String _fontFamily = 'Poppins';

  /// Large bold headings (e.g. "Welcome Back").
  static const TextStyle heading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Section / app-bar titles.
  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Supporting subtitle text under headings.
  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Default body text.
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Primary button label.
  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: Colors.white,
  );

  /// Small supporting / caption text.
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
