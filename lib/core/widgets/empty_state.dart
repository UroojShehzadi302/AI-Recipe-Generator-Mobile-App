import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A friendly placeholder for "no data" screens (no favorites, no results).
///
/// Renders a large accent icon, a title, an optional message, and an optional
/// action button (e.g. a "Browse recipes" call to action).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  /// Illustrative icon shown above the title.
  final IconData icon;

  /// Main heading describing the empty state.
  final String title;

  /// Optional supporting explanation.
  final String? message;

  /// Optional action widget (usually a button) shown below the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: AppColors.secondary,
            ),
            const SizedBox(height: AppDimensions.spaceL),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spaceS),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimensions.spaceXl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
