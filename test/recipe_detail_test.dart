import 'package:ai_recipe_generator/core/constants/sample_recipes.dart';
import 'package:ai_recipe_generator/core/theme/app_theme.dart';
import 'package:ai_recipe_generator/providers/auth_provider.dart';
import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/auth_repository.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/repositories/user_repository.dart';
import 'package:ai_recipe_generator/screens/recipe_detail_screen.dart';
import 'package:ai_recipe_generator/services/auth_service.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('RecipeDetailScreen renders title, sections and action bar',
      (tester) async {
    // Services/repositories now resolve Firebase lazily, so they can be
    // constructed in a widget test. The detail screen's build path only reads
    // in-memory state (RecipeProvider.isFavorite), so no Firebase call occurs.
    final recipeProvider = RecipeProvider(
      RecipeRepository(
        FirestoreService(),
        const UnconfiguredAiService(),
        MealDbService(),
      ),
    );
    final authProvider = AuthProvider(
      AuthRepository(
        authService: AuthService(),
        userRepository: UserRepository(),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RecipeProvider>.value(value: recipeProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: RecipeDetailScreen(recipe: SampleRecipes.popular.first),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Creamy Mushroom Chicken'), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Instructions'), findsOneWidget);
    expect(find.text('SAVE RECIPE'), findsOneWidget);
  });
}
