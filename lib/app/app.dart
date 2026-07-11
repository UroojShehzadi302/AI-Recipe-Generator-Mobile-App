import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/recipe_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/user_repository.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

/// Root widget: builds the dependency graph, provides the state layer, and
/// hosts the [MaterialApp].
///
/// The Services → Repositories → Providers wiring lives here so widgets never
/// construct Firebase/AI clients themselves. Providers are the only thing the
/// widget tree talks to.
class RecipeGeneratorApp extends StatelessWidget {
  const RecipeGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- Services (SDK seams) ---
    final authService = AuthService();
    final firestoreService = FirestoreService();
    const geminiService = GeminiService();

    // --- Repositories (domain boundary) ---
    final userRepository = UserRepository();
    final authRepository = AuthRepository(
      authService: authService,
      userRepository: userRepository,
    );
    final recipeRepository = RecipeRepository(firestoreService);
    final chatRepository = ChatRepository(gemini: geminiService);

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
