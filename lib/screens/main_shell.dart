import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/offline_banner.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recipe_provider.dart';
import 'ai_hub_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// Hosts the five main tabs behind the floating [AppBottomNav], with the AI
/// tab visually emphasized as the app's core feature.
///
/// Tabs are kept alive by an [IndexedStack] so switching between them never
/// discards scroll position or reloads data.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Observe lifecycle so notifications the FCM background isolate stored
    // while the app was backgrounded get merged into the inbox on resume.
    WidgetsBinding.instance.addObserver(this);
    // Warm the favorites list so Home hearts reflect saved state immediately,
    // and initialize push notifications (permission + FCM token + listeners).
    // Both run after the first frame so construction stays Firebase-free.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().uid;
      if (uid != null) {
        context.read<RecipeProvider>().loadFavorites(uid);
      }
      context.read<NotificationProvider>().init();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationProvider>().refresh();
      // Re-check connectivity on resume. This is the app's only non-request
      // recovery path: nothing polls, so a user who fixed their Wi-Fi while the
      // app was backgrounded would otherwise keep the banner until their next
      // successful request. The service rate-limits this, and it no-ops
      // entirely unless the status is actually in doubt.
      if (context.read<ConnectivityProvider>().isOffline) {
        context.read<ConnectivityProvider>().refresh();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenAi: () => _select(2)),
      const FavoritesScreen(),
      const AiHubScreen(),
      const SavedScreen(),
      ProfileScreen(onNavigateTab: _select),
    ];

    return Scaffold(
      // The nav bar floats, so the body runs full-bleed behind it. Scrollable
      // tab content pads itself by AppDimensions.navBarClearance so the last
      // item still clears the bar.
      extendBody: true,
      // One warm background gradient for every tab, set here rather than in
      // each screen so they can't drift apart.
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        // The offline strip sits ABOVE the tabs rather than floating over them.
        // Overlaying it would cover the top of whichever screen is showing —
        // on Home that is the greeting and the notification bell. Taking 36dp
        // of layout height instead pushes content down honestly, and because
        // the banner collapses to zero height when online it costs nothing in
        // the normal case.
        //
        // ⚠️ It is deliberately NOT inside the nav bar's territory: the bar
        // floats over the body via `extendBody: true`, and every tab pads its
        // own scrollable by `navBarClearance`. Adding anything at the bottom
        // here would break that arrangement.
        child: Column(
          children: [
            // Top-only SafeArea: the strip must clear the status bar/notch, but
            // the tabs below manage their own bottom inset.
            const SafeArea(
              bottom: false,
              child: OfflineBanner(),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onSelect: _select,
        destinations: _destinations,
      ),
    );
  }

  /// The five tabs, in shell order (Home · Favorites · AI · Saved · Profile).
  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: AppStrings.tabHome,
    ),
    NavDestination(
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: AppStrings.tabFavorites,
    ),
    NavDestination(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: AppStrings.tabAi,
      emphasized: true,
    ),
    NavDestination(
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
      label: AppStrings.tabSaved,
    ),
    NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: AppStrings.tabProfile,
    ),
  ];
}
