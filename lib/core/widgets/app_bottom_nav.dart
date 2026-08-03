import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// One destination in [AppBottomNav].
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.emphasized = false,
  });

  /// Outline glyph shown when the tab is not selected.
  final IconData icon;

  /// Filled glyph shown when the tab is selected — the weight change is what
  /// makes selection readable at a glance, more than color alone.
  final IconData activeIcon;

  final String label;

  /// Renders this destination as the raised brand action (the AI tab).
  final bool emphasized;
}

/// A floating, frosted bottom navigation bar.
///
/// Design decisions worth keeping:
/// * **Frosted, not opaque.** The bar is translucent over a [BackdropFilter]
///   blur, so content scrolling underneath stays faintly visible. An opaque
///   white slab floating over a scrolling list reads as a rendering bug; a
///   blurred one reads as a deliberate layer.
/// * **A single sliding pill** marks the selection, animated between slots with
///   [AnimatedAlign], instead of each tab fading its own background. One moving
///   element tells the eye where selection *went*.
/// * **The label belongs to the selected tab only.** Unselected tabs are icons;
///   the active one expands to icon + label. That removes four labels' worth of
///   noise and makes the bar work on narrow screens without a size class.
/// * **Emphasized center action** — the AI tab keeps its gradient circle, since
///   it is the app's core feature.
///
/// The bar reports its own height through [AppDimensions.navBarClearance] so
/// scrollable content can pad itself to clear it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onSelect,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final int count = destinations.length;

    // `mainAxisSize.min` is what pins the bar to the bottom: the Scaffold gives
    // `bottomNavigationBar` loose vertical constraints, so a `Center` (or any
    // widget that expands) would take the full height and float the bar up the
    // screen. The Column hugs its child; the Align only centers horizontally,
    // which matters once `maxContentWidth` kicks in on a tablet.
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Container(
                height: AppDimensions.navBarHeight,
                margin: const EdgeInsets.fromLTRB(
                  AppDimensions.spaceL,
                  0,
                  AppDimensions.spaceL,
                  AppDimensions.navBarMargin,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppDimensions.brPill,
                  boxShadow: AppShadows.raised,
                ),
                child: ClipRRect(
                  borderRadius: AppDimensions.brPill,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Translucent so the blur is visible; a hairline border
                        // keeps the edge crisp against a light background.
                        color: AppColors.surface.withValues(alpha: 0.82),
                        borderRadius: AppDimensions.brPill,
                        border: Border.all(
                          color: AppColors.surface.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Stack(
                        children: [
                          _SlidingIndicator(index: index, count: count),
                          Row(
                            children: <Widget>[
                              for (int i = 0; i < count; i++)
                                Expanded(
                                  child: destinations[i].emphasized
                                      ? _EmphasizedItem(
                                          destination: destinations[i],
                                          selected: index == i,
                                          onTap: () => onSelect(i),
                                        )
                                      : _NavItem(
                                          destination: destinations[i],
                                          selected: index == i,
                                          onTap: () => onSelect(i),
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The soft brand pill that slides to sit behind the selected destination.
///
/// Hidden when the emphasized (AI) tab is active — that one has its own raised
/// treatment, and a pill behind it would double up.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    // Maps slot index to an Alignment.x in [-1, 1] so the pill lands centered
    // on its tab regardless of how many destinations there are.
    final double x = count <= 1 ? 0 : (index / (count - 1)) * 2 - 1;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceXs,
          vertical: AppDimensions.spaceS + 2,
        ),
        child: AnimatedAlign(
          alignment: Alignment(x, 0),
          duration: AppDurations.medium,
          curve: AppAnimations.emphasized,
          child: FractionallySizedBox(
            widthFactor: 1 / count,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.9),
                borderRadius: AppDimensions.brPill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A standard destination. Shows its label only while selected, expanding
/// horizontally so the bar stays uncluttered.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.brPill,
        splashColor: AppColors.primary.withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Swapping outline -> filled reads as a real state change.
            AnimatedSwitcher(
              duration: AppDurations.short,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                key: ValueKey<bool>(selected),
                color: color,
                size: 22,
              ),
            ),
            // The label belongs to the active tab only, and grows *downward*
            // rather than sideways — a horizontal expansion has to compete with
            // the icon for a fifth of the bar's width, which overflows on a
            // 320dp screen. Vertical space is free here.
            AnimatedSize(
              duration: AppDurations.medium,
              curve: AppAnimations.standard,
              alignment: Alignment.topCenter,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.space2,
                      ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised center action (AI) — always visually emphasized as the app's
/// core feature, and lifted slightly further when selected.
class _EmphasizedItem extends StatelessWidget {
  const _EmphasizedItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: PressableScale(
        onTap: onTap,
        scale: 0.9,
        child: Center(
          child: AnimatedContainer(
            duration: AppDurations.medium,
            curve: AppAnimations.emphasized,
            width: selected ? 48 : 44,
            height: selected ? 48 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: AppShadows.glow(
                AppColors.primary,
                alpha: selected ? 0.5 : 0.32,
              ),
            ),
            child: Icon(
              selected ? destination.activeIcon : destination.icon,
              color: AppColors.onPrimary,
              size: selected ? 24 : 22,
            ),
          ),
        ),
      ),
    );
  }
}
