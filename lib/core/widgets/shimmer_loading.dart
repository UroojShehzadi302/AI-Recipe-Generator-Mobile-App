import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// A lightweight, dependency-free shimmer effect.
///
/// Sweeps a soft highlight across its [child] to signal loading. Wrap a whole
/// skeleton layout (built from [ShimmerBox] / [RecipeCardSkeleton]) in a single
/// [Shimmer] so one [AnimationController] drives the entire placeholder — far
/// cheaper than animating every box. Uses a [ShaderMask], so it tints whatever
/// opaque shapes the child paints; keep skeleton shapes on the brand
/// `primarySoft` fill for the intended warm shimmer.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final double t = _controller.value;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                AppColors.primarySoft,
                AppColors.surface,
                AppColors.primarySoft,
              ],
              stops: <double>[
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single skeleton shape (a soft, rounded block) used to build placeholders.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppDimensions.radiusSm,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A placeholder shaped like a [RecipeCard] (image block + title + stat line).
///
/// Not wrapped in [Shimmer] itself — place several inside one [Shimmer] (see
/// [RecipeRailSkeleton] / [RecipeGridSkeleton]) so they sweep together.
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key, this.width = double.infinity});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusLg),
            ),
            child: ShimmerBox(height: 112, width: double.infinity, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShimmerBox(height: 12, width: 120),
                SizedBox(height: 10),
                ShimmerBox(height: 10, width: 78),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shimmering horizontal rail of [RecipeCardSkeleton]s for Home rails.
class RecipeRailSkeleton extends StatelessWidget {
  const RecipeRailSkeleton({
    super.key,
    required this.height,
    required this.cardWidth,
    this.count = 4,
  });

  final double height;
  final double cardWidth;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, _) => RecipeCardSkeleton(width: cardWidth),
        ),
      ),
    );
  }
}

/// A shimmering grid of [RecipeCardSkeleton]s for full-screen loading states
/// (Search, Categories). [columns] should match the real grid's column count.
class RecipeGridSkeleton extends StatelessWidget {
  const RecipeGridSkeleton({
    super.key,
    required this.columns,
    this.count = 6,
  });

  final int columns;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.74,
        ),
        itemCount: count,
        itemBuilder: (_, _) => const RecipeCardSkeleton(),
      ),
    );
  }
}
