import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/recipe_card.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

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

  Future<void> _unfavorite(Recipe recipe) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<RecipeProvider>().favorites;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Favorites',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: favorites.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border,
                      title: 'No favorites yet',
                      message: 'Tap the heart on any recipe to save it here.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.74,
                      ),
                      itemCount: favorites.length,
                      itemBuilder: (context, i) => RecipeCard(
                        recipe: favorites[i],
                        width: double.infinity,
                        isFavorite: true,
                        onFavorite: () => _unfavorite(favorites[i]),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.recipeDetail,
                          arguments: favorites[i],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
