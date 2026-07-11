import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale for the AI Recipe Generator.
///
/// Poppins-based hierarchy (heading / title / subtitle / body / button /
/// caption). Screens should use these instead of hardcoding font sizes.
///
/// NOTE: Poppins is currently loaded via `google_fonts` (runtime fetch with a
/// cached fallback). Phase 6 of the refactoring plan bundles the `.ttf` files
/// under `assets/fonts/` to remove the network dependency on first launch —
/// once bundled, these definitions keep working unchanged.
class AppTextStyles {
  AppTextStyles._();

  /// Large bold headings (e.g. "Welcome Back").
  static TextStyle get heading => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  /// Section / app-bar titles.
  static TextStyle get title => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// Supporting subtitle text under headings.
  static TextStyle get subtitle => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Default body text.
  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  /// Primary button label.
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: Colors.white,
      );

  /// Small supporting / caption text.
  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
}
