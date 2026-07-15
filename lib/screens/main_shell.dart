import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import 'ai_hub_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// Hosts the five main tabs behind a custom bottom navigation bar, with the
/// AI tab visually highlighted as the app's core feature.
///
/// Tabs other than Home and Profile are placeholders until their feature
/// milestones (Favorites/Saved M8, AI Generator M6).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Warm the favorites list so Home hearts reflect saved state immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().uid;
      if (uid != null) {
        context.read<RecipeProvider>().loadFavorites(uid);
      }
    });
  }

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenAi: () => _select(2)),
      const FavoritesScreen(),
      const AiHubScreen(),
      const SavedScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomNav(index: _index, onSelect: _select),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _item(0, Icons.home_rounded, 'Home'),
              _item(1, Icons.favorite_border, 'Favorites'),
              _aiItem(2),
              _item(3, Icons.bookmark_border, 'Saved'),
              _item(4, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final selected = index == i;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => onSelect(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Center AI action — always visually emphasized as the core feature.
  Widget _aiItem(int i) {
    final selected = index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                        alpha: selected ? 0.5 : 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 3),
            const Text(
              'Ask AI',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
