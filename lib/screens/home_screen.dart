import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/sample_recipes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/widgets/ai_assistant_card.dart';
import '../core/widgets/category_chip.dart';
import '../core/widgets/profile_avatar.dart';
import '../core/widgets/recipe_card.dart';
import '../core/widgets/section_title.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Home tab — the visual centerpiece.
///
/// Layout is inspired by modern AI cooking apps (greeting, filter chips, a
/// highlighted AI card, recipe rails, a search bar) but rendered entirely in
/// the app's warm brown / cream brand palette. Content is placeholder sample
/// data until the `home_feed` backend lands (M5).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenAi});

  /// Called when the AI card is tapped (switches to the AI tab in the shell).
  final VoidCallback? onOpenAi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;

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

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthProvider, String>(
      (p) => (p.user?.name ?? '').trim(),
    );
    final greetingName = name.isEmpty ? 'there' : name.split(' ').first;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _header(greetingName),
          const SizedBox(height: 20),
          _searchBar(),
          const SizedBox(height: 18),
          _categoryChips(),
          const SizedBox(height: 22),
          AiAssistantCard(
            onTap: widget.onOpenAi ?? () => _comingSoon('AI generator coming soon'),
          ),
          const SizedBox(height: 26),
          SectionTitle(
            title: 'Popular Recipes',
            onSeeAll: () => _comingSoon('See all coming soon'),
          ),
          const SizedBox(height: 12),
          _recipeRail(SampleRecipes.popular),
          const SizedBox(height: 26),
          SectionTitle(
            title: 'Quick & Easy',
            onSeeAll: () => _comingSoon('See all coming soon'),
          ),
          const SizedBox(height: 12),
          _recipeRail(SampleRecipes.quickAndEasy),
        ],
      ),
    );
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
      onTap: () => _comingSoon('Search coming soon'),
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
          onTap: () => setState(() => _selectedCategory = i),
        ),
      ),
    );
  }

  Widget _recipeRail(List<Recipe> recipes) {
    final recipeProvider = context.watch<RecipeProvider>();
    return SizedBox(
      height: 212,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => RecipeCard(
          recipe: recipes[i],
          isFavorite: recipeProvider.isFavorite(recipes[i]),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.recipeDetail,
            arguments: recipes[i],
          ),
          onFavorite: () => _toggleFavorite(recipes[i]),
        ),
      ),
    );
  }
}
