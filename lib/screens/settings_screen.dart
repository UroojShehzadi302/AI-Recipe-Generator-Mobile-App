import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/about_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../routes/app_routes.dart';

/// Settings (M11) — preferences, legal links, and account actions.
///
/// Three groups, matching the grouped-card language Profile already uses:
///
/// * **Preferences** — the notifications switch. See
///   [NotificationProvider.setNotificationsEnabled] for exactly what it does
///   (a local preference, not an FCM unsubscribe — this app is receive-only).
/// * **About** — Privacy Policy, Terms of Service, and the shared About dialog.
/// * **Account** — pushes the existing Change Password / Delete Account
///   screens. Nothing is rebuilt here; those flows already meet the Play
///   requirements and are navigated to as-is.
///
/// No business logic lives in this file: the toggle goes through
/// [NotificationProvider], and account actions are route pushes.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Re-read the stored preference on open: another isolate (or a previous
    // session) may have written it since this provider last looked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().loadPreferences();
    });
  }

  Future<void> _setNotifications(bool enabled) async {
    await context.read<NotificationProvider>().setNotificationsEnabled(enabled);
  }

  /// Presents [url] in a copyable dialog.
  ///
  /// ⚠️ TODO(owner): this app has **no `url_launcher` dependency**, and adding
  /// one is a call for the owner to make — so we cannot open a browser
  /// directly. Showing the address with a Copy action is the honest fallback:
  /// the user can still reach the page, and nothing pretends to be a link that
  /// does nothing. If `url_launcher` is ever added, replace the body of this
  /// method with a `launchUrl` call and drop the dialog.
  Future<void> _showLink(String title, String url) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.linkDialogBody,
                style: AppTextStyles.subtitle),
            const SizedBox(height: AppDimensions.spaceM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceM),
              decoration: BoxDecoration(
                color: AppColors.primaryFaint,
                borderRadius: AppDimensions.brSm,
              ),
              child: SelectableText(url, style: AppTextStyles.body),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text(AppStrings.close),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text(AppStrings.linkCopied)),
                );
            },
            child: const Text(AppStrings.linkCopy),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the switch position is watched, so toggling it cannot rebuild
    // anything else on this screen.
    final bool notificationsOn = context.select<NotificationProvider, bool>(
      (NotificationProvider p) => p.notificationsEnabled,
    );
    final bool hasPassword = context.select<AuthProvider, bool>(
      (AuthProvider a) => a.hasPasswordProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(AppStrings.settings, style: AppTextStyles.title),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            // NOTE: no `navBarClearance` here on purpose. Settings is pushed as
            // a full route on the root navigator, so the MainShell floating nav
            // bar is not on screen and there is nothing to clear — padding for
            // it would just leave a dead 96px gap under the last row.
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                AppDimensions.spaceL,
                context.pagePadding,
                AppDimensions.spaceXxl,
              ),
              children: [
                FadeSlideIn(
                  child: _SettingsGroup(
                    title: AppStrings.settingsPreferences,
                    children: [
                      _SwitchRow(
                        icon: Icons.notifications_none_rounded,
                        label: AppStrings.notifications,
                        subtitle: AppStrings.notificationsSubtitle,
                        value: notificationsOn,
                        onChanged: _setNotifications,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceL),

                FadeSlideIn(
                  delay: AppAnimations.staggerFor(1),
                  child: _SettingsGroup(
                    title: AppStrings.settingsAboutGroup,
                    children: [
                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        label: AppStrings.privacyPolicy,
                        onTap: () => _showLink(
                          AppStrings.privacyPolicy,
                          AppStrings.privacyPolicyUrl,
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.description_outlined,
                        label: AppStrings.termsOfService,
                        onTap: () => _showLink(
                          AppStrings.termsOfService,
                          AppStrings.termsUrl,
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        label: AppStrings.aboutApp,
                        onTap: () => showAppAboutDialog(context),
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceL),

                FadeSlideIn(
                  delay: AppAnimations.staggerFor(2),
                  child: _SettingsGroup(
                    title: AppStrings.settingsAccountGroup,
                    children: [
                      // A Google-only account has no password to change, so the
                      // row is hidden rather than leading to a form it can
                      // never satisfy — same rule Profile applies.
                      if (hasPassword)
                        _SettingsRow(
                          icon: Icons.lock_outline_rounded,
                          label: AppStrings.changePassword,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.changePassword,
                          ),
                        ),
                      _SettingsRow(
                        icon: Icons.delete_forever_outlined,
                        label: AppStrings.deleteAccount,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.deleteAccount,
                        ),
                        destructive: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceXl),
                Center(
                  child: Text(
                    '${AppStrings.appName} · v$kAppVersion',
                    style: AppTextStyles.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card grouping related settings rows.
///
/// Mirrors Profile's `_MenuGroup` so the two screens read as one system.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spaceXs,
            bottom: AppDimensions.spaceS,
          ),
          child: Text(title, style: AppTextStyles.label),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDimensions.brLg,
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: AppDimensions.brLg,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// The leading tinted icon tile shared by both row types.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.destructive});

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: destructive
            ? AppColors.error.withValues(alpha: 0.10)
            : AppColors.primaryFaint,
        borderRadius: AppDimensions.brSm,
      ),
      child: Icon(
        icon,
        size: 18,
        color: destructive ? AppColors.error : AppColors.primary,
      ),
    );
  }
}

/// A tappable settings row that navigates or opens a dialog.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Suppresses the trailing divider on the final row of a group.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color accent = destructive ? AppColors.error : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.08),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceL,
                vertical: AppDimensions.spaceM,
              ),
              child: Row(
                children: [
                  _RowIcon(icon: icon, destructive: destructive),
                  const SizedBox(width: AppDimensions.spaceM),
                  Expanded(
                    child: Text(
                      label,
                      style: destructive
                          ? AppTextStyles.body
                              .copyWith(color: AppColors.error)
                          : AppTextStyles.body,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color:
                        destructive ? AppColors.error : AppColors.textTertiary,
                    size: AppDimensions.iconMd,
                  ),
                ],
              ),
            ),
            if (!isLast) const _RowDivider(),
          ],
        ),
      ),
    );
  }
}

/// A settings row carrying a [Switch], with an explanatory subtitle.
///
/// The whole row is tappable (not just the switch) — a 36px thumb is a small
/// target, and users reach for the label.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceL,
                vertical: AppDimensions.spaceM,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowIcon(icon: icon, destructive: false),
                  const SizedBox(width: AppDimensions.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: AppTextStyles.body),
                        const SizedBox(height: AppDimensions.space2),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceS),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: AppColors.onPrimary,
                    activeTrackColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            if (!isLast) const _RowDivider(),
          ],
        ),
      ),
    );
  }
}

/// The hairline separator between rows in a group.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      color: AppColors.borderSoft,
    );
  }
}
