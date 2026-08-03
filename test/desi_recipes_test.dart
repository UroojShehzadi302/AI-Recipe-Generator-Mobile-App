// Tests for the curated Pakistani ("desi") recipe set blended into the recipe
// data layer.
//
// Two things are verified here:
//   1. The curated data itself (DesiRecipes.all) is well-formed — 10 recipes,
//      all category 'Pakistani' / sourceType 'curated', full ingredients and
//      instructions, unique ids.
//   2. RecipeRepository serves the desi source correctly: the Pakistani-only
//      paths (category browse, id lookup, category-scoped search) are LOCAL and
//      never touch the network, while an uncategorised search PREPENDS the desi
//      matches to the TheMealDB results.
//
// The Pakistani-only assertions use a MockClient that throws on any request, so
// any accidental network call fails the test loudly (proving those paths are
// hermetic and offline-safe). Only the blended-search test needs a real canned
// response.

import 'dart:convert';

import 'package:ai_recipe_generator/core/constants/desi_recipes.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';
import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A MockClient that FAILS if it is ever called, and counts the attempts.
/// Used on the Pakistani-only paths to prove no network request is made.
class _NoNetworkClient {
  int calls = 0;

  MockClient build() => MockClient((http.Request request) async {
        calls++;
        throw StateError('Unexpected network call to ${request.url}');
      });
}

/// A MockClient returning a couple of unrelated TheMealDB meals for the
/// blended-search test (nothing that would itself match 'biryani').
class _BlendClient {
  int calls = 0;

  MockClient build() => MockClient((http.Request request) async {
        calls++;
        if (request.url.path.contains('search.php')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'meals': <dynamic>[
                <String, dynamic>{
                  'idMeal': '52940',
                  'strMeal': 'Beef Wellington',
                  'strCategory': 'Beef',
                  'strArea': 'British',
                  'strMealThumb': 'https://img.themealdb.com/52940.jpg',
                  'strInstructions': 'Sear.\nWrap.\nBake.',
                  'strIngredient1': 'Beef',
                  'strMeasure1': '1 kg',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode(<String, dynamic>{'meals': null}), 200);
      });
}

RecipeRepository _repoWith(http.Client client) => RecipeRepository(
      FirestoreService(),
      const UnconfiguredAiService(),
      MealDbService(client: client),
    );

void main() {
  group('DesiRecipes.all (curated data)', () {
    test('has exactly 10 recipes', () {
      expect(DesiRecipes.all, hasLength(10));
    });

    test('every recipe is Pakistani, curated, and fully populated', () {
      for (final Recipe r in DesiRecipes.all) {
        expect(r.category, 'Pakistani', reason: '${r.title} category');
        expect(r.sourceType, 'curated', reason: '${r.title} sourceType');
        expect(r.ingredients, isNotEmpty, reason: '${r.title} ingredients');
        expect(r.instructions, isNotEmpty, reason: '${r.title} instructions');
        expect(r.recipeId, isNotNull, reason: '${r.title} recipeId');
        expect(r.recipeId!.trim(), isNotEmpty, reason: '${r.title} recipeId');
      }
    });

    test('recipe ids are unique', () {
      final Iterable<String> ids =
          DesiRecipes.all.map((Recipe r) => r.recipeId!);
      expect(ids.toSet(), hasLength(DesiRecipes.all.length));
    });
  });

  group('RecipeRepository — Pakistani paths are local (no network)', () {
    test('getRecipesByCategory("Pakistani") returns all 10, zero network calls',
        () async {
      final client = _NoNetworkClient();
      final repo = _repoWith(client.build());

      final List<Recipe> list = await repo.getRecipesByCategory('Pakistani');

      expect(list, hasLength(10));
      expect(list.every((Recipe r) => r.category == 'Pakistani'), isTrue);
      expect(client.calls, 0);
    });

    test('getRecipeById("desi-chicken-biryani") resolves locally, no network',
        () async {
      final client = _NoNetworkClient();
      final repo = _repoWith(client.build());

      final Recipe? r = await repo.getRecipeById('desi-chicken-biryani');

      expect(r, isNotNull);
      expect(r!.title, 'Chicken Biryani');
      expect(r.ingredients, isNotEmpty);
      expect(r.instructions, isNotEmpty);
      expect(client.calls, 0);
    });

    test('searchRecipes("biryani", appCategory: "Pakistani") — desi only',
        () async {
      final client = _NoNetworkClient();
      final repo = _repoWith(client.build());

      final List<Recipe> results =
          await repo.searchRecipes('biryani', appCategory: 'Pakistani');

      expect(results, hasLength(1));
      expect(results.single.title, 'Chicken Biryani');
      expect(client.calls, 0);
    });

    test('searchRecipes is case-insensitive ("KARAHI" finds Chicken Karahi)',
        () async {
      final client = _NoNetworkClient();
      final repo = _repoWith(client.build());

      final List<Recipe> results =
          await repo.searchRecipes('KARAHI', appCategory: 'Pakistani');

      expect(results.map((Recipe r) => r.title), contains('Chicken Karahi'));
      expect(client.calls, 0);
    });
  });

  group('RecipeRepository — blended search (desi prepended to network)', () {
    test('searchRecipes("biryani") with no category includes the desi match',
        () async {
      final client = _BlendClient();
      final repo = _repoWith(client.build());

      final List<Recipe> results = await repo.searchRecipes('biryani');

      // The network client hit search.php (real blend, not the local path).
      expect(client.calls, greaterThan(0));
      // Curated desi dish is present (prepended) despite the network source not
      // returning it.
      expect(results.map((Recipe r) => r.title), contains('Chicken Biryani'));
      // And it comes first (prepended before the TheMealDB hits).
      expect(results.first.title, 'Chicken Biryani');
    });
  });

  group('RecipeProvider.loadCategory("Pakistani")', () {
    test('loads the 10 curated recipes hermetically', () async {
      final client = _NoNetworkClient();
      final provider = RecipeProvider(_repoWith(client.build()));

      await provider.loadCategory('Pakistani');

      expect(provider.categoryStatus, LoadStatus.loaded);
      expect(provider.categoryRecipes, hasLength(10));
      expect(
        provider.categoryRecipes.every((Recipe r) => r.category == 'Pakistani'),
        isTrue,
      );
      expect(client.calls, 0);
    });
  });
}
