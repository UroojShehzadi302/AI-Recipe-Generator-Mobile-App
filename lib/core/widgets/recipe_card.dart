import 'package:flutter/material.dart';

import '../../models/recipe_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_shadows.dart';

/// A premium recipe card for horizontal rails and grids.
///
/// Shows the recipe image (or a warm gradient placeholder when none is
/// available yet), a favorite toggle, the title, and quick stats (time +
/// calories). Fully token-driven so it matches the brand everywhere.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.width = 172,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusLg),
                  ),
                  child: _image(),
                ),
                Positioned(top: 8, right: 8, child: _favoriteButton()),
                if (recipe.category.isNotEmpty)
                  Positioned(left: 8, bottom: 8, child: _categoryTag()),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title.isEmpty ? 'Untitled recipe' : recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // scaleDown keeps the stats on one line in narrow grid cells
                  // (favorites/saved) without overflowing.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${recipe.cookingTimeMinutes} min', style: _stat),
                        const SizedBox(width: 12),
                        const Icon(Icons.local_fire_department_outlined,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text('${recipe.calories} kcal', style: _stat),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _stat =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);

  Widget _image() {
    const double h = 112;
    if (recipe.imageUrl.isNotEmpty) {
      return Image.network(
        recipe.imageUrl,
        height: h,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loading(h);
        },
        errorBuilder: (_, _, _) => _placeholder(h),
      );
    }
    return _placeholder(h);
  }

  Widget _loading(double h) {
    return Container(
      height: h,
      width: double.infinity,
      color: AppColors.primarySoft,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(double h) {
    return Container(
      height: h,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.primary],
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu, color: Colors.white70, size: 34),
      ),
    );
  }

  Widget _favoriteButton() {
    return GestureDetector(
      onTap: onFavorite,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: isFavorite ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }

  Widget _categoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        recipe.category,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
