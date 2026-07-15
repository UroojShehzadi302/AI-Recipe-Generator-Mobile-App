import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/primary_button.dart';
import '../core/widgets/profile_avatar.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../routes/app_routes.dart';

/// Profile tab — user info and account actions.
///
/// Shows the signed-in user's identity, sign-in method, and Favorites/Saved
/// counts, a menu of account actions, and a Log Out action (with a confirm
/// dialog). Menu rows that map to existing tabs switch to them via
/// [onNavigateTab]; the rest are honestly marked as arriving in M11.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onNavigateTab});

  /// Switches the [MainShell] tab (0 Home · 1 Favorites · 2 AI · 3 Saved ·
  /// 4 Profile). Null when the screen is shown outside the shell.
  final ValueChanged<int>? onNavigateTab;

  /// The app version shown in the footer + About dialog (matches `pubspec`).
  static const String _appVersion = '1.0.0';

  Future<void> _logout(BuildContext context) async {
    final bool confirmed = await _confirmLogout(context) ?? false;
    if (!confirmed || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brLg),
        title: const Text('Log out?', style: AppTextStyles.title),
        content: const Text(
          'You will need to sign in again to access your recipes.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToTab(BuildContext context, int index) {
    if (onNavigateTab != null) {
      onNavigateTab!(index);
    } else {
      _comingSoon(context, 'Open this from the bottom navigation');
    }
  }

  /// A custom About dialog — no "View licenses" button (unlike the framework
  /// [showAboutDialog]).
  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brLg),
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: AppColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('AI Recipe Generator', style: AppTextStyles.title),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover, generate, and save recipes with an AI cooking '
              'assistant.',
              style: AppTextStyles.subtitle,
            ),
            SizedBox(height: 12),
            Text('Version $_appVersion', style: AppTextStyles.caption),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = (user?.name ?? '').trim();
    final email = (user?.email ?? '').trim();

    // Live counts from the actual loaded lists — the server-maintained
    // UserModel counters stay 0 until Cloud Functions land, so use the real
    // Firestore data (warmed by MainShell / the Favorites + Saved tabs).
    final recipe = context.watch<RecipeProvider>();
    final int favoritesCount = recipe.favorites.length;
    final int savedCount = recipe.saved.length;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              20,
              context.pagePadding,
              24,
            ),
            children: [
              const _Header(title: 'Profile'),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                  child: ProfileAvatar(
                    radius: 48,
                    imageUrl: user?.photoUrl,
                    fallbackInitial: name.isNotEmpty ? name[0] : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name.isEmpty ? 'Your Profile' : name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  email.isEmpty ? '—' : email,
                  style: AppTextStyles.subtitle,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _statCard(
                    'Favorites',
                    favoritesCount,
                    Icons.favorite,
                    () => _goToTab(context, 1),
                  ),
                  const SizedBox(width: 14),
                  _statCard(
                    'Saved',
                    savedCount,
                    Icons.bookmark,
                    () => _goToTab(context, 3),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _menuSection(context),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'LOG OUT',
                onPressed: () => _logout(context),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Version $_appVersion', style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.secondary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _menuRow(
            Icons.favorite_border,
            'My Favorites',
            () => _goToTab(context, 1),
          ),
          _divider(),
          _menuRow(
            Icons.bookmark_border,
            'Saved Recipes',
            () => _goToTab(context, 3),
          ),
          _divider(),
          _menuRow(
            Icons.auto_awesome,
            'Ask AI',
            () => _goToTab(context, 2),
          ),
          _divider(),
          _menuRow(
            Icons.edit_outlined,
            'Edit Profile',
            () => Navigator.pushNamed(context, AppRoutes.editProfile),
          ),
          _divider(),
          _menuRow(
            Icons.info_outline,
            'About',
            () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: AppColors.border,
      );
}

/// The screen's leading title row (matches the Favorites/Saved tab headers).
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
