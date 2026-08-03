// Widget smoke test for the AI Hub (Generate | Chat) tab.
//
// Uses an UnconfiguredAiService so no network call happens; the test only
// verifies the UI scaffolding renders and the mode toggle switches views.

import 'package:ai_recipe_generator/core/theme/app_theme.dart';
import 'package:ai_recipe_generator/providers/chat_provider.dart';
import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/chat_repository.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/screens/ai_hub_screen.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AI Hub renders both modes and toggles between them',
      (tester) async {
    const ai = UnconfiguredAiService();
    final recipeProvider =
        RecipeProvider(RecipeRepository(FirestoreService(), ai, MealDbService()));
    final chatProvider = ChatProvider(ChatRepository(ai: ai));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RecipeProvider>.value(value: recipeProvider),
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AiHubScreen(),
        ),
      ),
    );
    await tester.pump();

    // Header + both toggle segments present; Generate is the default view.
    expect(find.text('AI Kitchen'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('GENERATE RECIPE'), findsOneWidget);

    // Switch to Chat mode → the empty-state assistant intro appears.
    await tester.tap(find.text('Chat'));
    await tester.pump();
    expect(find.text('Your cooking assistant'), findsOneWidget);
  });
}
