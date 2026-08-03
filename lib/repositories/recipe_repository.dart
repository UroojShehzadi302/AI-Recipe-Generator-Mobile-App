// Recipe data-access repository.
//
// [RecipeRepository] sits between the generic [FirestoreService] and the
// presentation layer (`RecipeProvider`). It owns the Firestore *schema* defined
// in the Backend Architecture doc (§6): document paths, the RecipeRef / embedded
// `Recipe` shapes, and the mapping to/from the [Recipe] model. All Firestore
// failures are translated into a [FirestoreFailure] carrying a user-safe
// message, so callers never see raw Firebase exceptions.
//
// AI generation delegates to an [AiService] (direct Gemini in dev, per the
// no-Cloud-Functions dev decision). This repository owns the Recipe *schema*:
// it asks the service for the model's JSON text and parses it into a [Recipe]
// via the defensive [Recipe.fromJson]. The service knows nothing about the
// domain model, so swapping it (dev → Cloud Functions) never touches this file.
//
// Imports are limited to `cloud_firestore` (for [FieldValue]) plus the
// project's own model/error/service files.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/desi_recipes.dart';
import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/generation_entry.dart';
import '../models/recipe_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/meal_db_service.dart';

/// Reads and writes recipe-related data (home feed, favorites, saved/generated
/// recipes) following the Backend Architecture schema (§6).
class RecipeRepository {
  /// Creates a repository backed by [_firestore], [_ai] and [_mealDb]
  /// (constructor injection).
  RecipeRepository(this._firestore, this._ai, this._mealDb);

  final FirestoreService _firestore;
  final AiService _ai;
  final MealDbService _mealDb;

  // ---------------------------------------------------------------------------
  // Path helpers (schema lives here, not in the service).
  // ---------------------------------------------------------------------------

  /// The single cached home-feed document for the given [locale] (D5, §6.4).
  static String _homeFeedPath([String locale = 'en']) => 'home_feed/$locale';

  /// The private favorites subcollection for [uid] (§6.1).
  static String _favoritesPath(String uid) => 'users/$uid/favorites';

  /// The private generated-recipes subcollection for [uid] (§6.1).
  static String _generatedPath(String uid) => 'users/$uid/generatedRecipes';

  /// Deterministic favorite document id for [recipe].
  ///
  /// Uses the curated [Recipe.recipeId] when available; otherwise a slug of the
  /// title. A stable id makes favoriting idempotent (no duplicate bookmarks)
  /// and lets callers remove a favorite knowing only the [Recipe].
  String favoriteDocId(Recipe recipe) {
    final String? id = recipe.recipeId;
    if (id != null && id.trim().isNotEmpty) return id.trim();

    final String slug = recipe.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-+)|(-+$)'), '');
    return slug.isEmpty ? 'recipe' : slug;
  }

  // ---------------------------------------------------------------------------
  // Recipe catalog (blended source).
  //
  // The catalog blends TWO sources behind identical, source-agnostic method
  // signatures:
  //   1. A curated built-in [DesiRecipes] set (the `'Pakistani'` category) —
  //      full const [Recipe] objects served locally with no network/cache.
  //   2. TheMealDB network source (Option A) for every other category.
  // The 'Pakistani' local source is permanent: it persists after the eventual
  // Firestore swap, whereas the TheMealDB path below is the stopgap.
  //
  // TODO(decision-1): the TheMealDB path is a stopgap while real content
  // (curated Firestore feed vs. recipe API vs. AI-only) is undecided. When
  // Decision 1 lands, repoint the network path at the chosen source — the
  // SIGNATURES stay identical so providers/UI never change, and the curated
  // desi blend stays in place.
  // ---------------------------------------------------------------------------

  /// The app category served by the built-in curated [DesiRecipes] source.
  /// Matched case-insensitively.
  static const String _desiCategory = 'Pakistani';

  /// True when [appCategory] denotes the curated desi ('Pakistani') category.
  static bool _isDesiCategory(String? appCategory) =>
      appCategory != null &&
      appCategory.trim().toLowerCase() == _desiCategory.toLowerCase();

  /// Filters the curated [DesiRecipes] set by free-text [query]
  /// (case-insensitive substring on title, any ingredient name, any tag, or
  /// category). A blank query returns every desi recipe.
  static List<Recipe> _desiMatches(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return DesiRecipes.all;
    return DesiRecipes.all.where((Recipe r) {
      if (r.title.toLowerCase().contains(q)) return true;
      if (r.category.toLowerCase().contains(q)) return true;
      if (r.tags.any((String t) => t.toLowerCase().contains(q))) return true;
      if (r.ingredients
          .any((Ingredient i) => i.name.toLowerCase().contains(q))) {
        return true;
      }
      return false;
    }).toList(growable: false);
  }

  /// App-category -> TheMealDB-category mapping.
  ///
  /// TheMealDB's taxonomy differs from the app's, so `Lunch`/`Dinner`/`Healthy`
  /// are approximations (Pasta / Beef / Vegetarian) chosen for reasonable
  /// results rather than exact equivalence.
  static const Map<String, String> _categoryMap = <String, String>{
    'Breakfast': 'Breakfast',
    'Lunch': 'Pasta',
    'Dinner': 'Beef',
    'Desserts': 'Dessert',
    'Healthy': 'Vegetarian',
    'Vegan': 'Vegan',
  };

  /// In-memory catalog caches to avoid repeated identical API calls within a
  /// session (search results / category lists keyed by request; recipes by id).
  final Map<String, List<Recipe>> _catalogCache = <String, List<Recipe>>{};
  final Map<String, Recipe> _recipeByIdCache = <String, Recipe>{};

  /// Searches the catalog by free-text [query], optionally narrowed to an
  /// [appCategory].
  ///
  /// Results blend the curated [DesiRecipes] set with the [MealDbService]
  /// search hits (full recipes):
  /// * `appCategory == 'Pakistani'` returns ONLY the curated desi matches (no
  ///   network call).
  /// * another real category (non-null, non-empty, not `'For You'`) keeps the
  ///   TheMealDB-only behavior, narrowed to the mapped TheMealDB category
  ///   (desi recipes never fall in those categories).
  /// * no category / `'For You'` runs the TheMealDB search and PREPENDS the
  ///   desi matches so curated dishes surface in a normal search.
  ///
  /// Cached per (query, category). Source-agnostic: a future Firestore impl
  /// keeps this exact signature.
  Future<List<Recipe>> searchRecipes(
    String query, {
    String? appCategory,
  }) async {
    final String cacheKey =
        'search:${query.toLowerCase().trim()}:${appCategory ?? ''}';
    final List<Recipe>? cached = _catalogCache[cacheKey];
    if (cached != null) return cached;

    // Pakistani = curated local source only; no network.
    if (_isDesiCategory(appCategory)) {
      final List<Recipe> desi = _desiMatches(query);
      _catalogCache[cacheKey] = desi;
      return desi;
    }

    try {
      final List<Recipe> results = await _mealDb.searchByName(query.trim());

      final bool hasRealCategory = appCategory != null &&
          appCategory.isNotEmpty &&
          appCategory.toLowerCase() != 'for you';

      List<Recipe> blended;
      if (hasRealCategory) {
        // Another real category: TheMealDB only (curated desi aren't in these).
        final String targetCat =
            (_categoryMap[appCategory] ?? appCategory).toLowerCase();
        blended = results
            .where((Recipe r) => r.category.toLowerCase() == targetCat)
            .toList(growable: false);
      } else {
        // No category / 'For You': surface curated desi dishes first, then the
        // network hits. Ids never collide, so no de-duplication is needed.
        blended = <Recipe>[..._desiMatches(query), ...results];
      }

      _catalogCache[cacheKey] = blended;
      return blended;
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Lists catalog recipes for an [appCategory] (e.g. the Home category chips).
  ///
  /// Maps the app category to a TheMealDB category; an unmapped category yields
  /// `const <Recipe>[]`. TheMealDB's `filter.php` returns PARTIAL cards, so
  /// these recipes carry id/title/image only — resolve full detail with
  /// [getRecipeById]. Each card's category is RE-LABELED back to [appCategory]
  /// so the UI shows the app's taxonomy. Cached per app category.
  Future<List<Recipe>> getRecipesByCategory(String appCategory) async {
    // Pakistani = curated local source, served directly (const, no network).
    if (_isDesiCategory(appCategory)) return DesiRecipes.all;

    final String? mealCat = _categoryMap[appCategory];
    if (mealCat == null) return const <Recipe>[];

    final String cacheKey = 'cat:$appCategory';
    final List<Recipe>? cached = _catalogCache[cacheKey];
    if (cached != null) return cached;

    try {
      final List<Recipe> list = await _mealDb.filterByCategory(mealCat);
      final List<Recipe> relabeled = list
          .map((Recipe r) => r.copyWith(category: appCategory))
          .toList(growable: false);
      _catalogCache[cacheKey] = relabeled;
      return relabeled;
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Resolves a single full catalog recipe by [id] (used to turn a partial
  /// category card into full detail). Returns `null` when not found. Cached
  /// by id. Source-agnostic signature.
  Future<Recipe?> getRecipeById(String id) async {
    // Curated desi recipes are full and their 'desi-...' ids aren't valid
    // TheMealDB ids — resolve them locally before any cache/network lookup.
    for (final Recipe r in DesiRecipes.all) {
      if (r.recipeId == id) return r;
    }

    if (_recipeByIdCache.containsKey(id)) return _recipeByIdCache[id];

    try {
      final Recipe? r = await _mealDb.lookupById(id);
      if (r != null) _recipeByIdCache[id] = r;
      return r;
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  // ---------------------------------------------------------------------------
  // AI generation.
  // ---------------------------------------------------------------------------

  /// Generates a recipe from a free-text [prompt] via the [AiService].
  ///
  /// Asks the service for the model's JSON text, decodes it, and maps it into a
  /// [Recipe] (forced to `sourceType: 'generated'`). Parsing is defensive:
  /// [Recipe.fromJson] never throws on missing/wrong-typed fields, so a partial
  /// model response degrades gracefully rather than crashing.
  ///
  /// Errors surface as domain [Failure]s: service [AiFailure]/[NetworkFailure]
  /// propagate unchanged; malformed JSON becomes an [AiFailure]; anything else
  /// an [UnknownFailure]. (With no API key the service throws
  /// [UnimplementedError], which callers map to a friendly "coming soon".)
  Future<Recipe> generateRecipe(String prompt) async {
    final String raw = await _ai.generateRecipe(prompt);
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw AiFailure(ErrorMapper.aiMessage('invalid-response'));
      }
      final Recipe recipe =
          Recipe.fromJson(Map<String, dynamic>.from(decoded));
      return recipe.copyWith(sourceType: 'generated');
    } on Failure {
      rethrow;
    } on FormatException {
      throw AiFailure(ErrorMapper.aiMessage('invalid-response'));
    } catch (e) {
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Home feed.
  // ---------------------------------------------------------------------------

  /// Reads the cached home feed (`home_feed/en`, §6.4) and flattens its
  /// RecipeRef rails (`popular` + `trending` + `featured` + `daily`) into a
  /// de-duplicated list of [Recipe]s.
  ///
  /// A RecipeRef is only a lightweight card projection, but [Recipe.fromJson]
  /// parses it defensively (missing fields fall back to defaults). Returns an
  /// **empty list** when the document is missing — never throws for that case.
  Future<List<Recipe>> getHomeFeed() async {
    try {
      final Map<String, dynamic>? data =
          await _firestore.getDoc(_homeFeedPath());
      if (data == null) return const <Recipe>[];

      final List<Map<String, dynamic>> refs = <Map<String, dynamic>>[];

      void addRail(Object? value) {
        if (value is List) {
          for (final Object? element in value) {
            if (element is Map) {
              refs.add(Map<String, dynamic>.from(element));
            }
          }
        }
      }

      addRail(data['popular']);
      addRail(data['trending']);
      addRail(data['featured']);

      final Object? daily = data['daily'];
      if (daily is Map) {
        refs.add(Map<String, dynamic>.from(daily));
      }

      // De-duplicate by recipeId (or title fallback) while preserving order.
      final Set<String> seen = <String>{};
      final List<Recipe> recipes = <Recipe>[];
      for (final Map<String, dynamic> ref in refs) {
        final Recipe recipe = Recipe.fromJson(ref);
        final String key =
            (recipe.recipeId != null && recipe.recipeId!.isNotEmpty)
                ? recipe.recipeId!
                : recipe.title;
        if (key.isEmpty || seen.add(key)) {
          recipes.add(recipe);
        }
      }
      return recipes;
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Favorites (`users/{uid}/favorites`, §6.1 — embedded snapshot, D4).
  // ---------------------------------------------------------------------------

  /// Adds [recipe] to [uid]'s favorites as an embedded snapshot.
  ///
  /// Stored under a deterministic id ([favoriteDocId]) so re-favoriting the same
  /// recipe overwrites rather than duplicates.
  Future<void> addFavorite(String uid, Recipe recipe) async {
    try {
      final String favoriteId = favoriteDocId(recipe);
      await _firestore.setDoc(
        '${_favoritesPath(uid)}/$favoriteId',
        <String, dynamic>{
          'favoriteId': favoriteId,
          'recipe': recipe.toJson(),
          'sourceType': recipe.sourceType,
          'sourceRecipeId': recipe.recipeId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Removes the favorite [favoriteId] from [uid]'s favorites.
  Future<void> removeFavorite(String uid, String favoriteId) async {
    try {
      await _firestore.deleteDoc('${_favoritesPath(uid)}/$favoriteId');
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Reads [uid]'s favorites, mapping each doc's embedded `recipe` map into a
  /// [Recipe].
  Future<List<Recipe>> getFavorites(String uid) async {
    try {
      final List<Map<String, dynamic>> docs =
          await _firestore.getCollection(_favoritesPath(uid));
      return _mapEmbeddedRecipes(docs);
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Streams [uid]'s favorites in real time. Stream errors are converted to a
  /// [FirestoreFailure].
  Stream<List<Recipe>> watchFavorites(String uid) {
    return _firestore.watchCollection(_favoritesPath(uid)).map(_mapEmbeddedRecipes).handleError(
      (Object error) {
        throw FirestoreFailure(ErrorMapper.generic(error));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Saved / generated recipes (`users/{uid}/generatedRecipes`, §6.1).
  // ---------------------------------------------------------------------------

  /// Saves [recipe] to [uid]'s kept collection (`users/{uid}/generatedRecipes`).
  ///
  /// Stored as an embedded snapshot under a deterministic id so re-saving the
  /// same recipe overwrites rather than duplicates. Surfaces a
  /// [FirestoreFailure] on error.
  ///
  /// [prompt] is the request that produced the recipe. It is recorded so the
  /// Usage History screen can show *what the user asked for*, not just what
  /// came back — the prompt is the part they recognise. Passing null leaves any
  /// previously stored prompt untouched (the write is a merge).
  Future<void> saveRecipe(String uid, Recipe recipe, {String? prompt}) async {
    try {
      final String id = favoriteDocId(recipe);
      final Map<String, dynamic> data = <String, dynamic>{
        'genId': id,
        'recipe': recipe.toJson(),
        'sourceType': recipe.sourceType,
        'status': 'saved',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (prompt != null && prompt.trim().isNotEmpty) {
        data['prompt'] = prompt.trim();
      }
      await _firestore.setDoc(
        '${_generatedPath(uid)}/$id',
        data,
        merge: true,
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Removes a kept recipe from `users/{uid}/generatedRecipes`.
  ///
  /// [genId] is the deterministic id from [favoriteDocId]. Deleting also
  /// removes the matching Usage History row, which is intended: history lists
  /// generations the user still has, so an unsaved recipe shouldn't linger.
  Future<void> deleteSavedRecipe(String uid, String genId) async {
    try {
      await _firestore.deleteDoc('${_generatedPath(uid)}/$genId');
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Reads [uid]'s AI generation history, newest first.
  ///
  /// Backs the Usage History screen. Sorting happens client-side rather than
  /// via `orderBy` so the read needs no composite index and still works for
  /// documents whose server timestamp hasn't resolved yet.
  Future<List<GenerationEntry>> getGenerationHistory(String uid) async {
    try {
      final List<Map<String, dynamic>> docs =
          await _firestore.getCollection(_generatedPath(uid));

      final List<GenerationEntry> entries = <GenerationEntry>[];
      for (final Map<String, dynamic> doc in docs) {
        final GenerationEntry? entry = GenerationEntry.fromMap(doc);
        if (entry != null) entries.add(entry);
      }
      entries.sort(
        (GenerationEntry a, GenerationEntry b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      return entries;
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  /// Reads the recipes [uid] generated with AI and kept, mapping each doc's
  /// embedded `recipe` map into a [Recipe].
  Future<List<Recipe>> getSavedRecipes(String uid) async {
    try {
      final List<Map<String, dynamic>> docs =
          await _firestore.getCollection(_generatedPath(uid));
      return _mapEmbeddedRecipes(docs);
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirestoreFailure(ErrorMapper.generic(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Internal mapping.
  // ---------------------------------------------------------------------------

  /// Maps a list of subcollection docs (each shaped `{ recipe: {...}, ... }`)
  /// into [Recipe]s, tolerantly skipping any doc missing a valid `recipe` map.
  List<Recipe> _mapEmbeddedRecipes(List<Map<String, dynamic>> docs) {
    final List<Recipe> recipes = <Recipe>[];
    for (final Map<String, dynamic> doc in docs) {
      final Object? raw = doc['recipe'];
      if (raw is Map) {
        recipes.add(Recipe.fromJson(Map<String, dynamic>.from(raw)));
      }
    }
    return recipes;
  }
}
