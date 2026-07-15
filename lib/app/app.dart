import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/ai_config.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/recipe_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/user_repository.dart';
import '../routes/app_routes.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_direct_service.dart';
import '../services/meal_db_service.dart';
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

    // AI: use the direct Gemini Developer API when a key is configured;
    // otherwise a no-op service so AI features degrade to a friendly "coming
    // soon". Swapping this single line to a Cloud Functions-backed AiService
    // later leaves repos/providers/UI unchanged.
    final AiService aiService = aiConfig.isConfigured
        ? GeminiDirectService(aiConfig)
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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AI Recipe Generator',
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
