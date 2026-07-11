import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Header row for Home rails / sections (e.g. "Popular Recipes").
///
/// Shows [title] using [AppTextStyles.title]. When [onSeeAll] is provided a
/// trailing "See all" [TextButton] in the brand primary color is rendered.
class SectionTitle extends StatelessWidget {
  /// Section heading text.
  final String title;

  /// Optional "See all" callback. When null, no trailing action is shown.
  final VoidCallback? onSeeAll;

  const SectionTitle({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
