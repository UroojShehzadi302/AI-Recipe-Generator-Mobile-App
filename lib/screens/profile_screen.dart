import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/about_dialog.dart';
import '../core/widgets/primary_button.dart';
import '../core/widgets/profile_avatar.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/usage_provider.dart';
import '../routes/app_routes.dart';

/// Profile tab — identity, activity stats, and account actions.
///
/// Layout: a brand-gradient identity header, a row of live activity stats
/// (Generated / Saved / Favorites), then a grouped settings menu and Log Out.
///
/// Counts come from the actually-loaded provider lists rather than the
/// server-maintained `UserModel` counters, which stay 0 until Cloud Functions
/// land. Menu rows that map to existing tabs switch to them via
/// [onNavigateTab]; the rest push real routes.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onNavigateTab});

  /// Switches the [MainShell] tab (0 Home · 1 Favorites · 2 AI · 3 Saved ·
  /// 4 Profile). Null when the screen is shown outside the shell.
  final ValueChanged<int>? onNavigateTab;

  /// The app version shown in the footer + About dialog (matches `pubspec`).
  ///
  /// Aliases [kAppVersion] so the footer here and the extracted About dialog
  /// can never disagree about which version is running.
  static const String appVersion = kAppVersion;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Warm the saved + history lists so the stat tiles show real numbers on
    // first open rather than counting up after the user visits other tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String? uid = context.read<AuthProvider>().uid;
      if (uid == null) return;
      final RecipeProvider recipes = context.read<RecipeProvider>();
      recipes.loadSaved(uid);
      recipes.loadHistory(uid);
    });
  }

  Future<void> _logout() async {
    final bool confirmed = await _confirmLogout() ?? false;
    if (!confirmed || !mounted) return;

    final AuthProvider auth = context.read<AuthProvider>();
    // Drop the loaded usage numbers before signing out, so the next user to
    // sign in on this device never sees the previous one's totals.
    context.read<UsageProvider>().reset();
    await auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<bool?> _confirmLogout() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your recipes.',
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
            child: const Text(AppStrings.logOut),
          ),
        ],
      ),
    );
  }

  void _goToTab(int index) {
    final ValueChanged<int>? navigate = widget.onNavigateTab;
    if (navigate != null) {
      navigate(index);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Open this from the bottom navigation'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final user = auth.user;
    final String name = (user?.name ?? '').trim();
    final String email = (user?.email ?? '').trim();

    final RecipeProvider recipes = context.watch<RecipeProvider>();

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppDimensions.spaceL,
              context.pagePadding,
              AppDimensions.navBarClearance,
            ),
            children: [
              Text(AppStrings.profile, style: AppTextStyles.screenTitle),
              const SizedBox(height: AppDimensions.spaceL),

              FadeSlideIn(
                child: _IdentityCard(
                  name: name,
                  email: email,
                  photoUrl: user?.photoUrl,
                  onEdit: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceL),
              const _EmailVerificationBanner(),

              FadeSlideIn(
                delay: AppAnimations.staggerFor(1),
                child: Row(
                  children: [
                    _StatTile(
                      label: 'Generated',
                      value: recipes.history.length,
                      icon: Icons.auto_awesome,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.history),
                    ),
                    const SizedBox(width: AppDimensions.spaceM),
                    _StatTile(
                      label: AppStrings.tabSaved,
                      value: recipes.saved.length,
                      icon: Icons.bookmark_rounded,
                      onTap: () => _goToTab(3),
                    ),
                    const SizedBox(width: AppDimensions.spaceM),
                    _StatTile(
                      label: AppStrings.tabFavorites,
                      value: recipes.favorites.length,
                      icon: Icons.favorite_rounded,
                      onTap: () => _goToTab(1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              _MenuGroup(
                title: 'Activity',
                children: [
                  _MenuRow(
                    icon: Icons.favorite_border_rounded,
                    label: AppStrings.myFavorites,
                    onTap: () => _goToTab(1),
                  ),
                  _MenuRow(
                    icon: Icons.bookmark_border_rounded,
                    label: AppStrings.savedRecipes,
                    onTap: () => _goToTab(3),
                  ),
                  _MenuRow(
                    icon: Icons.history_rounded,
                    label: AppStrings.usageHistory,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.history),
                  ),
                  _MenuRow(
                    icon: Icons.data_usage_rounded,
                    label: AppStrings.usageMenuLabel,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.usage),
                  ),
                  _MenuRow(
                    icon: Icons.auto_awesome,
                    label: AppStrings.tabAi,
                    onTap: () => _goToTab(2),
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceL),

              _MenuGroup(
                title: 'Account',
                children: [
                  _MenuRow(
                    icon: Icons.edit_outlined,
                    label: AppStrings.editProfile,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.editProfile),
                  ),
                  // Only password-backed accounts have a password to change; a
                  // Google-only account would land on a form it can never
                  // satisfy.
                  if (auth.hasPasswordProvider)
                    _MenuRow(
                      icon: Icons.lock_outline_rounded,
                      label: AppStrings.changePassword,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.changePassword,
                      ),
                    ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    label: AppStrings.settings,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    label: AppStrings.about,
                    onTap: () => showAppAboutDialog(context),
                  ),
                  _MenuRow(
                    icon: Icons.delete_forever_outlined,
                    label: AppStrings.deleteAccount,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.deleteAccount),
                    destructive: true,
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              PrimaryButton(
                text: AppStrings.logOut,
                icon: Icons.logout_rounded,
                variant: ButtonVariant.outlined,
                onPressed: _logout,
              ),

              const SizedBox(height: AppDimensions.spaceL),
              Center(
                child: Text(
                  '${AppStrings.appName} · v${ProfileScreen.appVersion}',
                  style: AppTextStyles.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gradient identity header: avatar, name, email, and an edit affordance.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppDimensions.brXl,
        boxShadow: AppShadows.glow(AppColors.primary, alpha: 0.28),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEdit,
            child: Stack(
              children: [
                ProfileAvatar(
                  radius: 34,
                  imageUrl: photoUrl,
                  fallbackInitial: name.isNotEmpty ? name[0] : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'Your Profile' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                Text(
                  email.isEmpty ? '—' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One activity stat, tappable through to the matching screen.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spaceL,
            horizontal: AppDimensions.spaceS,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDimensions.brLg,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppDimensions.iconMd,
                  color: AppColors.secondary),
              const SizedBox(height: AppDimensions.spaceS),
              Text(
                '$value',
                style: AppTextStyles.screenTitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.space2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card grouping related menu rows.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.children});

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

/// A single menu row. [destructive] tints it with the error colour so a
/// dangerous action never looks like an ordinary one.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: destructive
                          ? AppColors.error.withValues(alpha: 0.10)
                          : AppColors.primaryFaint,
                      borderRadius: AppDimensions.brSm,
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
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
                    color: destructive
                        ? AppColors.error
                        : AppColors.textTertiary,
                    size: AppDimensions.iconMd,
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 64,
                color: AppColors.borderSoft,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows an "unverified email" notice with a resend action, and disappears once
/// the address is confirmed.
///
/// Stateful on its own so the verified flag — which lives in the cached ID
/// token and is stale until the account is re-read from the server — can be
/// refreshed on mount. Without that refresh the banner would still be there
/// after the user clicked the link, which reads as broken.
///
/// Renders nothing for Google accounts (already verified) and nothing while the
/// first check is in flight, so a verified user never sees it flash.
class _EmailVerificationBanner extends StatefulWidget {
  const _EmailVerificationBanner();

  @override
  State<_EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<_EmailVerificationBanner> {
  bool _checking = true;
  bool _verified = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final bool verified = await auth.refreshEmailVerification();
    if (!mounted) return;
    setState(() {
      _verified = verified;
      _checking = false;
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final AuthProvider auth = context.read<AuthProvider>();
    final bool sent = await auth.resendEmailVerification();
    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Verification email sent — check your inbox.'
                : auth.errorMessage ?? 'Could not send the email.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _verified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceL),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceM),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: AppDimensions.brMd,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.primaryDark,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your email',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  Text(
                    'Confirm your address so you can recover your account if '
                    'you lose your password.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Wrap(
                    spacing: AppDimensions.spaceL,
                    children: [
                      TextButton(
                        onPressed: _sending ? null : _resend,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(_sending ? 'Sending…' : 'Resend email'),
                      ),
                      TextButton(
                        onPressed: _check,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("I've verified"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
