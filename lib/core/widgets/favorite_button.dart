import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';

/// The heart toggle used on recipe cards and the detail header.
///
/// Favoriting is a moment of delight, so the heart doesn't merely change
/// colour — it **pops**: the glyph overshoots past its resting size while a
/// soft ring expands and fades behind it, then it settles as a filled red
/// heart. Un-favoriting just fades back, with no burst; celebrating a removal
/// would be odd.
///
/// The burst is deliberately contained to the button's own bounds (an
/// [OverflowBox] lets the ring bleed slightly past the icon without affecting
/// layout) rather than flashing over the whole screen.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = AppDimensions.iconSm,
    this.padded = true,
  });

  /// Current favorite state — drives the glyph, colour, and whether a tap
  /// plays the celebratory burst.
  final bool isFavorite;

  final VoidCallback? onPressed;

  /// Diameter of the heart glyph.
  final double size;

  /// Wraps the heart in the standard white circular chip used on cards. Set
  /// false to render the bare glyph (e.g. inside an existing circular button).
  final bool padded;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Scale of the heart itself: a quick squash, a big overshoot, then settle.
  late final Animation<double> _pop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0.75)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.75, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.35, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
    ],
  ).animate(_controller);

  /// The ring expands outward and fades as it goes.
  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    // Only celebrate when turning the heart ON. `isFavorite` is still the old
    // value here — the parent flips it via the callback below.
    if (!widget.isFavorite) {
      // Commit to red on THIS frame, before the parent's state round-trip.
      // Waiting for `isFavorite` to come back would pop a grey heart that
      // turns red afterwards; the fill has to lead the animation, not trail
      // it. Cleared in didUpdateWidget once the real state catches up.
      setState(() => _optimisticFavorite = true);
      _controller.forward(from: 0);
    }
    widget.onPressed!.call();
  }

  /// True from the moment of tap until the parent reports the new state.
  ///
  /// Favoriting writes to Firestore, so `isFavorite` can lag by a frame or
  /// more — long enough to see a grey pop if the icon waited for it.
  bool _optimisticFavorite = false;

  /// What the heart should render right now.
  bool get _showFavorite => _optimisticFavorite || widget.isFavorite;

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Real state has caught up (or the write failed and it reverted) — either
    // way stop overriding it.
    if (widget.isFavorite != oldWidget.isFavorite) {
      _optimisticFavorite = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // No cross-fade on the way IN: the icon flips to a filled red heart on the
    // same frame as the tap, so the whole pop is red. Fading outline→filled
    // over 200ms meant the heart was still washed-out at peak scale, which is
    // the "pops colourless, then turns red" problem.
    //
    // Un-favoriting still fades, since there is nothing to celebrate there and
    // an abrupt flip to grey reads as a glitch.
    final Widget glyph = Icon(
      _showFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      key: ValueKey<bool>(_showFavorite),
      size: widget.size,
      color: _showFavorite ? AppColors.error : AppColors.primary,
    );

    final Widget heart = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _pop.value,
        child: child,
      ),
      child: _showFavorite
          ? glyph
          : AnimatedSwitcher(
              duration: AppDurations.short,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: glyph,
            ),
    );

    final Widget content = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // The expanding ring.
        //
        // Wrapped in a zero-size SizedBox so it contributes nothing to layout
        // and simply paints outward from the centre — an OverflowBox here
        // takes an infinite size whenever the button sits in an unbounded
        // parent (a Row/Column), which crashes layout.
        AnimatedBuilder(
          animation: _ring,
          builder: (context, _) {
            if (_ring.value == 0 || _ring.value == 1) {
              return const SizedBox.shrink();
            }
            final double diameter = widget.size * (1 + _ring.value * 1.8);
            return SizedBox(
              width: 0,
              height: 0,
              child: Center(
                child: Opacity(
                  opacity: (1 - _ring.value).clamp(0, 1),
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.55),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        heart,
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.padded
          ? Container(
              padding: const EdgeInsets.all(AppDimensions.spaceXs + 2),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: AppShadows.subtle,
              ),
              child: content,
            )
          : content,
    );
  }
}
