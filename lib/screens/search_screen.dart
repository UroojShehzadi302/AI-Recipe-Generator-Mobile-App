import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/sample_recipes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/widgets/app_error_view.dart';
import '../core/widgets/category_chip.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/loading_indicator.dart';
import '../core/widgets/recipe_card.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Search & Categories screen (M10).
///
/// Lets the user search recipes by keyword/ingredient and narrow results by a
/// category filter chip. All data now comes from TheMealDB via
/// [RecipeProvider.search] (the temporary Option A content source, until the
/// real feed lands — see Open Decision 1); this widget only reads provider
/// state and calls provider methods. Text input is debounced (300ms) so the
/// network search runs after the user pauses typing rather than on every
/// keystroke. Search results are FULL recipes, so tapping a card navigates
/// straight to the detail screen.
///
/// Body switches on [RecipeProvider.searchStatus]:
///  * idle    → "Recent searches" (if any) + "Popular searches" chips.
///  * loading → centered [LoadingIndicator].
///  * error   → [AppErrorView] with the provider message + "Try again" retry.
///  * loaded (empty)   → branded [EmptyState].
///  * loaded (results) → a 2-column grid of [RecipeCard]s (matches Favorites).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// Index into [SampleRecipes.categories]; 0 == 'For You' (no category filter).
  int _selectedCategory = 0;

  /// The category name to pass to the provider for the current chip selection.
  String get _categoryFilter => SampleRecipes.categories[_selectedCategory];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounced text change: restart a 300ms timer that runs the search.
  void _onQueryChanged(String value) {
    setState(() {}); // refresh clear (X) suffix visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context
          .read<RecipeProvider>()
          .search(value, category: _categoryFilter);
    });
  }

  /// Runs the search immediately (no debounce) for the current field text.
  void _runSearchNow() {
    _debounce?.cancel();
    context
        .read<RecipeProvider>()
        .search(_controller.text, category: _categoryFilter);
  }

  void _onSubmitted(String value) {
    final String term = value.trim();
    if (term.isNotEmpty) {
      context.read<RecipeProvider>().addRecentSearch(term);
    }
    _runSearchNow();
  }

  /// Selects a category chip and re-runs the search with the new filter.
  void _selectCategory(int index) {
    setState(() => _selectedCategory = index);
    _runSearchNow();
  }

  /// Fills the field with [term], records it, and searches immediately.
  void _applyTerm(String term) {
    _controller
      ..text = term
      ..selection = TextSelection.collapsed(offset: term.length);
    setState(() {});
    context.read<RecipeProvider>().addRecentSearch(term);
    _runSearchNow();
  }

  void _clearField() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    context.read<RecipeProvider>().clearSearch();
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Sign in to save favorites')));
      return;
    }
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  void _openRecipe(Recipe recipe) {
    Navigator.pushNamed(
      context,
      AppRoutes.recipeDetail,
      arguments: recipe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 16),
              _categoryChips(),
              const SizedBox(height: 18),
              Expanded(child: _body(recipeProvider)),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the body for the current [RecipeProvider.searchStatus].
  Widget _body(RecipeProvider provider) {
    switch (provider.searchStatus) {
      case LoadStatus.idle:
        return _suggestions(provider);
      case LoadStatus.loading:
        return const LoadingIndicator();
      case LoadStatus.error:
        return AppErrorView(
          message: provider.searchError ?? 'Something went wrong.',
          onRetry: () => provider.retrySearch(),
        );
      case LoadStatus.loaded:
        if (provider.searchResults.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'No recipes found',
            message: 'Try a different keyword or ingredient.',
          );
        }
        return _resultsGrid(provider);
    }
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _searchField()),
      ],
    );
  }

  Widget _searchField() {
    final bool hasText = _controller.text.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
        onSubmitted: _onSubmitted,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search recipes or ingredients',
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: _clearField,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          onTap: () => _selectCategory(i),
        ),
      ),
    );
  }

  Widget _suggestions(RecipeProvider provider) {
    final List<String> recent = provider.recentSearches;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (recent.isNotEmpty) ...[
          _sectionLabel('Recent searches'),
          const SizedBox(height: 12),
          _termChips(recent),
          const SizedBox(height: 24),
        ],
        _sectionLabel('Popular searches'),
        const SizedBox(height: 12),
        _termChips(SampleRecipes.popularSearches),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _termChips(List<String> terms) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final String term in terms)
          GestureDetector(
            onTap: () => _applyTerm(term),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                term,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _resultsGrid(RecipeProvider provider) {
    final List<Recipe> results = provider.searchResults;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) => RecipeCard(
        recipe: results[i],
        width: double.infinity,
        isFavorite: provider.isFavorite(results[i]),
        onFavorite: () => _toggleFavorite(results[i]),
        onTap: () => _openRecipe(results[i]),
      ),
    );
  }
}
