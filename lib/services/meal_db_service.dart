// Temporary curated-catalog service backed by the free **TheMealDB API**.
//
// Development-phase source for real recipe content (Option A) while the curated
// Firestore feed (Decision 1) is not yet built. This is the ONLY place that
// knows TheMealDB exists: its base URL, endpoints, JSON shapes, and the adapter
// that maps those shapes into the app's own [Recipe] model live here. Callers
// (the [RecipeRepository]) only ever see [Recipe]s and domain [Failure]s — a
// TheMealDB map never escapes this file.
//
// Endpoint notes:
// - `search.php?s=` and `lookup.php?i=` return FULL meals (all fields), mapped
//   via [_mapFullMeal].
// - `filter.php?c=` returns PARTIAL cards (id/title/thumb only), mapped via
//   [_mapFilterItem]; a caller that needs full detail resolves a card to a full
//   meal with [lookupById].
//
// Migration: when the curated Firestore catalog lands, this service is dropped
// and the repository's catalog methods (identical signatures) point at it
// instead — providers/UI are untouched.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/error/failure.dart';
import '../models/recipe_model.dart';

/// Direct-to-TheMealDB adapter returning the app's [Recipe] model.
class MealDbService {
  /// Creates a [MealDbService].
  ///
  /// [client] is injectable for tests (defaults to a fresh [http.Client]).
  /// [timeout] bounds each request. TheMealDB's public test key (`1`) needs no
  /// credentials, so there is no key/header to configure.
  MealDbService({
    http.Client? client,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration _timeout;

  /// Base URL of TheMealDB v1 test API.
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Searches meals by [query] (`search.php?s=`), returning fully-mapped
  /// [Recipe]s. An empty/no-match response yields `const <Recipe>[]`.
  Future<List<Recipe>> searchByName(String query) async {
    final Uri uri =
        Uri.parse('$_baseUrl/search.php?s=${Uri.encodeQueryComponent(query)}');
    final Map<String, dynamic> json = await _getJson(uri);
    return _mapMeals(json, _mapFullMeal);
  }

  /// Filters meals by TheMealDB category [mealDbCategory] (`filter.php?c=`).
  ///
  /// The endpoint returns PARTIAL cards (id/title/thumb only); each is mapped
  /// via [_mapFilterItem] with its category set to [mealDbCategory]. Callers
  /// resolve a card to a full recipe with [lookupById]. No matches -> empty.
  Future<List<Recipe>> filterByCategory(String mealDbCategory) async {
    final Uri uri = Uri.parse(
        '$_baseUrl/filter.php?c=${Uri.encodeQueryComponent(mealDbCategory)}');
    final Map<String, dynamic> json = await _getJson(uri);
    return _mapMeals(
      json,
      (Map<String, dynamic> meal) => _mapFilterItem(meal, mealDbCategory),
    );
  }

  /// Looks up a single full meal by TheMealDB [id] (`lookup.php?i=`), mapped via
  /// [_mapFullMeal]. Returns `null` when no meal matches.
  Future<Recipe?> lookupById(String id) async {
    final Uri uri = Uri.parse('$_baseUrl/lookup.php?i=${Uri.encodeQueryComponent(id)}');
    final Map<String, dynamic> json = await _getJson(uri);
    final Object? meals = json['meals'];
    if (meals is! List || meals.isEmpty) return null;
    final Object? first = meals.first;
    if (first is! Map) return null;
    return _mapFullMeal(Map<String, dynamic>.from(first));
  }

  // ---------------------------------------------------------------------------
  // HTTP (mirrors gemini_direct_service: injectable client, timeout, domain
  // Failure on any transport/timeout/decode error — never a raw exception).
  // ---------------------------------------------------------------------------

  /// GETs [uri] and decodes a JSON object. Throws [NetworkFailure] on any
  /// transport error, timeout, non-200 status, or unexpected/undecodable body
  /// (TheMealDB has no useful error bodies to distinguish further).
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const NetworkFailure();
    } catch (_) {
      // Socket/DNS/connection errors.
      throw const NetworkFailure();
    }

    if (response.statusCode != 200) {
      throw const NetworkFailure();
    }

    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw const NetworkFailure();
    } on FormatException {
      throw const NetworkFailure();
    }
  }

  /// Maps the `meals` array of a response with [map], or `const <Recipe>[]` when
  /// it is `null`/absent/empty (TheMealDB uses `{ "meals": null }` for no match).
  List<Recipe> _mapMeals(
    Map<String, dynamic> json,
    Recipe Function(Map<String, dynamic>) map,
  ) {
    final Object? meals = json['meals'];
    if (meals is! List || meals.isEmpty) return const <Recipe>[];
    final List<Recipe> recipes = <Recipe>[];
    for (final Object? meal in meals) {
      if (meal is Map) {
        recipes.add(map(Map<String, dynamic>.from(meal)));
      }
    }
    return recipes;
  }

  // ---------------------------------------------------------------------------
  // Adapters (TheMealDB JSON -> Recipe). These NEVER throw: every field is read
  // defensively and coerced to a safe default.
  // ---------------------------------------------------------------------------

  /// Reads [key] from [meal] as a trimmed string, tolerating null/non-string.
  static String _str(Map<String, dynamic> meal, String key) =>
      (meal[key] ?? '').toString().trim();

  /// Maps a FULL meal (from `search.php` / `lookup.php`) into a [Recipe].
  Recipe _mapFullMeal(Map<String, dynamic> meal) {
    final String id = _str(meal, 'idMeal');
    final String area = _str(meal, 'strArea');

    return Recipe(
      recipeId: id.isEmpty ? null : id,
      title: _str(meal, 'strMeal'),
      // TheMealDB has no short description field; leave it empty (clean).
      description: '',
      imageUrl: _str(meal, 'strMealThumb'),
      category: _str(meal, 'strCategory'),
      cookingTimeMinutes: 0,
      servings: 0,
      calories: 0,
      nutrition: Nutrition.zero,
      ingredients: _mapIngredients(meal),
      instructions: _mapInstructions(_str(meal, 'strInstructions')),
      tags: _mapTags(_str(meal, 'strTags'), area),
      sourceType: 'curated',
    );
  }

  /// Maps a PARTIAL filter card (from `filter.php`) into a [Recipe]: only id,
  /// title and image are available; [mealDbCategory] is stamped as the category
  /// and every other field falls back to its model default.
  Recipe _mapFilterItem(Map<String, dynamic> meal, String mealDbCategory) {
    final String id = _str(meal, 'idMeal');
    return Recipe(
      recipeId: id.isEmpty ? null : id,
      title: _str(meal, 'strMeal'),
      imageUrl: _str(meal, 'strMealThumb'),
      category: mealDbCategory,
      nutrition: Nutrition.zero,
      sourceType: 'curated',
    );
  }

  /// Splits TheMealDB's single instructions blob into non-empty, trimmed lines.
  List<String> _mapInstructions(String blob) {
    if (blob.isEmpty) return const <String>[];
    return blob
        .split(RegExp(r'\r\n|\r|\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Collects `strIngredient1..20` + `strMeasure1..20` into [Ingredient]s,
  /// skipping any slot whose ingredient name is blank/whitespace.
  List<Ingredient> _mapIngredients(Map<String, dynamic> meal) {
    final List<Ingredient> ingredients = <Ingredient>[];
    for (int i = 1; i <= 20; i++) {
      final String name = _str(meal, 'strIngredient$i');
      if (name.isEmpty) continue;
      final String quantity = _str(meal, 'strMeasure$i');
      ingredients.add(Ingredient(name: name, quantity: quantity));
    }
    return ingredients;
  }

  /// Builds tags from the comma-separated `strTags` plus the cuisine [area],
  /// dropping blanks. Returns `const <String>[]` when nothing is present.
  List<String> _mapTags(String rawTags, String area) {
    final List<String> tags = <String>[];
    if (rawTags.isNotEmpty) {
      for (final String tag in rawTags.split(',')) {
        final String trimmed = tag.trim();
        if (trimmed.isNotEmpty) tags.add(trimmed);
      }
    }
    if (area.isNotEmpty) tags.add(area);
    return tags.isEmpty ? const <String>[] : tags;
  }
}
