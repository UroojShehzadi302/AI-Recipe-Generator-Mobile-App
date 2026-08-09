import 'package:flutter/material.dart';

import '../../models/recipe_model.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_image_cache.dart';
import 'favorite_button.dart';

/// A premium recipe card for horizontal rails and grids.
///
/// Shows the recipe image (or a warm gradient placeholder when none is
/// available), a favorite toggle, the title, and quick stats (time + calories).
/// Fully token-driven so it matches the brand everywhere.
///
/// Layout notes that matter for correctness:
/// * The image is wrapped in an [AspectRatio] rather than a fixed height, so
///   the card scales properly on tablets where the grid cell is wider.
/// * The text block is [Flexible], and the title is capped at two lines, so a
///   long recipe name can't overflow a narrow grid cell.
/// * A [Hero] can wrap the image (see [heroEnabled]) so opening a matching
///   destination animates the photo into place. The tag is keyed on the recipe
///   identity plus [heroPrefix] — see [_heroTag].
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.width = 168,
    this.heroPrefix,
    this.heroEnabled = false,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final double width;

  /// Disambiguates the [Hero] tag when the same recipe appears in more than
  /// one list on screen (e.g. two Home rails). Without it Flutter throws on
  /// duplicate tags.
  final String? heroPrefix;

  /// Wraps the image in a [Hero] so it flies into the detail screen's header.
  ///
  /// Off by default: a hero with no matching destination costs work for no
  /// animation. Turn it on only when the destination also renders a [Hero]
  /// with the same tag — pass [heroTagFor] to `RecipeDetailScreen.heroTag`.
  final bool heroEnabled;

  /// Stable per-recipe hero tag, shared by the card and the detail screen.
  ///
  /// Both ends MUST derive the tag the same way or the flight silently does
  /// nothing, so this is the one public definition — never hand-build the
  /// string at a call site. Falls back to the title when the recipe has no id
  /// (AI-generated recipes before they are saved).
  static String heroTagFor(Recipe recipe, {String? prefix}) {
    final String id = (recipe.recipeId?.trim().isNotEmpty ?? false)
        ? recipe.recipeId!.trim()
        : recipe.title;
    return 'recipe-image-${prefix ?? ''}$id';
  }

  String get _heroTag => heroTagFor(recipe, prefix: heroPrefix);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      // Tapping a card navigates, so let the press-and-pop finish first —
      // otherwise the route push swallows the animation and the tap feels
      // like nothing happened.
      confirmBeforeTap: true,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDimensions.brLg,
          // A hairline warm border stops the white card from dissolving into
          // the cream background — without it the cards read as floating text.
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppShadows.card,
        ),
        // Clip so the image corners follow the card's radius exactly.
        child: ClipRRect(
          borderRadius: AppDimensions.brLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The image yields height first: the title + stats block has a
              // fixed intrinsic height, so in a cell shorter than the card's
              // natural size the photo shrinks rather than the text clipping.
              Flexible(
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    if (heroEnabled)
                      Hero(
                        tag: _heroTag,
                        // A plain image during the flight avoids the card's
                        // shadow/clip animating oddly mid-transition.
                        flightShuttleBuilder: (_, _, _, _, _) => _image(),
                        child: _image(),
                      )
                    else
                      _image(),
                    // Always scrimmed, not just when a category tag is shown:
                    // it seats the photo into the card and keeps any overlay
                    // legible against a bright image.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: AppColors.imageScrim,
                          ),
                        ),
                      ),
                    ),
                    if (onFavorite != null)
                      Positioned(
                        top: AppDimensions.spaceS,
                        right: AppDimensions.spaceS,
                        child: _favoriteButton(),
                      ),
                    if (recipe.category.isNotEmpty)
                      Positioned(
                        left: AppDimensions.spaceS,
                        bottom: AppDimensions.spaceS,
                        child: _categoryTag(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title.isEmpty ? 'Untitled recipe' : recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceS),
                    // scaleDown keeps the stats on one line in narrow grid
                    // cells (favorites/saved) without overflowing.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(children: _statChildren()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final TextStyle _stat = AppTextStyles.label.copyWith(
    color: AppColors.textSecondary,
  );

  /// Builds the quick-stats row, showing only the values that actually exist.
  ///
  /// TheMealDB recipes carry no cooking time or calories, so we hide those
  /// fields rather than render a fake "0 min" / "0 kcal". When neither stat is
  /// available the row would be empty, so we fall back to the difficulty (or a
  /// "View recipe" nudge) so the card never looks unfinished.
  ///
  /// Each stat is a tinted pill rather than bare text — at 11px, loose
  /// icon+label pairs read as debug output; a chip reads as a designed value.
  List<Widget> _statChildren() {
    final List<Widget> children = <Widget>[];

    if (recipe.hasCookingTime) {
      children.add(_statChip(
        Icons.schedule_rounded,
        '${recipe.cookingTimeMinutes} min',
        AppColors.primary,
      ));
    }

    if (recipe.hasCalories) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: AppDimensions.spaceXs + 2));
      }
      children.add(_statChip(
        Icons.local_fire_department_rounded,
        '${recipe.calories} kcal',
        AppColors.secondary,
      ));
    }

    if (children.isEmpty) {
      final bool hasDifficulty = recipe.difficulty.isNotEmpty;
      children.add(_statChip(
        hasDifficulty
            ? Icons.trending_up_rounded
            : Icons.arrow_forward_rounded,
        hasDifficulty ? recipe.difficulty : 'View recipe',
        AppColors.primary,
      ));
    }

    return children;
  }

  /// One tinted stat pill.
  Widget _statChip(IconData icon, String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceS,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: AppDimensions.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tint),
          const SizedBox(width: AppDimensions.spaceXs),
          Text(
            label,
            style: _stat.copyWith(color: tint, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    if (recipe.imageUrl.isEmpty) {
      return AspectRatio(aspectRatio: _imageAspect, child: _placeholder());
    }

    // LayoutBuilder gives the ACTUAL painted width. Deriving the decode size
    // from the `width` field instead would blow up in a grid, where callers
    // pass `double.infinity` and `(infinity * 2).round()` throws
    // "Unsupported operation: Infinity or NaN toInt".
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final double logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width.isFinite
                ? width
                : 0;

        // Decode at roughly the displayed size instead of full resolution —
        // TheMealDB serves large JPEGs and a grid of full-size decodes is the
        // main memory cost on these screens. Zero/!finite means "unconstrained",
        // where we let Flutter decode natively rather than guess.
        final int? cacheWidth =
            logicalWidth > 0 ? (logicalWidth * dpr).round() : null;

        return AspectRatio(
          aspectRatio: _imageAspect,
          // Image (not Image.network) so the bytes come from the disk-backed
          // provider: Flutter's NetworkImage keeps nothing on disk, so every
          // photo re-downloaded on each cold launch. ResizeImage reproduces
          // exactly what `Image.network(cacheWidth:)` does internally — see the
          // infinity warning above; `cacheWidth` is still the LayoutBuilder
          // value and is still null when the width is unconstrained.
          child: Image(
            image: cachedNetworkImage(recipe.imageUrl, cacheWidth: cacheWidth),
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _loading();
            },
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        );
      },
    );
  }

  /// Image aspect ratio, shared by the photo and its placeholder so the card
  /// keeps one height whether or not an image loads.
  static const double _imageAspect = 16 / 11;

  Widget _loading() {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.placeholderGradient),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: Color(0xB3FFFFFF), // white @ 70%
          size: 30,
        ),
      ),
    );
  }

  Widget _favoriteButton() {
    return FavoriteButton(
      isFavorite: isFavorite,
      onPressed: onFavorite,
    );
  }

  Widget _categoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceS,
        vertical: AppDimensions.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.scrim,
        borderRadius: AppDimensions.brPill,
      ),
      child: Text(
        recipe.category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
