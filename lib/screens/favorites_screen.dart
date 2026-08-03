import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/recipe_card.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_screen.dart';

/// Favorites tab — recipes the user has bookmarked.
///
/// Loads from Firestore (`users/{uid}/favorites`) via [RecipeProvider]. Shows a
/// branded empty state when there are none.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<RecipeProvider>().loadFavorites(uid);
    }
  }

  /// Namespaces this screen's hero tags. The same recipe can be on screen in
  /// another list elsewhere in the app, and duplicate tags throw.
  static const String _heroPrefix = 'fav-';

  /// Opens [recipe], handing the detail screen the matching hero tag so the
  /// card's photo flies into its header.
  void _open(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          heroTag: RecipeCard.heroTagFor(recipe, prefix: _heroPrefix),
        ),
      ),
    );
  }

  Future<void> _unfavorite(Recipe recipe) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<RecipeProvider>().favorites;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  AppDimensions.spaceL,
                  context.pagePadding,
                  AppDimensions.spaceL,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.tabFavorites,
                        style: AppTextStyles.screenTitle,
                      ),
                    ),
                    if (favorites.isNotEmpty)
                      Text(
                        '${favorites.length} '
                        '${favorites.length == 1 ? "recipe" : "recipes"}',
                        style: AppTextStyles.label,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: favorites.isEmpty
                    ? const EmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No favorites yet',
                        message:
                            'Tap the heart on any recipe to save it here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(),
                        color: AppColors.primary,
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            0,
                            context.pagePadding,
                            AppDimensions.navBarClearance,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: context.recipeGridColumns,
                            crossAxisSpacing: AppDimensions.spaceM,
                            mainAxisSpacing: AppDimensions.spaceM,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: favorites.length,
                          itemBuilder: (context, i) => FadeSlideIn(
                            delay: AppAnimations.staggerFor(i),
                            child: RecipeCard(
                              recipe: favorites[i],
                              width: double.infinity,
                              heroPrefix: _heroPrefix,
                              heroEnabled: true,
                              isFavorite: true,
                              onFavorite: () => _unfavorite(favorites[i]),
                              onTap: () => _open(favorites[i]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
