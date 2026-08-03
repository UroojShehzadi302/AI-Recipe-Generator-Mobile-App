import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/recipe_model.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A branded "opening this recipe" overlay.
///
/// Shown while a tapped card is resolved to full detail (rail and category
/// cards are partial and need a network round-trip). It replaces an anonymous
/// centered spinner with something that answers *what* is loading: the recipe's
/// own photo and title, under an animated brand ring.
///
/// Why this matters: the wait is the same length either way, but a blank scrim
/// makes the app feel stalled, whereas showing the thing you just tapped makes
/// it feel like it already started. The card image is usually already in the
/// image cache, so it paints instantly.
///
/// The overlay absorbs input (via [ModalBarrier]) so the list underneath can't
/// be tapped again mid-resolve.
class RecipeOpeningOverlay extends StatelessWidget {
  const RecipeOpeningOverlay({super.key, required this.recipe});

  /// The recipe being opened — supplies the preview image and title.
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            color: AppColors.textPrimary.withValues(alpha: 0.45),
            dismissible: false,
          ),
          Center(
            child: FadeSlideIn(
              duration: AppDurations.short,
              offset: 12,
              child: Container(
                margin: const EdgeInsets.all(AppDimensions.spaceXxl),
                padding: const EdgeInsets.all(AppDimensions.spaceXl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppDimensions.brXl,
                  boxShadow: AppShadows.raised,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingThumbnail(imageUrl: recipe.imageUrl),
                    const SizedBox(height: AppDimensions.spaceL),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        recipe.title.isEmpty
                            ? 'Opening recipe'
                            : recipe.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXs),
                    Text(
                      'Getting the recipe ready…',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recipe thumbnail inside a rotating brand arc, with a soft pulse.
///
/// One [AnimationController] drives both the rotation and the pulse — a second
/// controller here would be pure overhead for an overlay that typically lives
/// well under a second.
class _PulsingThumbnail extends StatefulWidget {
  const _PulsingThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  State<_PulsingThumbnail> createState() => _PulsingThumbnailState();
}

class _PulsingThumbnailState extends State<_PulsingThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const double _size = 88;
  static const double _ring = _size + 18;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ring,
      height: _ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The sweeping brand arc.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(_ring, _ring),
                painter: _ArcPainter(),
              ),
            ),
          ),
          // The recipe image, breathing gently.
          ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.04).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Curves.easeInOut,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: _size,
                height: _size,
                child: widget.imageUrl.isEmpty
                    ? _placeholder()
                    : Image.network(
                        widget.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: (_size * 3).round(),
                        errorBuilder: (_, _, _) => _placeholder(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.placeholderGradient),
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: AppColors.onPrimary,
          size: 30,
        ),
      );
}

/// Paints a partial ring in the brand gradient — the rotating "loading" arc.
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      // A sweep gradient makes the arc fade out along its tail, which reads as
      // motion even in a single frame.
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0x008B5E3C),
          AppColors.secondary,
          AppColors.primary,
        ],
        stops: <double>[0, 0.6, 1],
      ).createShader(rect);

    // Three-quarters of a turn, leaving a gap so the rotation is visible.
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => false;
}
