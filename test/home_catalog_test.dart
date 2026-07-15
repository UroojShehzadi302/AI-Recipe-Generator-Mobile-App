// Unit tests for RecipeProvider.loadHomeCatalog — the live Home rails.
//
// The Home tab's rails come from the live catalog: two network categories
// (Popular -> Dinner/Beef, Quick -> Breakfast) via
// RecipeRepository.getRecipesByCategory, plus the curated local Pakistani
// (desi) set. A MockClient returns canned TheMealDB filter.php JSON so the
// tests are hermetic, and asserts that:
//   * the desi rail is populated from the LOCAL curated set (never empty),
//   * the two network rails load and are re-labelled to their app category,
//   * a network failure still leaves the desi rail populated (offline-safe).

import 'dart:convert';

import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _filterCard(String id, String name) => <String, dynamic>{
      'idMeal': id,
      'strMeal': name,
      'strMealThumb': 'https://img.themealdb.com/$id.jpg',
    };

/// A MockClient that returns two partial cards for any filter.php request.
MockClient _filterClient() => MockClient((http.Request request) async {
      if (request.url.path.contains('filter.php')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'meals': <dynamic>[
              _filterCard('1001', 'Beef Wellington'),
              _filterCard('1002', 'Full English Breakfast'),
            ],
          }),
          200,
        );
      }
      return http.Response(jsonEncode(<String, dynamic>{'meals': null}), 200);
    });

RecipeProvider _providerWith(http.Client client) => RecipeProvider(
      RecipeRepository(
        FirestoreService(),
        const UnconfiguredAiService(),
        MealDbService(client: client),
      ),
    );

void main() {
  group('RecipeProvider.loadHomeCatalog', () {
    test('populates desi + both live rails on success', () async {
      final provider = _providerWith(_filterClient());

      await provider.loadHomeCatalog();

      expect(provider.homeCatalogStatus, LoadStatus.loaded);
      // Desi rail comes from the curated local Pakistani set.
      expect(provider.desiRail, isNotEmpty);
      expect(
        provider.desiRail.every((r) => r.category == 'Pakistani'),
        isTrue,
      );
      // Live network rails loaded and were re-labelled to their app category.
      expect(provider.popularRail, isNotEmpty);
      expect(provider.quickRail, isNotEmpty);
      expect(provider.popularRail.every((r) => r.category == 'Dinner'), isTrue);
      expect(provider.quickRail.every((r) => r.category == 'Breakfast'), isTrue);
    });

    test('no-ops once loaded; forced reload keeps rails populated', () async {
      var filterCalls = 0;
      final counting = MockClient((http.Request request) async {
        if (request.url.path.contains('filter.php')) {
          filterCalls++;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'meals': <dynamic>[_filterCard('1', 'A')],
            }),
            200,
          );
        }
        return http.Response(jsonEncode(<String, dynamic>{'meals': null}), 200);
      });
      final provider = _providerWith(counting);

      await provider.loadHomeCatalog();
      final callsAfterFirst = filterCalls;

      // Second plain call is guarded by the loaded state — no work at all.
      await provider.loadHomeCatalog();
      expect(filterCalls, callsAfterFirst);

      // A forced reload re-runs the load and keeps the rails populated. The
      // repository caches category results for the session, so this serves from
      // cache rather than issuing new network calls — the state stays loaded.
      await provider.retryHomeCatalog();
      expect(provider.homeCatalogStatus, LoadStatus.loaded);
      expect(provider.popularRail, isNotEmpty);
      expect(provider.quickRail, isNotEmpty);
    });

    test('network failure keeps a usable, populated Home (curated seed)',
        () async {
      final failing = MockClient((http.Request request) async {
        return http.Response('server error', 500);
      });
      final provider = _providerWith(failing);

      await provider.loadHomeCatalog();

      // Never gets stuck: the curated seed leaves Home loaded and populated.
      expect(provider.homeCatalogStatus, LoadStatus.loaded);
      // Curated desi set is local, so it survives the network failure.
      expect(provider.desiRail, isNotEmpty);
      // Popular / Quick fall back to the curated sample rails.
      expect(provider.popularRail, isNotEmpty);
      expect(provider.quickRail, isNotEmpty);
    });
  });
}
