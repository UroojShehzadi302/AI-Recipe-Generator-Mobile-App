import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_error_view.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/loading_indicator.dart';
import '../core/widgets/recipe_card.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Category results — recipes belonging to a single category (M10).
///
/// A pushed route reached from Search & Categories with a typed [String]
/// category argument (e.g. `'Dinner'`). Data now comes from TheMealDB via
/// [RecipeProvider.loadCategory] (the temporary Option A content source, until
/// the real feed lands — see Open Decision 1), with full loading / empty /
/// error+retry states. The grid mirrors the Favorites grid so the warm brown /
/// cream brand stays consistent.
///
/// Category cards are PARTIAL (title + image only), so tapping a card first
/// resolves it to FULL detail via [RecipeProvider.getRecipeDetails] before
/// navigating; a lightweight overlay spinner covers that round-trip and blocks
/// double-taps.
///
/// Body switches on [RecipeProvider.categoryStatus]:
///  * loading → centered [LoadingIndicator].
///  * error   → [AppErrorView] with the provider message + "Try again" retry.
///  * loaded (empty)   → branded [EmptyState].
///  * loaded (results) → a 2-column grid of [RecipeCard]s.
class CategoryResultsScreen extends StatefulWidget {
  const CategoryResultsScreen({super.key, required this.category});

  /// The category to show results for (also used as the AppBar title).
  final String category;

  @override
  State<CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<CategoryResultsScreen> {
  /// The `recipeId` currently being resolved to full detail, or `null` when
  /// idle. Drives the blocking overlay spinner and prevents double-taps.
  String? _openingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecipeProvider>().loadCategory(widget.category);
    });
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sign in to save favorites')),
        );
      return;
    }
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  /// Opens [recipe] — resolving a partial category card to full detail first.
  ///
  /// When the card has no id we navigate with what we have; otherwise we show
  /// the overlay, fetch full detail, and either push the detail screen or warn
  /// via a snackbar on failure.
  Future<void> _openRecipe(Recipe recipe) async {
    // A resolve is already in flight — ignore further taps.
    if (_openingId != null) return;

    final String? id = recipe.recipeId;
    if (id == null || id.isEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.recipeDetail,
        arguments: recipe,
      );
      return;
    }

    setState(() => _openingId = id);
    final Recipe? full =
        await context.read<RecipeProvider>().getRecipeDetails(id);
    if (!mounted) return;
    setState(() => _openingId = null);

    if (full != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.recipeDetail,
        arguments: full,
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Couldn't load this recipe. Check your connection."),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          widget.category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _body(provider),
            ),
            if (_openingId != null) _openingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Picks the body for the current [RecipeProvider.categoryStatus].
  Widget _body(RecipeProvider provider) {
    switch (provider.categoryStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingIndicator();
      case LoadStatus.error:
        return AppErrorView(
          message: provider.categoryError ?? 'Something went wrong.',
          onRetry: () => provider.retryCategory(),
        );
      case LoadStatus.loaded:
        if (provider.categoryRecipes.isEmpty) {
          return EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Nothing here yet',
            message: 'No ${widget.category} recipes available right now.',
          );
        }
        return _resultsGrid(provider);
    }
  }

  Widget _resultsGrid(RecipeProvider provider) {
    final List<Recipe> recipes = provider.categoryRecipes;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, i) => RecipeCard(
        recipe: recipes[i],
        width: double.infinity,
        isFavorite: provider.isFavorite(recipes[i]),
        onFavorite: () => _toggleFavorite(recipes[i]),
        onTap: () => _openRecipe(recipes[i]),
      ),
    );
  }

  /// A subtle translucent scrim + centered spinner shown while a tapped card is
  /// resolved to full detail. The [ModalBarrier] absorbs input so the grid
  /// can't be tapped again mid-resolve.
  Widget _openingOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            color: AppColors.textPrimary.withValues(alpha: 0.25),
            dismissible: false,
          ),
          const LoadingIndicator(),
        ],
      ),
    );
  }
}
