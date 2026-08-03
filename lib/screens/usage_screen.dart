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
import '../models/usage_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart' show LoadStatus;
import '../providers/usage_provider.dart';

/// Credit Usage — how many AI tokens this user has consumed.
///
/// Leads with the headline total (the number the user actually asked for),
/// then input/output/request sub-totals, a per-feature breakdown, and the
/// individual calls newest-first.
///
/// Deliberately shows tokens, not currency: the app does not bill anyone, and
/// putting a price on a free-tier number would be inventing a figure.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final String? uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<UsageProvider>().load(uid);
    }
  }

  Future<void> _clear() async {
    final String? uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    final bool confirmed = await _confirmClear() ?? false;
    if (!confirmed || !mounted) return;

    final UsageProvider provider = context.read<UsageProvider>();
    final bool ok = await provider.clear(uid);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Usage log cleared'
                : provider.error ?? 'Could not clear your usage log.',
          ),
        ),
      );
  }

  Future<bool?> _confirmClear() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.usageClearConfirmTitle),
        content: const Text(AppStrings.usageClearConfirmBody),
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
            child: const Text(AppStrings.clear),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UsageProvider provider = context.watch<UsageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.usageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        actions: [
          if (provider.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clear,
              tooltip: AppStrings.usageClear,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: _body(provider),
          ),
        ),
      ),
    );
  }

  Widget _body(UsageProvider provider) {
    if (provider.status == LoadStatus.loading && provider.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.status == LoadStatus.error && provider.entries.isEmpty) {
      return AppErrorView(
        message: provider.error ?? 'Could not load your usage.',
        onRetry: _load,
      );
    }

    if (provider.entries.isEmpty) {
      return const EmptyState(
        icon: Icons.data_usage_rounded,
        title: AppStrings.usageEmpty,
        message: AppStrings.usageEmptyBody,
      );
    }

    final UsageSummary summary = provider.summary;
    final List<UsageEntry> entries = provider.entries;

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          AppDimensions.spaceL,
          context.pagePadding,
          AppDimensions.spaceXxl,
        ),
        children: [
          FadeSlideIn(child: _TotalCard(summary: summary)),
          const SizedBox(height: AppDimensions.spaceL),
          FadeSlideIn(
            delay: AppAnimations.staggerFor(1),
            child: _SplitRow(summary: summary),
          ),
          if (summary.byKind.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spaceXl),
            FadeSlideIn(
              delay: AppAnimations.staggerFor(2),
              child: const Text(
                AppStrings.usageBreakdownTitle,
                style: AppTextStyles.sectionTitle,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceM),
            FadeSlideIn(
              delay: AppAnimations.staggerFor(3),
              child: _Breakdown(summary: summary),
            ),
          ],
          const SizedBox(height: AppDimensions.spaceXl),
          FadeSlideIn(
            delay: AppAnimations.staggerFor(4),
            child: const Text(
              AppStrings.usageRecentTitle,
              style: AppTextStyles.sectionTitle,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceM),
          for (int i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
              child: FadeSlideIn(
                delay: AppAnimations.staggerFor(i + 5),
                child: _UsageTile(entry: entries[i]),
              ),
            ),
          const SizedBox(height: AppDimensions.spaceS),
          Text(
            AppStrings.usageDisclaimer,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a token count with thousands separators (e.g. `12,480`).
///
/// Hand-rolled rather than via `intl` — the project has no localization
/// dependency and this is the only place a grouped number appears.
String formatTokens(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The headline card: total tokens consumed across every AI request.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final UsageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppDimensions.brXl,
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: AppDimensions.iconMd,
                color: AppColors.onPrimary,
              ),
              const SizedBox(width: AppDimensions.spaceS),
              Text(
                AppStrings.usageTotalLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Text(
            formatTokens(summary.totalTokens),
            style: AppTextStyles.display.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(
            summary.callCount == 1
                ? 'across 1 AI request'
                : 'across ${formatTokens(summary.callCount)} AI requests',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input / Output / Requests sub-totals.
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.summary});

  final UsageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: AppStrings.usageInputLabel,
            value: formatTokens(summary.promptTokens),
            icon: Icons.north_east_rounded,
          ),
        ),
        const SizedBox(width: AppDimensions.spaceM),
        Expanded(
          child: _StatTile(
            label: AppStrings.usageOutputLabel,
            value: formatTokens(summary.outputTokens),
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: AppDimensions.spaceM),
        Expanded(
          child: _StatTile(
            label: AppStrings.usageRequestsLabel,
            value: formatTokens(summary.callCount),
            icon: Icons.tag_rounded,
          ),
        ),
      ],
    );
  }
}

/// One small stat tile inside [_SplitRow].
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceM,
        horizontal: AppDimensions.spaceS,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimensions.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimensions.iconSm, color: AppColors.primary),
          const SizedBox(height: AppDimensions.spaceXs),
          FittedBox(
            child: Text(value, style: AppTextStyles.cardTitle),
          ),
          const SizedBox(height: AppDimensions.space2),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-feature share of the total, as labelled proportional bars.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.summary});

  final UsageSummary summary;

  @override
  Widget build(BuildContext context) {
    // Largest consumer first — that is the question the breakdown answers.
    final List<MapEntry<UsageKind, int>> rows = summary.byKind.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimensions.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i != 0) const SizedBox(height: AppDimensions.spaceL),
            _BreakdownRow(
              kind: rows[i].key,
              tokens: rows[i].value,
              // Guard the divide: a summary can only reach here with entries,
              // but a zero total would still produce NaN and crash layout.
              fraction: summary.totalTokens > 0
                  ? rows[i].value / summary.totalTokens
                  : 0,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single labelled proportion bar.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.kind,
    required this.tokens,
    required this.fraction,
  });

  final UsageKind kind;
  final int tokens;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _iconFor(kind),
              size: AppDimensions.iconSm,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(child: Text(kind.label, style: AppTextStyles.bodyMedium)),
            Text(
              '${formatTokens(tokens)}  ·  ${(fraction * 100).round()}%',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceS),
        ClipRRect(
          borderRadius: AppDimensions.brPill,
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.primarySoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(UsageKind kind) {
    switch (kind) {
      case UsageKind.recipe:
        return Icons.auto_awesome_rounded;
      case UsageKind.chat:
        return Icons.chat_bubble_outline_rounded;
      case UsageKind.title:
        return Icons.label_outline_rounded;
    }
  }
}

/// One recorded AI call.
class _UsageTile extends StatelessWidget {
  const _UsageTile({required this.entry});

  final UsageEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimensions.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryFaint,
              borderRadius: AppDimensions.brSm,
            ),
            child: Icon(
              _BreakdownRow._iconFor(entry.kind),
              size: AppDimensions.iconSm,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.kind.label,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.space2),
                Text(
                  '${formatTokens(entry.promptTokens)} in  ·  '
                  '${formatTokens(entry.outputTokens)} out'
                  '${_relativeTime(entry.createdAt)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceS),
          Text(
            formatTokens(entry.totalTokens),
            style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// A trailing "  ·  3h ago" fragment, or empty when the server timestamp has
  /// not resolved yet (epoch 0) — better to show nothing than "56 years ago".
  static String _relativeTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '';

    final Duration diff = DateTime.now().difference(date);
    if (diff.isNegative) return '  ·  just now';
    if (diff.inMinutes < 1) return '  ·  just now';
    if (diff.inMinutes < 60) return '  ·  ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '  ·  ${diff.inHours}h ago';
    if (diff.inDays < 7) return '  ·  ${diff.inDays}d ago';
    return '  ·  ${(diff.inDays / 7).floor()}w ago';
  }
}
