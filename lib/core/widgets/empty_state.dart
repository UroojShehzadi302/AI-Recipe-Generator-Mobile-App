import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A friendly placeholder for "no data" screens (no favorites, no results).
///
/// The icon sits inside a soft brand-tinted circle rather than floating as a
/// bare glyph — that one change is most of what separates a polished empty
/// state from a default one. The whole block fades in so an empty list doesn't
/// snap into view after a load finishes.
///
/// Scrollable by design: with a keyboard open on a small phone, a centered
/// column of icon + title + message + button would otherwise overflow.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  /// Illustrative icon shown above the title.
  final IconData icon;

  /// Main heading describing the empty state.
  final String title;

  /// Optional supporting explanation.
  final String? message;

  /// Optional action widget (usually a button) shown below the text.
  final Widget? action;

  /// Tightens the spacing for use inside a sheet or a short section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double circle = compact ? 72 : 96;
    final double glyph = compact ? 30 : 40;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceXl,
          vertical: compact ? AppDimensions.spaceL : AppDimensions.spaceXxl,
        ),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: glyph, color: AppColors.primary),
              ),
              SizedBox(
                height: compact ? AppDimensions.spaceM : AppDimensions.spaceXl,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spaceS),
                ConstrainedBox(
                  // Keeps the sentence from stretching into an unreadably wide
                  // single line on a tablet.
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppDimensions.spaceXl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
