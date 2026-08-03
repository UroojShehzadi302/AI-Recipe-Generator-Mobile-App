import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// The highlighted "Cook smarter with AI" card on the Home screen.
///
/// This is the app's hero surface — the one element on Home that should stop
/// the eye — so it is deliberately the richest thing on the screen:
///
/// * a three-stop warm gradient on a diagonal, rather than a flat two-stop
///   wash, so the panel has a light source;
/// * two soft translucent "orbs" bleeding off the edges, which give the card
///   depth and stop the large brown area from reading as a plain rectangle;
/// * a glow shadow tinted with the brand color instead of neutral black.
///
/// Everything is painted with tokens — no external accent colors — and the
/// whole card responds to touch via [PressableScale].
class AiAssistantCard extends StatelessWidget {
  const AiAssistantCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppDimensions.brXl,
          boxShadow: AppShadows.glow(AppColors.primary, alpha: 0.38),
        ),
        // Clipped so the decorative orbs can overflow the card's bounds and be
        // cut cleanly by its corner radius.
        child: ClipRRect(
          borderRadius: AppDimensions.brXl,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF9C6B44), // lifted highlight edge
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
                stops: <double>[0, 0.45, 1],
              ),
            ),
            child: Stack(
              children: [
                // Decorative depth. Non-interactive and purely visual.
                Positioned(
                  right: -28,
                  top: -34,
                  child: _orb(96, 0.13),
                ),
                Positioned(
                  right: 34,
                  bottom: -40,
                  child: _orb(76, 0.09),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spaceXl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cook smarter with AI',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceXs + 2),
                            Text(
                              'Generate a recipe from your ingredients or a '
                              'prompt.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onPrimary
                                    .withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceL),
                            _cta(),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceM),
                      _sparkleBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A soft translucent circle used to add depth behind the content.
  Widget _orb(double size, double alpha) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onPrimary.withValues(alpha: alpha),
        ),
      ),
    );
  }

  Widget _cta() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceL,
        vertical: AppDimensions.spaceS + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimensions.brPill,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Get started',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceXs + 2),
          const Icon(
            Icons.arrow_forward_rounded,
            size: AppDimensions.iconSm,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// The sparkle emblem — a translucent disc with a brighter inner ring, so it
  /// reads as a lit object rather than a flat icon on a flat circle.
  Widget _sparkleBadge() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.onPrimary.withValues(alpha: 0.16),
        border: Border.all(
          color: AppColors.onPrimary.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.onPrimary.withValues(alpha: 0.16),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: AppColors.onPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
