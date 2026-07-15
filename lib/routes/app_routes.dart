import 'package:flutter/material.dart';

import '../models/recipe_model.dart';
import '../screens/category_results_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_screen.dart';
import '../screens/splash_screen.dart';

/// Central route table for the app.
///
/// Uses [onGenerateRoute] so routes can carry typed arguments (e.g. a `Recipe`
/// passed to the detail screen). Route names live here as constants; screens
/// that are not built yet resolve to a lightweight "coming soon" placeholder so
/// navigation never crashes on an unregistered name.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String recipeDetail = '/recipe';
  static const String search = '/search';
  static const String category = '/category';
  static const String favorites = '/favorites';
  static const String saved = '/saved';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';

  /// Resolves a [RouteSettings] into a [MaterialPageRoute].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _page(const SplashScreen(), settings);
      case login:
        return _page(const LoginScreen(), settings);
      case register:
        return _page(const RegisterScreen(), settings);
      case home:
        return _page(const MainShell(), settings);
      case forgotPassword:
        return _page(const ForgotPasswordScreen(), settings);
      case recipeDetail:
        final args = settings.arguments;
        if (args is Recipe) {
          return _page(RecipeDetailScreen(recipe: args), settings);
        }
        return _page(const _ComingSoon(routeName: recipeDetail), settings);
      case search:
        return _page(const SearchScreen(), settings);
      case category:
        final args = settings.arguments;
        if (args is String) {
          return _page(CategoryResultsScreen(category: args), settings);
        }
        return _page(const _ComingSoon(routeName: category), settings);
      default:
        // Route named but screen not built yet (arrives in its feature
        // milestone). Show a placeholder rather than throwing.
        return _page(_ComingSoon(routeName: settings.name), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}

/// Placeholder for routes whose screens are implemented in a later milestone.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('Coming soon${routeName != null ? '\n$routeName' : ''}',
            textAlign: TextAlign.center),
      ),
    );
  }
}
