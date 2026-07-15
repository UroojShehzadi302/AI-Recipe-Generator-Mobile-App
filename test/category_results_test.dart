// Unit tests for RecipeProvider's async category browse (M10) over TheMealDB.
//
// Category lists now come from the network: MealDbService.filterByCategory
// (partial cards) via RecipeRepository.getRecipesByCategory, and full detail
// via MealDbService.lookupById / RecipeRepository.getRecipeById. A MockClient
// (package:http/testing.dart) inspects the request path and returns canned
// TheMealDB JSON, so the tests are hermetic. They also assert the app->TheMealDB
// category MAP is applied (Desserts -> filter.php?c=Dessert).

import 'dart:convert';

import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A partial filter card (filter.php shape: id/title/thumb only).
Map<String, dynamic> _filterCard(String id, String name) => <String, dynamic>{
      'idMeal': id,
      'strMeal': name,
      'strMealThumb': 'https://img.themealdb.com/$id.jpg',
    };

/// A full meal (lookup.php shape) with ingredients + instructions.
Map<String, dynamic> _fullMeal(String id, String name, String category) =>
    <String, dynamic>{
      'idMeal': id,
      'strMeal': name,
      'strCategory': category,
      'strArea': 'French',
      'strMealThumb': 'https://img.themealdb.com/$id.jpg',
      'strInstructions': 'Mix.\nBake.\nCool.',
      'strIngredient1': 'Flour',
      'strMeasure1': '200 g',
      'strIngredient2': 'Sugar',
      'strMeasure2': '100 g',
    };

/// Records the last filter.php request URI so tests can assert the mapping.
class _CatClient {
  Uri? lastFilterUri;

  MockClient build() => MockClient((http.Request request) async {
        final String path = request.url.path;
        if (path.contains('filter.php')) {
          lastFilterUri = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'meals': <dynamic>[
                _filterCard('52768', 'Apple Frangipan Tart'),
                _filterCard('52893', 'Apple & Blackberry Crumble'),
              ],
            }),
            200,
          );
        }
        if (path.contains('lookup.php')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'meals': <dynamic>[
                _fullMeal('52768', 'Apple Frangipan Tart', 'Dessert'),
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode(<String, dynamic>{'meals': null}), 200);
      });
}

RecipeProvider _providerWith(http.Client client) => RecipeProvider(
      RecipeRepository(
        FirestoreService(),
        const UnconfiguredAiService(),
        MealDbService(client: client),
      ),
    );

void main() {
  group('RecipeProvider.loadCategory (async, TheMealDB-backed)', () {
    test('loads mapped category, relabels to app category, applies map',
        () async {
      final client = _CatClient();
      final provider = _providerWith(client.build());

      await provider.loadCategory('Desserts');

      expect(provider.categoryStatus, LoadStatus.loaded);
      expect(provider.categoryRecipes, isNotEmpty);
      // Repository re-labels each card back to the app category.
      expect(
        provider.categoryRecipes.every((r) => r.category == 'Desserts'),
        isTrue,
      );
      // The app->TheMealDB map was applied: Desserts -> filter.php?c=Dessert.
      expect(client.lastFilterUri, isNotNull);
      expect(client.lastFilterUri!.path, contains('filter.php'));
      expect(client.lastFilterUri!.query, contains('c=Dessert'));
    });

    test('unmapped category loads empty with no network call', () async {
      final client = _CatClient();
      final provider = _providerWith(client.build());

      await provider.loadCategory('For You');

      expect(provider.categoryStatus, LoadStatus.loaded);
      expect(provider.categoryRecipes, isEmpty);
      // Unmapped => repo returns [] without hitting filter.php.
      expect(client.lastFilterUri, isNull);
    });

    test('network error settles into error state', () async {
      final failing = MockClient((http.Request request) async {
        return http.Response('server error', 500);
      });
      final provider = _providerWith(failing);

      await provider.loadCategory('Desserts');

      expect(provider.categoryStatus, LoadStatus.error);
      expect(provider.categoryError, isNotNull);
    });
  });

  group('RecipeProvider.getRecipeDetails', () {
    test('resolves a full recipe via lookup.php', () async {
      final provider = _providerWith(_CatClient().build());

      final recipe = await provider.getRecipeDetails('52768');

      expect(recipe, isNotNull);
      expect(recipe!.title, 'Apple Frangipan Tart');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.instructions, isNotEmpty);
    });
  });
}
