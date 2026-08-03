import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/ai_config.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_scroll_behavior.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/usage_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/usage_repository.dart';
import '../repositories/user_repository.dart';
import '../routes/app_routes.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_direct_service.dart';
import '../services/meal_db_service.dart';
import '../services/notification_service.dart';
import '../services/unconfigured_ai_service.dart';

/// Root widget: builds the dependency graph, provides the state layer, and
/// hosts the [MaterialApp].
///
/// The Services → Repositories → Providers wiring lives here so widgets never
/// construct Firebase/AI clients themselves. Providers are the only thing the
/// widget tree talks to.
class RecipeGeneratorApp extends StatelessWidget {
  const RecipeGeneratorApp({super.key, required this.aiConfig});

  /// AI key/model resolved at startup by [AiConfig.load] (from `env.json`).
  final AiConfig aiConfig;

  @override
  Widget build(BuildContext context) {
    // --- Services (SDK seams) ---
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final mealDbService = MealDbService();
    final notificationService = NotificationService();

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(recipeRepository),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(chatRepository),
        ),
        ChangeNotifierProvider<UsageProvider>(
          create: (_) => UsageProvider(usageRepository),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          // Construction is Firebase-free; init() is called after the first
          // frame by the widget tree (see MainShell) so tests stay safe.
          create: (_) => NotificationProvider(notificationService),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        // One scroll behavior for the whole app: bouncing physics + a stretch
        // overscroll indicator, so every list feels the same without each
        // scrollable setting `physics:` itself.
        scrollBehavior: const AppScrollBehavior(),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
