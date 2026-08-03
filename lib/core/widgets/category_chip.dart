import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A selectable pill used for filter rows (For You / Recipes / …).
///
/// Selected: filled with the brand gradient and lifted by a soft glow.
/// Unselected: white surface with a hairline border. Both the color and the
/// label weight animate, so selection reads as a state change rather than a
/// repaint.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional leading glyph.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        selected ? AppColors.onPrimary : AppColors.textSecondary;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.short,
        curve: AppAnimations.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceL,
          vertical: AppDimensions.spaceS + 2,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppDimensions.brPill,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
          boxShadow: selected ? AppShadows.selectedChip : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...<Widget>[
              Icon(icon, size: AppDimensions.iconSm, color: foreground),
              const SizedBox(width: AppDimensions.spaceXs + 2),
            ],
            AnimatedDefaultTextStyle(
              duration: AppDurations.short,
              curve: AppAnimations.standard,
              style: AppTextStyles.caption.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
