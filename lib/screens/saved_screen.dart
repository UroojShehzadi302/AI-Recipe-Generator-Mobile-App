import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/recipe_card.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_screen.dart';

/// How the saved list is ordered.
enum SavedSort {
  newest(AppStrings.sortNewest, Icons.arrow_downward_rounded),
  oldest(AppStrings.sortOldest, Icons.arrow_upward_rounded),
  titleAz(AppStrings.sortTitleAz, Icons.sort_by_alpha_rounded),
  titleZa(AppStrings.sortTitleZa, Icons.sort_by_alpha_rounded);

  const SavedSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Saved tab — recipes the user generated with AI and kept.
///
/// Loads from Firestore (`users/{uid}/generatedRecipes`) via [RecipeProvider]
/// and adds the management the list needs once it grows past a screenful:
/// search, sort, swipe/long-press to delete, and favoriting straight from the
/// grid.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  SavedSort _sort = SavedSort.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final String? uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<RecipeProvider>().loadSaved(uid);
    }
  }

  /// Applies the search filter and the chosen ordering.
  ///
  /// The provider keeps saved recipes newest-first, so "newest" is the source
  /// order and "oldest" is simply its reverse — no timestamp is needed on the
  /// [Recipe] itself.
  List<Recipe> _visible(List<Recipe> saved) {
    final String q = _query.trim().toLowerCase();

    final List<Recipe> filtered = q.isEmpty
        ? List<Recipe>.of(saved)
        : saved.where((Recipe r) {
            if (r.title.toLowerCase().contains(q)) return true;
            if (r.category.toLowerCase().contains(q)) return true;
            if (r.tags.any((String t) => t.toLowerCase().contains(q))) {
              return true;
            }
            return r.ingredients
                .any((Ingredient i) => i.name.toLowerCase().contains(q));
          }).toList();

    switch (_sort) {
      case SavedSort.newest:
        break;
      case SavedSort.oldest:
        return filtered.reversed.toList(growable: false);
      case SavedSort.titleAz:
        filtered.sort((Recipe a, Recipe b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SavedSort.titleZa:
        filtered.sort((Recipe a, Recipe b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    }
    return filtered;
  }

  Future<void> _delete(Recipe recipe) async {
    final String? uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    final bool confirmed = await _confirmDelete(recipe);
    if (!confirmed || !mounted) return;

    final RecipeProvider provider = context.read<RecipeProvider>();
    final bool ok = await provider.deleteSaved(uid, recipe);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Removed "${recipe.title}"'
                : provider.savedError ?? 'Could not remove that recipe.',
          ),
        ),
      );
  }

  Future<bool> _confirmDelete(Recipe recipe) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved recipe?'),
        content: Text(
          '"${recipe.title}" will be removed from your saved recipes. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.remove),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final String? uid = context.read<AuthProvider>().uid;
    if (uid == null) return;
    await context.read<RecipeProvider>().toggleFavorite(uid, recipe);
  }

  /// Namespaces this screen's hero tags. The same recipe can be on screen in
  /// another list elsewhere in the app, and duplicate tags throw.
  static const String _heroPrefix = 'saved-';

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

  Future<void> _pickSort() async {
    final SavedSort? picked = await showModalBottomSheet<SavedSort>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spaceXl,
                AppDimensions.spaceS,
                AppDimensions.spaceXl,
                AppDimensions.spaceS,
              ),
              child: Text(AppStrings.sortBy,
                  style: AppTextStyles.sectionTitle),
            ),
            for (final SavedSort option in SavedSort.values)
              ListTile(
                leading: Icon(
                  option.icon,
                  color: option == _sort
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(
                  option.label,
                  style: option == _sort
                      ? AppTextStyles.cardTitle
                          .copyWith(color: AppColors.primary)
                      : AppTextStyles.body,
                ),
                trailing: option == _sort
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            const SizedBox(height: AppDimensions.spaceS),
          ],
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final RecipeProvider provider = context.watch<RecipeProvider>();
    final List<Recipe> saved = provider.saved;
    final List<Recipe> visible = _visible(saved);
    final bool searching = _query.trim().isNotEmpty;

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
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.savedRecipes,
                        style: AppTextStyles.screenTitle,
                      ),
                    ),
                    if (saved.isNotEmpty)
                      _IconAction(
                        icon: _sort.icon,
                        tooltip: AppStrings.sortBy,
                        onTap: _pickSort,
                      ),
                  ],
                ),
              ),
              if (saved.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppDimensions.spaceM),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding,
                  ),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: (String value) =>
                        setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXs),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding,
                    vertical: AppDimensions.spaceS,
                  ),
                  child: Text(
                    '${visible.length} '
                    '${visible.length == 1 ? "recipe" : "recipes"}'
                    '${searching ? " found" : ""} · ${_sort.label}',
                    style: AppTextStyles.label,
                  ),
                ),
              ],
              Expanded(
                child: saved.isEmpty
                    ? const EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: AppStrings.noSavedRecipes,
                        message: AppStrings.noSavedRecipesBody,
                      )
                    : visible.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: AppStrings.noSavedMatches,
                            message: AppStrings.noSavedMatchesBody,
                            compact: true,
                          )
                        : _grid(provider, visible),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(RecipeProvider provider, List<Recipe> recipes) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppColors.primary,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          AppDimensions.spaceXs,
          context.pagePadding,
          AppDimensions.navBarClearance,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.recipeGridColumns,
          crossAxisSpacing: AppDimensions.spaceM,
          mainAxisSpacing: AppDimensions.spaceM,
          childAspectRatio: 0.72,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, i) {
          final Recipe recipe = recipes[i];
          return FadeSlideIn(
            delay: AppAnimations.staggerFor(i),
            child: GestureDetector(
              // Long-press to delete: discoverable without adding chrome to
              // every card, and it pairs with the confirm dialog.
              onLongPress: () => _delete(recipe),
              child: RecipeCard(
                recipe: recipe,
                width: double.infinity,
                heroPrefix: _heroPrefix,
                heroEnabled: true,
                isFavorite: provider.isFavorite(recipe),
                onFavorite: () => _toggleFavorite(recipe),
                onTap: () => _open(recipe),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact rounded search input used in the Saved header.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: AppStrings.searchSavedHint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: AppDimensions.iconMd,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onClear,
                tooltip: 'Clear',
              ),
        // A pill reads as "filter this list", distinct from the squared form
        // fields used for data entry.
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brPill,
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brPill,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceL,
          vertical: AppDimensions.spaceM,
        ),
      ),
    );
  }
}

/// Small circular icon button used beside a screen title.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppShadows.subtle,
          ),
          child: Icon(icon, size: AppDimensions.iconMd,
              color: AppColors.primary),
        ),
      ),
    );
  }
}
