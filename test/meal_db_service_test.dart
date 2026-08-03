// Unit tests for MealDbService: the TheMealDB JSON -> Recipe adapter.
//
// A MockClient (package:http/testing.dart, part of the `http` package) returns
// canned TheMealDB bodies so the mapping is verified with no real network. The
// service deliberately produces NO fake data: unknown numeric fields (calories,
// cooking time, nutrition, servings) stay zero.

import 'dart:convert';

import 'package:ai_recipe_generator/core/error/failure.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A full meal body (search.php / lookup.php shape) with a couple of
/// ingredients, one blank slot to prove blanks are skipped, and multi-line
/// instructions.
String _fullMealBody() => jsonEncode(<String, dynamic>{
      'meals': <dynamic>[
        <String, dynamic>{
          'idMeal': '52795',
          'strMeal': 'Chicken Handi',
          'strCategory': 'Chicken',
          'strArea': 'Indian',
          'strMealThumb': 'https://img.themealdb.com/52795.jpg',
          'strInstructions': 'Heat oil.\nAdd chicken.\nSimmer until done.',
          'strIngredient1': 'Chicken',
          'strMeasure1': '1.2 kg',
          'strIngredient2': 'Yogurt',
          'strMeasure2': '400 g',
          'strIngredient3': '   ',
          'strMeasure3': '1 cup',
          'strTags': 'Curry,Spicy',
        },
      ],
    });

MealDbService _service(MockClient client) => MealDbService(client: client);

void main() {
  group('searchByName', () {
    test('maps a full meal into a Recipe with no fabricated numbers', () async {
      final service = _service(MockClient((http.Request request) async {
        expect(request.url.path, contains('search.php'));
        return http.Response(_fullMealBody(), 200);
      }));

      final List<Recipe> recipes = await service.searchByName('chicken');

      expect(recipes, hasLength(1));
      final Recipe r = recipes.single;
      expect(r.recipeId, '52795');
      expect(r.title, 'Chicken Handi');
      expect(r.imageUrl, 'https://img.themealdb.com/52795.jpg');
      expect(r.category, 'Chicken');

      // Ingredients built from strIngredientN/strMeasureN, blank slot skipped.
      expect(r.ingredients, hasLength(2));
      expect(r.ingredients[0].name, 'Chicken');
      expect(r.ingredients[0].quantity, '1.2 kg');
      expect(r.ingredients[1].name, 'Yogurt');

      // Instructions split into multiple steps.
      expect(r.instructions, hasLength(3));
      expect(r.instructions.first, 'Heat oil.');

      // No fake data: all numeric fields stay zero, nutrition all-zero.
      expect(r.calories, 0);
      expect(r.cookingTimeMinutes, 0);
      expect(r.servings, 0);
      expect(r.nutrition.protein, 0);
      expect(r.nutrition.carbs, 0);
      expect(r.nutrition.fat, 0);
      expect(r.nutrition.fiber, 0);
    });

    test('{"meals":null} yields an empty list (no crash)', () async {
      final service = _service(MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'meals': null}),
          200,
        );
      }));

      expect(await service.searchByName('zzz'), isEmpty);
    });

    test('non-200 throws NetworkFailure', () async {
      final service = _service(MockClient((http.Request request) async {
        return http.Response('server error', 500);
      }));

      await expectLater(
        service.searchByName('beef'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('filterByCategory', () {
    test('maps partial cards (title+image+id; ingredients empty)', () async {
      final service = _service(MockClient((http.Request request) async {
        expect(request.url.path, contains('filter.php'));
        return http.Response(
          jsonEncode(<String, dynamic>{
            'meals': <dynamic>[
              <String, dynamic>{
                'idMeal': '52768',
                'strMeal': 'Apple Frangipan Tart',
                'strMealThumb': 'https://img.themealdb.com/52768.jpg',
              },
            ],
          }),
          200,
        );
      }));

      final List<Recipe> recipes = await service.filterByCategory('Dessert');

      expect(recipes, hasLength(1));
      final Recipe r = recipes.single;
      expect(r.recipeId, '52768');
      expect(r.title, 'Apple Frangipan Tart');
      expect(r.imageUrl, 'https://img.themealdb.com/52768.jpg');
      expect(r.category, 'Dessert');
      expect(r.ingredients, isEmpty);
    });

    test('non-200 throws NetworkFailure', () async {
      final service = _service(MockClient((http.Request request) async {
        return http.Response('nope', 500);
      }));

      await expectLater(
        service.filterByCategory('Dessert'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('lookupById', () {
    test('returns a full Recipe', () async {
      final service = _service(MockClient((http.Request request) async {
        expect(request.url.path, contains('lookup.php'));
        return http.Response(_fullMealBody(), 200);
      }));

      final Recipe? r = await service.lookupById('52795');

      expect(r, isNotNull);
      expect(r!.title, 'Chicken Handi');
      expect(r.ingredients, isNotEmpty);
      expect(r.instructions, isNotEmpty);
    });

    test('returns null when meals is null', () async {
      final service = _service(MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'meals': null}),
          200,
        );
      }));

      expect(await service.lookupById('0'), isNull);
    });
  });
}
