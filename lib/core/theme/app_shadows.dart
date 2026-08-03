import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation / shadow tokens for CookMate AI.
///
/// Soft, low-opacity, tightly-spread shadows are part of the premium brand
/// language — a modern mobile UI reads as "lifted", not "drop-shadowed". Reuse
/// these instead of each widget inventing its own.
class AppShadows {
  AppShadows._();

  /// No elevation. Useful as the "resting" value in an animated shadow.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Barely-there lift for chips, small tiles, and inline surfaces.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0D000000), // ~5% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Default soft shadow for cards and elevated surfaces.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000), // ~8% black
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: -4,
    ),
  ];

  /// Stronger lift for sheets, dialogs, and the floating navigation bar.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1A000000), // ~10% black
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -6,
    ),
  ];

  /// Const brand glow for selected pills/chips.
  ///
  /// A `const` list (rather than [glow]) so a scrolling filter row doesn't
  /// allocate a new shadow on every rebuild.
  static const List<BoxShadow> selectedChip = [
    BoxShadow(
      color: Color(0x3D8B5E3C), // AppColors.primary @ ~24%
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  /// Brown-tinted glow under the primary button / brand accents.
  static List<BoxShadow> get button => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -4,
        ),
      ];

  /// A brand glow, used behind the AI action and other emphasized affordances.
  static List<BoxShadow> glow(Color color, {double alpha = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
      ];
}
