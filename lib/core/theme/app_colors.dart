import 'package:flutter/material.dart';

/// Central color palette for the AI Recipe Generator.
///
/// Single source of truth for every color in the app. Screens and widgets must
/// reference these tokens instead of hardcoding `Color(0x...)` literals so the
/// warm brown branding stays consistent across the whole application.
class AppColors {
  AppColors._();

  /// Brand primary — warm brown. Used for buttons, accents, active states.
  static const Color primary = Color(0xFF8B5E3C);

  /// Darker brown, used as the end stop of warm brand gradients.
  static const Color primaryDark = Color(0xFF5E3D26);

  /// Soft brown tint for subtle backgrounds (chips, section fills).
  static const Color primarySoft = Color(0xFFEDE3DA);

  /// Softer brown/tan accent for secondary emphasis.
  static const Color secondary = Color(0xFFD6A46D);

  /// App background — brand cream. Standardized across every screen.
  static const Color background = Color(0xFFF6F2EE);

  /// Card / elevated surface color.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text color.
  static const Color textPrimary = Color(0xFF2E2E2E);

  /// Secondary / supporting text color.
  static const Color textSecondary = Color(0xFF7A7A7A);

  /// Neutral border color for inputs and dividers.
  static const Color border = Color(0xFFE0E0E0);

  /// Success state (soft green).
  static const Color success = Color(0xFF66BB6A);

  /// Error state (soft red).
  static const Color error = Color(0xFFE57373);
}
