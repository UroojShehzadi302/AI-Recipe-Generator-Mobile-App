import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/ai_config.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_scroll_behavior.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/text_scale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/usage_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/usage_repository.dart';
import '../repositories/user_repository.dart';
import '../routes/app_routes.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_direct_service.dart';
import '../services/meal_db_service.dart';
import '../services/notification_service.dart';
import '../services/platform_share_service.dart';
import '../services/probe_connectivity_service.dart';
import '../services/share_service.dart';
import '../services/unconfigured_ai_service.dart';

/// Root widget: builds the dependency graph, provides the state layer, and
/// hosts the [MaterialApp].
///
/// The Services → Repositories → Providers wiring lives here so widgets never
/// construct Firebase/AI clients themselves. Providers are the only thing the
/// widget tree talks to.
class RecipeGeneratorApp extends StatelessWidget {
  const RecipeGeneratorApp({
    super.key,
    required this.aiConfig,
    this.themeProvider,
    this.textScaleProvider,
  });

  /// AI key/model resolved at startup by [AiConfig.load] (from `env.json`).
  final AiConfig aiConfig;

  /// The theme controller, pre-loaded in `main()` so the stored preference is
  /// applied before the first frame rather than flashing light and correcting
  /// itself. Optional: tests and any caller that does not care get a default
  /// system-mode controller.
  final ThemeProvider? themeProvider;

  /// The text size controller, pre-loaded in `main()` for the same reason
  /// [themeProvider] is: resolving it after the first frame would render one
  /// frame at the default size and then reflow the whole app. Optional — tests
  /// and any caller that does not care get a default medium controller.
  final TextScaleProvider? textScaleProvider;

  @override
  Widget build(BuildContext context) {
    // --- Services (SDK seams) ---
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final mealDbService = MealDbService();
    final notificationService = NotificationService();

    // Sharing. Uses Flutter's built-in `Share.invoke` platform channel with a
    // clipboard fallback, so it needs no third-party package. Swapping this one
    // line to a `share_plus`-backed implementation later leaves the UI
    // untouched — RecipeDetailScreen depends on the ShareService interface.
    const ShareService shareService = PlatformShareService();

    // Connectivity. Dependency-free: it learns from the app's OWN request
    // failures and confirms with a DNS lookup, so in the normal case it makes
    // no network call at all. Swapping this one line to a `connectivity_plus`-
    // backed implementation later leaves the provider, the banner, and every
    // screen untouched — see the TODO box in probe_connectivity_service.dart.
    final ConnectivityService connectivityService = ProbeConnectivityService();

    // Usage accounting. Built before the AI service because it IS the sink the
    // service reports token costs to. The uid is read lazily per call (rather
    // than captured now) so sign-in/sign-out can never leave it stale.
    final usageRepository = UsageRepository(
      firestoreService,
      currentUid: () => authService.currentUser?.uid,
    );

    // AI: use the direct Gemini Developer API when a key is configured;
    // otherwise a no-op service so AI features degrade to a friendly "coming
    // soon". Swapping this single line to a Cloud Functions-backed AiService
    // later leaves repos/providers/UI unchanged.
    final AiService aiService = aiConfig.isConfigured
        ? GeminiDirectService(aiConfig, usageSink: usageRepository)
        : const UnconfiguredAiService();

    // --- Repositories (domain boundary) ---
    final userRepository = UserRepository();
    final authRepository = AuthRepository(
      authService: authService,
      userRepository: userRepository,
    );
    final recipeRepository =
        RecipeRepository(firestoreService, aiService, mealDbService);
    final chatRepository = ChatRepository(ai: aiService);

    // --- Providers (UI state) ---
    //
    // Built here rather than inside the MultiProvider entry below because the
    // two AI providers need the SAME instance: they feed request outcomes into
    // it (which is how the app detects an outage for free) and read its verdict
    // to word their errors. A `create:` closure would be lazy and could hand
    // out a second instance.
    final connectivityProvider = ConnectivityProvider(connectivityService);
    return MultiProvider(
      providers: [
        // Plain value, not a ChangeNotifier: sharing is stateless, so nothing
        // ever rebuilds because of it. Screens read it with `context.read`.
        Provider<ShareService>.value(value: shareService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(
            recipeRepository,
            connectivity: connectivityProvider,
          ),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            chatRepository,
            connectivity: connectivityProvider,
          ),
        ),
        ChangeNotifierProvider<UsageProvider>(
          create: (_) => UsageProvider(usageRepository),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          // Construction is Firebase-free; init() is called after the first
          // frame by the widget tree (see MainShell) so tests stay safe.
          create: (_) => NotificationProvider(notificationService),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => themeProvider ?? ThemeProvider(),
        ),
        // `.value` because the instance is shared with the two AI providers
        // above — see the note where it is constructed. MultiProvider does not
        // dispose a `.value` notifier, which is correct here: this one lives as
        // long as the app does.
        ChangeNotifierProvider<ConnectivityProvider>.value(
          value: connectivityProvider,
        ),
        ChangeNotifierProvider<TextScaleProvider>(
          create: (_) => textScaleProvider ?? TextScaleProvider(),
        ),
      ],
      // Watches both display preferences so a change to either rebuilds
      // MaterialApp. Without this the widget would be built once and the app
      // would keep whatever theme and text size it started with.
      child: Consumer2<ThemeProvider, TextScaleProvider>(
        builder: (
          BuildContext context,
          ThemeProvider themeProvider,
          TextScaleProvider textScale,
          _,
        ) {
          // Keep the global palette in step with the OS when following the
          // system theme. MaterialApp rebuilds on a platform brightness change
          // but AppPalette is not reactive, so it has to be re-resolved here —
          // before the subtree below reads any AppColors getter.
          themeProvider.syncWithPlatformBrightness(
            MediaQuery.platformBrightnessOf(context),
          );

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.mode,
            // One scroll behavior for the whole app: bouncing physics + a
            // stretch overscroll indicator, so every list feels the same
            // without each scrollable setting `physics:` itself.
            scrollBehavior: const AppScrollBehavior(),
            // Applies the user's text size to every Text in the app — including
            // Material's own dialogs, snackbars and tooltips, which never touch
            // AppTextStyles. `builder` runs INSIDE MaterialApp, above the
            // navigator, so routes and overlays (dialogs, bottom sheets) all
            // inherit it; wrapping MaterialApp from the outside would leave
            // anything pushed onto the root overlay unscaled.
            //
            // The scaler already in the tree here is the OS setting, and it is
            // multiplied rather than replaced — see TextScaleProvider for why
            // that is the accessible choice, and for the clamp that keeps the
            // product from compounding into an unusable size.
            builder: (BuildContext context, Widget? child) {
              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: textScale.scalerFor(media.textScaler),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
