import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/sample_recipes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/ai_assistant_card.dart';
import '../core/widgets/category_chip.dart';
import '../core/widgets/profile_avatar.dart';
import '../core/widgets/recipe_card.dart';
import '../core/widgets/recipe_opening_overlay.dart';
import '../core/widgets/section_title.dart';
import '../core/widgets/shimmer_loading.dart';
import '../models/app_notification.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';
import 'recipe_detail_screen.dart';

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

  /// The recipe currently being resolved to full detail, or `null` when idle.
  ///
  /// Drives the blocking [RecipeOpeningOverlay] and prevents double-taps (rail
  /// cards can be partial and need a lookup before the detail screen opens).
  /// The whole [Recipe] is held, not just its id, so the overlay can show the
  /// card's own photo and title while the fetch is in flight.
  Recipe? _opening;

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
  Future<void> _openRecipe(Recipe recipe, String railKey) async {
    if (_opening != null) return;

    // The tag is built from the CARD's recipe and its rail, so the flight still
    // matches after the fetch swaps in the fuller object below.
    final String heroTag =
        RecipeCard.heroTagFor(recipe, prefix: '$railKey-');

    final String? id = recipe.recipeId;
    if (id == null || id.isEmpty) {
      _push(recipe, heroTag);
      return;
    }

    setState(() => _opening = recipe);
    final Recipe? full =
        await context.read<RecipeProvider>().getRecipeDetails(id);
    if (!mounted) return;
    setState(() => _opening = null);

    if (full != null) {
      _push(full, heroTag);
    } else {
      _comingSoon("Couldn't load this recipe. Check your connection.");
    }
  }

  void _push(Recipe recipe, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(recipe: recipe, heroTag: heroTag),
      ),
    );
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
              // No `physics:` — AppScrollBehavior already supplies bouncing
              // physics with an AlwaysScrollableScrollPhysics parent, which is
              // what keeps a short list draggable for pull-to-refresh. Setting
              // it here overrode the bounce and gave Home Android's hard stop.
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                AppDimensions.spaceM,
                context.pagePadding,
                // Clears the floating nav bar so the last rail isn't hidden.
                AppDimensions.navBarClearance,
              ),
              children: [
                _header(greetingName),
                const SizedBox(height: AppDimensions.spaceXl),
                _searchBar(),
                const SizedBox(height: AppDimensions.spaceL),
                _categoryChips(),
                const SizedBox(height: AppDimensions.spaceXl),
                AiAssistantCard(
                  onTap: widget.onOpenAi ??
                      () => _comingSoon('AI generator coming soon'),
                ),
                const SizedBox(height: AppDimensions.spaceXxl),
                SectionTitle(
                  title: 'Popular Recipes',
                  subtitle: 'Trending with home cooks',
                  onSeeAll: () => _openCategory(_popularCategory),
                ),
                const SizedBox(height: AppDimensions.spaceM),
                _liveRail(
                  recipeProvider,
                  recipeProvider.popularRail,
                  'popular',
                ),
                const SizedBox(height: AppDimensions.spaceXxl),
                SectionTitle(
                  title: 'Pakistani Favourites',
                  subtitle: 'Desi classics, done right',
                  onSeeAll: () => _openCategory('Pakistani'),
                ),
                const SizedBox(height: AppDimensions.spaceM),
                _desiRail(recipeProvider),
                const SizedBox(height: AppDimensions.spaceXxl),
                SectionTitle(
                  title: 'Quick & Easy',
                  subtitle: 'Ready in no time',
                  onSeeAll: () => _openCategory(_quickCategory),
                ),
                const SizedBox(height: AppDimensions.spaceM),
                _liveRail(recipeProvider, recipeProvider.quickRail, 'quick'),
              ],
            ),
          ),
          if (_opening != null) RecipeOpeningOverlay(recipe: _opening!),
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

  Widget _header(String greetingName) => _HomeHeader(
        greetingName: greetingName,
        onOpenNotifications: _openNotifications,
      );

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => const _NotificationInboxSheet(),
    );
  }

  Widget _searchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.search),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceL,
          vertical: AppDimensions.spaceM + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDimensions.brPill,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Text(
              'Search recipes or ingredients',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
              ),
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
        padding: EdgeInsets.zero,
        itemCount: SampleRecipes.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.spaceS),
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
  ///
  /// [railKey] namespaces each rail's [Hero] tags — the same recipe can appear
  /// in more than one rail, and duplicate hero tags on screen throw.
  Widget _liveRail(
    RecipeProvider provider,
    List<Recipe> recipes,
    String railKey,
  ) {
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
        return _recipeRail(recipes, railKey);
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
    if (provider.desiRail.isNotEmpty) {
      return _recipeRail(provider.desiRail, 'desi');
    }
    if (provider.homeCatalogStatus == LoadStatus.loading ||
        provider.homeCatalogStatus == LoadStatus.idle) {
      return _railSkeleton();
    }
    return const _RailEmpty();
  }

  Widget _recipeRail(List<Recipe> recipes, String railKey) {
    final recipeProvider = context.watch<RecipeProvider>();
    return SizedBox(
      height: context.railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Trims the rail's own padding so cards align with the page gutter.
        padding: EdgeInsets.zero,
        itemCount: recipes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.spaceM),
        itemBuilder: (context, i) => RecipeCard(
          recipe: recipes[i],
          width: context.railCardWidth,
          heroPrefix: '$railKey-',
          heroEnabled: true,
          isFavorite: recipeProvider.isFavorite(recipes[i]),
          onTap: () => _openRecipe(recipes[i], railKey),
          onFavorite: () => _toggleFavorite(recipes[i]),
        ),
      ),
    );
  }

}

/// The Home greeting row: avatar, greeting, and the notification bell.
///
/// A separate widget on purpose. [HomeScreen.build] calls
/// `watch<RecipeProvider>()`, so favoriting a recipe rebuilds its whole tree —
/// and rebuilding the avatar there made the profile picture visibly glitch.
/// Isolated here, the header only rebuilds when the *user* or the unread count
/// actually changes.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greetingName,
    required this.onOpenNotifications,
  });

  final String greetingName;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    // Watch the user's photo + name so the avatar updates live after an Edit
    // Profile change (the avatar is a base64 data: URI — ProfileAvatar renders
    // it via imageProviderFromUrl).
    final String? photoUrl = context.select<AuthProvider, String?>(
      (p) => p.user?.photoUrl,
    );
    final String fullName = context.select<AuthProvider, String>(
      (p) => (p.user?.name ?? '').trim(),
    );

    return Row(
      children: [
        ProfileAvatar(
          radius: 24,
          imageUrl: photoUrl,
          fallbackInitial: fullName.isNotEmpty ? fullName[0] : null,
        ),
        const SizedBox(width: AppDimensions.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $greetingName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppDimensions.space2),
              Text(
                'What would you like to cook today?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        _NotificationBell(onTap: onOpenNotifications),
      ],
    );
  }
}

/// The notification bell with a live unread badge.
///
/// Separate again so a changing unread count repaints only the bell, not the
/// avatar beside it.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int badgeCount = context.select<NotificationProvider, int>(
      (p) => p.unreadCount,
    );
    final IconData icon = badgeCount > 0
        ? Icons.notifications_active
        : Icons.notifications_none;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.subtle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceXs + 1,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: AppDimensions.brPill,
                    border: Border.all(
                      color: AppColors.background,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
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
            Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 30),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
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
    return SizedBox(
      height: 212,
      child: Center(
        child: Text(
          'Nothing here yet',
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}

/// Bottom-sheet inbox listing received push notifications.
///
/// Reads from [NotificationProvider]: shows a branded empty state when there
/// are none, otherwise a scrollable list (title / body / relative time) with a
/// "Mark all read" affordance in the header. Opening the sheet does NOT clear
/// the badge on its own — the user clears it via "Mark all read".
class _NotificationInboxSheet extends StatefulWidget {
  const _NotificationInboxSheet();

  @override
  State<_NotificationInboxSheet> createState() =>
      _NotificationInboxSheetState();
}

class _NotificationInboxSheetState extends State<_NotificationInboxSheet> {
  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppDimensions.spaceM),
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceL),
              child: Row(
                children: <Widget>[
                  Icon(Icons.notifications_none, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spaceM),
                  Text('Notifications', style: AppTextStyles.title),
                  const Spacer(),
                  Consumer<NotificationProvider>(
                    builder: (context, notif, _) {
                      if (notif.items.isEmpty) return const SizedBox.shrink();
                      return PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: AppColors.primary,
                        ),
                        onSelected: (String value) {
                          if (value == 'read') {
                            notif.markAllRead();
                          } else {
                            notif.clear();
                          }
                        },
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'read',
                            enabled: notif.hasUnread,
                            child: Text(
                              'Mark all read',
                              style: AppTextStyles.body,
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'clear',
                            child: Text(
                              'Clear all',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Flexible(
              child: Consumer<NotificationProvider>(
                builder: (context, notif, _) {
                  final List<AppNotification> items = notif.items;
                  if (items.isEmpty) return const _NotificationsEmpty();
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: AppDimensions.spaceL),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final AppNotification item = items[index];
                      return Dismissible(
                        key: ValueKey<String>(item.dedupeKey),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => notif.remove(item.dedupeKey),
                        background: Container(
                          color: AppColors.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(
                            right: AppDimensions.spaceL,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        child: _NotificationTile(
                          item: item,
                          onTap: () => notif.markRead(item.dedupeKey),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single notification row in the inbox.
///
/// Tapping the row marks *this* notification read (via [onTap]); the others
/// stay unread and keep the bell badge alive. Unread rows carry a tinted
/// background and a trailing dot so they read as unread at a glance.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = item.title.isEmpty ? 'Notification' : item.title;
    return ListTile(
      onTap: item.read ? null : onTap,
      tileColor: item.read
          ? null
          : AppColors.primarySoft.withValues(alpha: 0.35),
      trailing: item.read
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(
          item.read ? Icons.notifications_none : Icons.notifications_active,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(
          fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: item.body.isEmpty
          ? Text(_relativeTime(item.receivedAt), style: AppTextStyles.caption)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 2),
                Text(_relativeTime(item.receivedAt),
                    style: AppTextStyles.caption),
              ],
            ),
      isThreeLine: item.body.isNotEmpty,
    );
  }

  /// A short, dependency-free relative timestamp ("just now", "5m ago", …).
  static String _relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

/// Branded empty state for the notifications inbox.
class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceL,
        AppDimensions.spaceL,
        AppDimensions.spaceL,
        AppDimensions.spaceXxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceL),
          Text(
            'No notifications yet',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            "We'll let you know when something tasty comes up.",
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
