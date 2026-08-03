import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Header row for Home rails / sections (e.g. "Popular Recipes").
///
/// Shows [title], an optional [subtitle], and an optional trailing "See all"
/// action. The action is an arrow-suffixed text button — a chevron reads as
/// "there is more this way" without competing with the heading.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
  });

  /// Section heading text.
  final String title;

  /// Optional supporting line under the heading.
  final String? subtitle;

  /// Optional "See all" callback. When null, no trailing action is shown.
  final VoidCallback? onSeeAll;

  /// Label for the trailing action.
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceS,
                vertical: AppDimensions.spaceXs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seeAllLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: AppDimensions.iconSm,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
