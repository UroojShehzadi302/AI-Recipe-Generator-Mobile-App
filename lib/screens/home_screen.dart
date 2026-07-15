import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/sample_recipes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/ai_assistant_card.dart';
import '../core/widgets/category_chip.dart';
import '../core/widgets/loading_indicator.dart';
import '../core/widgets/profile_avatar.dart';
import '../core/widgets/recipe_card.dart';
import '../core/widgets/section_title.dart';
import '../core/widgets/shimmer_loading.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Home tab — the visual centerpiece.
///
/// Layout is inspired by modern AI cooking apps (greeting, filter chips, a
/// highlighted AI card, recipe rails, a search bar) but rendered entirely in
/// the app's warm brown / cream brand palette. The recipe rails are driven by
/// the **live catalog** ([RecipeProvider.loadHomeCatalog]): real TheMealDB
/// cards for Popular / Quick & Easy, plus the curated Pakistani (desi) set —
/// with loading, error+retry, and pull-to-refresh states.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenAi});

  /// Called when the AI card is tapped (switches to the AI tab in the shell).
  final VoidCallback? onOpenAi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;

  /// The `recipeId` currently being resolved to full detail, or `null` when
  /// idle. Drives the blocking overlay spinner and prevents double-taps (rail
  /// cards can be partial and need a lookup before the detail screen opens).
  String? _openingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecipeProvider>().loadHomeCatalog();
    });
  }

  void _comingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      _comingSoon('Sign in to save favorites');
      return;
    }
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  /// Opens [recipe] — resolving a partial rail card to full detail first.
  ///
  /// Curated (desi) and full cards resolve instantly; live TheMealDB category
  /// cards carry only id/title/image, so we show a blocking overlay while the
  /// full recipe is fetched, then push the detail screen (or warn on failure).
  Future<void> _openRecipe(Recipe recipe) async {
    if (_openingId != null) return;

    final String? id = recipe.recipeId;
    if (id == null || id.isEmpty) {
      Navigator.pushNamed(context, AppRoutes.recipeDetail, arguments: recipe);
      return;
    }

    setState(() => _openingId = id);
    final Recipe? full =
        await context.read<RecipeProvider>().getRecipeDetails(id);
    if (!mounted) return;
    setState(() => _openingId = null);

    if (full != null) {
      Navigator.pushNamed(context, AppRoutes.recipeDetail, arguments: full);
    } else {
      _comingSoon("Couldn't load this recipe. Check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthProvider, String>(
      (p) => (p.user?.name ?? '').trim(),
    );
    final greetingName = name.isEmpty ? 'there' : name.split(' ').first;
    final recipeProvider = context.watch<RecipeProvider>();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                context.read<RecipeProvider>().retryHomeCatalog(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                12,
                context.pagePadding,
                24,
              ),
              children: [
                _header(greetingName),
                const SizedBox(height: 20),
                _searchBar(),
                const SizedBox(height: 18),
                _categoryChips(),
                const SizedBox(height: 22),
                AiAssistantCard(
                  onTap: widget.onOpenAi ??
                      () => _comingSoon('AI generator coming soon'),
                ),
                const SizedBox(height: 26),
                SectionTitle(
                  title: 'Popular Recipes',
                  onSeeAll: () => _openCategory(_popularCategory),
                ),
                const SizedBox(height: 12),
                _liveRail(recipeProvider, recipeProvider.popularRail),
                const SizedBox(height: 26),
                SectionTitle(
                  title: 'Pakistani Favourites',
                  onSeeAll: () => _openCategory('Pakistani'),
                ),
                const SizedBox(height: 12),
                _desiRail(recipeProvider),
                const SizedBox(height: 26),
                SectionTitle(
                  title: 'Quick & Easy',
                  onSeeAll: () => _openCategory(_quickCategory),
                ),
                const SizedBox(height: 12),
                _liveRail(recipeProvider, recipeProvider.quickRail),
              ],
            ),
          ),
          if (_openingId != null) _openingOverlay(),
        ],
      ),
    );
  }

  /// App category the "Popular Recipes" rail maps to (mirrors the provider).
  static const String _popularCategory = 'Dinner';

  /// App category the "Quick & Easy" rail maps to (mirrors the provider).
  static const String _quickCategory = 'Breakfast';

  void _openCategory(String category) {
    Navigator.pushNamed(context, AppRoutes.category, arguments: category);
  }

  Widget _header(String greetingName) {
    return Row(
      children: [
        const ProfileAvatar(radius: 24, fallbackInitial: null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $greetingName 👋',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'What would you like to cook today?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _circleIcon(Icons.notifications_none, () => _comingSoon('No notifications yet')),
      ],
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _searchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.search),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text(
              'Search recipes or ingredients',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Selects a category chip. Index 0 ('For You') is the "all" pseudo-category,
  /// so it only updates the visual selection; any real category also navigates
  /// to its results screen.
  void _onCategoryTap(int i) {
    setState(() => _selectedCategory = i);
    if (i == 0) return;
    _openCategory(SampleRecipes.categories[i]);
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SampleRecipes.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => CategoryChip(
          label: SampleRecipes.categories[i],
          selected: i == _selectedCategory,
          onTap: () => _onCategoryTap(i),
        ),
      ),
    );
  }

  /// A live (network-backed) rail: shows a loading strip while the catalog
  /// loads, an inline retry on failure, and the recipe cards once loaded.
  Widget _liveRail(RecipeProvider provider, List<Recipe> recipes) {
    switch (provider.homeCatalogStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return _railSkeleton();
      case LoadStatus.error:
        return _RailError(
          message: provider.homeCatalogError ?? 'Something went wrong.',
          onRetry: () => provider.retryHomeCatalog(),
        );
      case LoadStatus.loaded:
        if (recipes.isEmpty) return const _RailEmpty();
        return _recipeRail(recipes);
    }
  }

  /// A shimmering rail placeholder sized to the current screen.
  Widget _railSkeleton() => RecipeRailSkeleton(
        height: context.railHeight,
        cardWidth: context.railCardWidth,
      );

  /// The desi rail. Backed by the curated local set, so it shows as soon as it
  /// is populated — even if the network rails failed. Falls back to the loading
  /// strip only while the very first load is still in flight.
  Widget _desiRail(RecipeProvider provider) {
    if (provider.desiRail.isNotEmpty) return _recipeRail(provider.desiRail);
    if (provider.homeCatalogStatus == LoadStatus.loading ||
        provider.homeCatalogStatus == LoadStatus.idle) {
      return _railSkeleton();
    }
    return const _RailEmpty();
  }

  Widget _recipeRail(List<Recipe> recipes) {
    final recipeProvider = context.watch<RecipeProvider>();
    return SizedBox(
      height: context.railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => RecipeCard(
          recipe: recipes[i],
          width: context.railCardWidth,
          isFavorite: recipeProvider.isFavorite(recipes[i]),
          onTap: () => _openRecipe(recipes[i]),
          onFavorite: () => _toggleFavorite(recipes[i]),
        ),
      ),
    );
  }

  /// A subtle translucent scrim + centered spinner shown while a tapped card is
  /// resolved to full detail. Absorbs input so the rails can't be tapped again
  /// mid-resolve.
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

/// Inline, rail-sized error with a retry action.
class _RailError extends StatelessWidget {
  const _RailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 30),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rail-sized empty placeholder when a category has no recipes.
class _RailEmpty extends StatelessWidget {
  const _RailEmpty();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 212,
      child: Center(
        child: Text(
          'Nothing here yet',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
