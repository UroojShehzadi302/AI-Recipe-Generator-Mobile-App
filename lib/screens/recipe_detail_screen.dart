import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/recipe_share_text.dart';
import '../core/widgets/favorite_button.dart';
import '../core/widgets/primary_button.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../services/platform_share_service.dart';
import '../services/share_service.dart';

/// Full-detail view for a single [Recipe].
///
/// Presents a hero image, headline stats, ingredients, numbered instructions,
/// estimated nutrition and tips in the app's warm brown / cream premium style.
/// Stateful so the header favorite button can toggle local UI state.
class RecipeDetailScreen extends StatefulWidget {
  /// The recipe to display.
  final Recipe recipe;

  /// Optional [Hero] tag matching the card that opened this screen, so the
  /// card's photo flies into the header instead of the page simply sliding in.
  ///
  /// Null when there is no originating card (e.g. a freshly generated recipe),
  /// in which case the header image renders directly with no hero.
  final String? heroTag;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.heroTag,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  /// Height of the hero image header.
  static const double _heroHeight = 260;

  Recipe get _recipe => widget.recipe;

  /// Shows a lightweight "coming soon" message.
  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleFavorite() async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      _snack('Sign in to save favorites');
      return;
    }
    await context.read<RecipeProvider>().toggleFavorite(uid, _recipe);
  }

  /// Shares the recipe as plain text via the platform share sheet.
  ///
  /// Composition lives in [RecipeShareText] (pure, testable) and delivery in
  /// the [ShareService] seam, so this handler only bridges the two and reports
  /// the outcome. A share that fell back to the clipboard says so explicitly
  /// rather than claiming success.
  Future<void> _shareRecipe() async {
    // `read` inside a callback, not `watch` in build — sharing is stateless and
    // must never cause a rebuild. `listen: false` keeps this legal here.
    //
    // The screen is pushed from seven call sites and built bare in widget
    // tests, so a missing provider must not crash a tap. Falling back to the
    // default implementation keeps the seam intact (the type is still
    // ShareService) while making the lookup total.
    ShareService shareService;
    try {
      shareService = Provider.of<ShareService>(context, listen: false);
    } on ProviderNotFoundException {
      shareService = const PlatformShareService();
    }
    final String text = RecipeShareText.compose(_recipe);

    final ShareOutcome outcome = await shareService.share(
      text,
      subject: _recipe.title.isEmpty ? AppStrings.appName : _recipe.title,
    );

    if (!mounted) return;
    switch (outcome) {
      case ShareOutcome.shared:
        // The OS sheet is its own confirmation; a snackbar on top of it would
        // be noise.
        break;
      case ShareOutcome.copiedToClipboard:
        _snack(AppStrings.shareCopiedToClipboard);
      case ShareOutcome.failed:
        _snack(AppStrings.shareFailed);
    }
  }

  Future<void> _saveRecipe() async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      _snack('Sign in to save recipes');
      return;
    }
    final recipeProvider = context.read<RecipeProvider>();
    final ok = await recipeProvider.saveRecipe(uid, _recipe);
    if (!mounted) return;
    _snack(ok
        ? 'Saved to your recipes'
        : (recipeProvider.savedError ?? 'Could not save recipe'));
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<RecipeProvider>().isFavorite(_recipe);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHero(context, isFavorite),
          _buildBody(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero image header
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context, bool isFavorite) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Wrapped only when a tag was supplied — a Hero with no matching
          // source on the previous route adds cost for no animation.
          if (widget.heroTag != null)
            Hero(
              tag: widget.heroTag!,
              // A plain image mid-flight: the card's rounded clip and the
              // header's square edges would otherwise fight during the tween.
              flightShuttleBuilder: (_, _, _, _, _) => _buildHeroImage(),
              child: _buildHeroImage(),
            )
          else
            _buildHeroImage(),
          // Top overlay controls.
          Positioned(
            top: MediaQuery.of(context).padding.top + AppDimensions.spaceS,
            left: AppDimensions.spaceL,
            right: AppDimensions.spaceL,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _CircleIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                // Same pop-and-burst as the cards, in the header's circular
                // chrome — favoriting should feel identical wherever it lives.
                Material(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spaceS),
                    child: FavoriteButton(
                      isFavorite: isFavorite,
                      onPressed: _toggleFavorite,
                      size: AppDimensions.iconLg,
                      padded: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    if (_recipe.imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }
    return Image.network(
      _recipe.imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.primarySoft,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
    );
  }

  /// Gradient fallback shown when the image is missing or fails to load.
  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.secondary, AppColors.primary],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu,
        color: Colors.white,
        size: 64,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    return Container(
      // Overlap the hero slightly with rounded top corners.
      transform: Matrix4.translationValues(0, -AppDimensions.spaceXl, 0),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceL,
        AppDimensions.spaceXl,
        AppDimensions.spaceL,
        AppDimensions.spaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_recipe.category.isNotEmpty) ...<Widget>[
            _CategoryPill(label: _recipe.category),
            const SizedBox(height: AppDimensions.spaceM),
          ],
          Text(_recipe.title, style: AppTextStyles.heading),
          if (_recipe.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppDimensions.spaceS),
            Text(_recipe.description, style: AppTextStyles.subtitle),
          ],
          const SizedBox(height: AppDimensions.spaceL),
          _buildStatChips(),
          const SizedBox(height: AppDimensions.spaceXl),
          _buildIngredientsSection(),
          const SizedBox(height: AppDimensions.spaceXl),
          _buildInstructionsSection(),
          if (_recipe.hasNutrition) ...<Widget>[
            const SizedBox(height: AppDimensions.spaceXl),
            _buildNutritionSection(),
          ],
          if (_recipe.tips.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppDimensions.spaceXl),
            _buildTipsSection(),
          ],
        ],
      ),
    );
  }

  // ---- Stat chips ----------------------------------------------------------

  Widget _buildStatChips() {
    // Only render chips for values that actually exist. TheMealDB recipes lack
    // time / servings / calories, so we hide those instead of showing "0".
    return Wrap(
      spacing: AppDimensions.spaceS,
      runSpacing: AppDimensions.spaceS,
      children: <Widget>[
        if (_recipe.hasCookingTime)
          _StatChip(
            icon: Icons.schedule,
            label: '${_recipe.cookingTimeMinutes} min',
          ),
        if (_recipe.difficulty.isNotEmpty)
          _StatChip(
            icon: Icons.local_fire_department_outlined,
            label: _capitalize(_recipe.difficulty),
          ),
        if (_recipe.hasServings)
          _StatChip(
            icon: Icons.people_outline,
            label: '${_recipe.servings} servings',
          ),
        if (_recipe.hasCalories)
          _StatChip(
            icon: Icons.bolt,
            label: '${_recipe.calories} kcal',
          ),
      ],
    );
  }

  // ---- Ingredients ---------------------------------------------------------

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Ingredients'),
        const SizedBox(height: AppDimensions.spaceM),
        if (_recipe.ingredients.isEmpty)
          const _EmptyLine('No ingredients listed.')
        else
          ..._recipe.ingredients.map(_buildIngredientRow),
      ],
    );
  }

  Widget _buildIngredientRow(Ingredient ingredient) {
    final String text =
        '${ingredient.quantity} ${ingredient.name}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }

  // ---- Instructions --------------------------------------------------------

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Instructions'),
        const SizedBox(height: AppDimensions.spaceM),
        if (_recipe.instructions.isEmpty)
          const _EmptyLine('No instructions provided.')
        else
          ...List<Widget>.generate(
            _recipe.instructions.length,
            (int index) => _buildStepRow(index + 1, _recipe.instructions[index]),
          ),
      ],
    );
  }

  Widget _buildStepRow(int number, String step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceXs),
              child: Text(step, style: AppTextStyles.body),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Nutrition -----------------------------------------------------------

  Widget _buildNutritionSection() {
    final Nutrition n = _recipe.nutrition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Nutrition (estimated)'),
        const SizedBox(height: AppDimensions.spaceXs),
        Text('AI estimates', style: AppTextStyles.caption),
        const SizedBox(height: AppDimensions.spaceM),
        Row(
          children: <Widget>[
            Expanded(
              child: _NutritionCard(label: 'Protein', value: n.protein),
            ),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(child: _NutritionCard(label: 'Carbs', value: n.carbs)),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(child: _NutritionCard(label: 'Fat', value: n.fat)),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(child: _NutritionCard(label: 'Fiber', value: n.fiber)),
          ],
        ),
      ],
    );
  }

  // ---- Tips ----------------------------------------------------------------

  Widget _buildTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Tips'),
        const SizedBox(height: AppDimensions.spaceM),
        ..._recipe.tips.map(_buildTipRow),
      ],
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(child: Text(tip, style: AppTextStyles.body)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceL),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  text: 'SAVE RECIPE',
                  onPressed: _saveRecipe,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceM),
              _ShareButton(
                onPressed: _shareRecipe,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

// -----------------------------------------------------------------------------
// Private sub-widgets
// -----------------------------------------------------------------------------

/// A circular, semi-transparent white button used over the hero image.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceS),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Small rounded pill showing the recipe category.
class _CategoryPill extends StatelessWidget {
  final String label;

  const _CategoryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceM,
        vertical: AppDimensions.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Soft rounded pill combining an icon and a short stat label.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceM,
        vertical: AppDimensions.spaceS,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceS),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bold section header used across the body.
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.title);
  }
}

/// Muted single-line message shown for empty sections.
class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Small card showing one macro-nutrient value in grams.
class _NutritionCard extends StatelessWidget {
  final String label;
  final double value;

  const _NutritionCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceM,
        horizontal: AppDimensions.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '${value.toStringAsFixed(0)} g',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Square outlined share button sitting beside the primary save button.
class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShareButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimensions.buttonHeight,
      height: AppDimensions.buttonHeight,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: AppDimensions.brMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const Icon(Icons.share, color: AppColors.primary),
        ),
      ),
    );
  }
}
