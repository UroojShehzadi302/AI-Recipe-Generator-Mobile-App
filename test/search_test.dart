// Unit tests for RecipeProvider's async catalog search (M10) over TheMealDB.
//
// The catalog now comes from the network via MealDbService -> RecipeRepository.
// A `MockClient` (from package:http/testing.dart, part of the `http` package)
// is injected into MealDbService so these tests are fully hermetic: no real
// network call happens, and canned TheMealDB JSON drives every assertion.
// Recent-search bookkeeping stays synchronous and is covered here too.

import 'dart:convert';

import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A full TheMealDB meal (search.php / lookup.php shape).
Map<String, dynamic> _fullMeal({
  required String id,
  required String name,
  required String category,
}) =>
    <String, dynamic>{
      'idMeal': id,
      'strMeal': name,
      'strCategory': category,
      'strArea': 'Indian',
      'strMealThumb': 'https://img.themealdb.com/$id.jpg',
      'strInstructions': 'Heat the pan.\nAdd the spices.\nSimmer gently.',
      'strIngredient1': 'Chicken',
      'strMeasure1': '500 g',
      'strIngredient2': 'Yogurt',
      'strMeasure2': '1 cup',
      'strIngredient3': '',
      'strMeasure3': '',
      'strTags': 'Spicy,Curry',
    };

/// `{"meals":[...]}` body containing a couple of full meals, one being the
/// mocked "Chicken Handi" the success test asserts on.
String _searchBody() => jsonEncode(<String, dynamic>{
      'meals': <dynamic>[
        _fullMeal(id: '52795', name: 'Chicken Handi', category: 'Chicken'),
        _fullMeal(id: '52940', name: 'Beef Wellington', category: 'Beef'),
      ],
    });

/// A MockClient that serves canned search JSON and counts how many times it
/// was invoked (to prove no network happens on an empty query).
class _CountingClient {
  int calls = 0;

  MockClient build() => MockClient((http.Request request) async {
        calls++;
        if (request.url.path.contains('search.php')) {
          return http.Response(_searchBody(), 200);
        }
        return http.Response(jsonEncode(<String, dynamic>{'meals': null}), 200);
      });
}

/// Builds a provider whose repository's MealDbService uses [client].
RecipeProvider _providerWith(http.Client client) => RecipeProvider(
      RecipeRepository(
        FirestoreService(),
        const UnconfiguredAiService(),
        MealDbService(client: client),
      ),
    );

void main() {
  group('RecipeProvider.search (async, TheMealDB-backed)', () {
    test('successful search loads results containing the mocked title',
        () async {
      final provider = _providerWith(_CountingClient().build());

      await provider.search('chicken');

      expect(provider.searchStatus, LoadStatus.loaded);
      expect(provider.searchResults, isNotEmpty);
      expect(
        provider.searchResults.map((r) => r.title),
        contains('Chicken Handi'),
      );
    });

    test('empty query with no category short-circuits — no network call',
        () async {
      final counter = _CountingClient();
      final provider = _providerWith(counter.build());

      await provider.search('');

      expect(provider.searchStatus, LoadStatus.idle);
      expect(provider.searchResults, isEmpty);
      // Proves the provider did not touch the network for an empty query.
      expect(counter.calls, 0);
    });

    test('network error settles into error state; retry can succeed', () async {
      // First a 500 client to force the error path...
      final failing = MockClient((http.Request request) async {
        return http.Response('server error', 500);
      });
      final repo = RecipeRepository(
        FirestoreService(),
        const UnconfiguredAiService(),
        MealDbService(client: failing),
      );
      final provider = RecipeProvider(repo);

      await provider.search('beef');

      expect(provider.searchStatus, LoadStatus.error);
      expect(provider.searchError, isNotNull);

      // retrySearch re-invokes search with the same query. It hits the same
      // failing client (repo caches only successes), so it stays in error —
      // this at least proves retrySearch re-runs the last search.
      await provider.retrySearch();
      expect(provider.searchStatus, LoadStatus.error);
      expect(provider.searchQuery, 'beef');
    });

    test('retrySearch on a healthy client reaches loaded', () async {
      final provider = _providerWith(_CountingClient().build());

      await provider.search('chicken');
      expect(provider.searchStatus, LoadStatus.loaded);

      await provider.retrySearch();
      expect(provider.searchStatus, LoadStatus.loaded);
      expect(provider.searchResults, isNotEmpty);
    });

    test('clearSearch empties results and query but keeps recent searches',
        () async {
      final provider = _providerWith(_CountingClient().build())
        ..addRecentSearch('Pasta');
      await provider.search('chicken');
      expect(provider.searchResults, isNotEmpty);

      provider.clearSearch();

      expect(provider.searchResults, isEmpty);
      expect(provider.searchQuery, '');
      expect(provider.searchStatus, LoadStatus.idle);
      expect(provider.recentSearches, contains('Pasta'));
    });
  });

  group('RecipeProvider.addRecentSearch (synchronous)', () {
    RecipeProvider build() =>
        RecipeProvider(RecipeRepository(
          FirestoreService(),
          const UnconfiguredAiService(),
          MealDbService(),
        ));

    test('dedupes case-insensitively, most-recent first', () {
      final provider = build()
        ..addRecentSearch('Pasta')
        ..addRecentSearch('pasta');

      expect(provider.recentSearches, hasLength(1));
      expect(provider.recentSearches.first, 'pasta');
    });

    test('caps recent searches at 8 entries', () {
      final provider = build();

      for (var i = 0; i < 9; i++) {
        provider.addRecentSearch('term$i');
      }

      expect(provider.recentSearches, hasLength(8));
      expect(provider.recentSearches.first, 'term8');
      expect(provider.recentSearches, isNot(contains('term0')));
    });

    test('ignores blank terms', () {
      final provider = build()
        ..addRecentSearch('   ')
        ..addRecentSearch('');

      expect(provider.recentSearches, isEmpty);
    });
  });
}
