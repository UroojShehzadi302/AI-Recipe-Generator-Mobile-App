import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/app_error_view.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/shimmer_loading.dart';
import '../models/generation_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Usage History — every recipe the user generated with AI.
///
/// Each row shows the recipe name, the prompt that produced it, when it
/// happened, and its status. Tapping a row reopens the full recipe; swiping (or
/// using the row menu) deletes it.
///
/// Grouped by day ("Today" / "Yesterday" / a date) because a flat list of
/// timestamps is hard to scan once there are more than a handful of entries.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final String? uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<RecipeProvider>().loadHistory(uid);
    }
  }

  Future<void> _delete(GenerationEntry entry) async {
    final String? uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    final RecipeProvider provider = context.read<RecipeProvider>();
    final bool ok = await provider.deleteHistoryEntry(uid, entry);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Removed "${entry.title}"'
                : provider.historyError ?? 'Could not remove that entry.',
          ),
        ),
      );
  }

  Future<bool> _confirmDelete(GenerationEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from history?'),
        content: Text(
          '"${entry.title}" will be removed from your history and your saved '
          'recipes. This cannot be undone.',
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

  @override
  Widget build(BuildContext context) {
    final RecipeProvider provider = context.watch<RecipeProvider>();
    final List<GenerationEntry> entries = provider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: _body(provider, entries),
          ),
        ),
      ),
    );
  }

  Widget _body(RecipeProvider provider, List<GenerationEntry> entries) {
    if (provider.historyStatus == LoadStatus.loading && entries.isEmpty) {
      return const _HistorySkeleton();
    }

    if (provider.historyStatus == LoadStatus.error && entries.isEmpty) {
      return AppErrorView(
        message: provider.historyError ?? 'Could not load your history.',
        onRetry: _load,
      );
    }

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: AppStrings.historyEmpty,
        message: AppStrings.historyEmptyBody,
      );
    }

    // Flatten into a single list of headers + rows so one ListView.builder
    // renders the whole grouped view lazily.
    final List<_Row> rows = _groupByDay(entries);

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          AppDimensions.spaceS,
          context.pagePadding,
          AppDimensions.spaceXxl,
        ),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final _Row row = rows[i];
          if (row.header != null) {
            return Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : AppDimensions.spaceXl,
                bottom: AppDimensions.spaceS,
              ),
              child: Text(row.header!, style: AppTextStyles.label),
            );
          }

          final GenerationEntry entry = row.entry!;
          return FadeSlideIn(
            delay: AppAnimations.staggerFor(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
              child: _HistoryTile(
                entry: entry,
                onOpen: () => Navigator.pushNamed(
                  context,
                  AppRoutes.recipeDetail,
                  arguments: entry.recipe,
                ),
                onDelete: () => _delete(entry),
                confirmDismiss: () => _confirmDelete(entry),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Splits [entries] (already newest-first) into day-headed sections.
  List<_Row> _groupByDay(List<GenerationEntry> entries) {
    final List<_Row> rows = <_Row>[];
    String? currentLabel;

    for (final GenerationEntry entry in entries) {
      final String label = _dayLabel(entry.createdAt);
      if (label != currentLabel) {
        rows.add(_Row.header(label));
        currentLabel = label;
      }
      rows.add(_Row.entry(entry));
    }
    return rows;
  }

  /// "Today" / "Yesterday" / "12 Mar 2026", or "Earlier" for entries whose
  /// server timestamp hasn't resolved (epoch 0).
  static String _dayLabel(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Earlier';

    final DateTime now = DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

/// One flattened list row: either a day header or an entry.
class _Row {
  const _Row.header(this.header) : entry = null;
  const _Row.entry(this.entry) : header = null;

  final String? header;
  final GenerationEntry? entry;
}

/// A single history row: title, prompt, time, and status.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    required this.confirmDismiss,
  });

  final GenerationEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final Future<bool> Function() confirmDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>('history-${entry.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDelete(),
      background: _swipeBackground(),
      child: PressableScale(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spaceM),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDimensions.brLg,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: AppDimensions.spaceXs),
                    // The prompt is what the user recognises, so it gets the
                    // quotation treatment rather than being hidden.
                    Text(
                      entry.hasPrompt
                          ? '"${entry.prompt}"'
                          : 'No prompt recorded',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontStyle: entry.hasPrompt
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: entry.hasPrompt
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceS),
                    Row(
                      children: [
                        _statusPill(),
                        const SizedBox(width: AppDimensions.spaceS),
                        Flexible(
                          child: Text(
                            _timeLabel(entry.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: AppDimensions.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    const double size = 56;
    return ClipRRect(
      borderRadius: AppDimensions.brSm,
      child: SizedBox(
        width: size,
        height: size,
        child: entry.recipe.imageUrl.isEmpty
            ? DecoratedBox(
                decoration:
                    BoxDecoration(gradient: AppColors.placeholderGradient),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.onPrimary,
                  size: AppDimensions.iconMd,
                ),
              )
            : Image.network(
                entry.recipe.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => DecoratedBox(
                  decoration:
                      BoxDecoration(gradient: AppColors.placeholderGradient),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.onPrimary,
                    size: AppDimensions.iconMd,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statusPill() {
    final bool saved = entry.status == GenerationStatus.saved;
    final Color color = saved ? AppColors.success : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceS,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppDimensions.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            saved ? Icons.bookmark_rounded : Icons.auto_awesome,
            size: 11,
            color: color,
          ),
          const SizedBox(width: AppDimensions.spaceXs),
          Text(
            saved ? AppStrings.statusSaved : AppStrings.statusGenerated,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppDimensions.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppDimensions.brLg,
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: AppColors.onPrimary,
      ),
    );
  }

  /// A short relative time ("2h ago"), falling back to a clock time.
  static String _timeLabel(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Just now';

    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final String hh = date.hour.toString().padLeft(2, '0');
    final String mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// Loading placeholder matching the row layout.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        AppDimensions.spaceL,
        context.pagePadding,
        AppDimensions.spaceXxl,
      ),
      itemCount: 6,
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppDimensions.spaceM),
        child: Shimmer(
          child: ShimmerBox(height: 88, radius: AppDimensions.radiusLg),
        ),
      ),
    );
  }
}
