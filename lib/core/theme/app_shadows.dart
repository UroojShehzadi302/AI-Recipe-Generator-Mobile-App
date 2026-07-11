import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation / shadow tokens for the AI Recipe Generator.
///
/// Soft shadows are part of the premium brand language. Reusing these keeps
/// cards and buttons visually consistent instead of each widget inventing its
/// own shadow.
class AppShadows {
  AppShadows._();

  /// Soft neutral shadow for cards and elevated surfaces.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1F000000), // ~black12
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Brown-tinted shadow used under the primary button.
  static List<BoxShadow> get button => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}
