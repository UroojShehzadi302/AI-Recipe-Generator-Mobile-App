// Recipe data-access repository.
//
// [RecipeRepository] sits between the generic [FirestoreService] and the
// presentation layer (`RecipeProvider`). It owns the Firestore *schema* defined
// in the Backend Architecture doc (§6): document paths, the RecipeRef / embedded
// `Recipe` shapes, and the mapping to/from the [Recipe] model. All Firestore
// failures are translated into a [FirestoreFailure] carrying a user-safe
// message, so callers never see raw Firebase exceptions.
//
// AI generation is intentionally *not* implemented here: it is delivered in M6
// through the `generateRecipe` Cloud Function. [generateRecipe] is a stub that
// throws [UnimplementedError] until then.
//
// Imports are limited to `cloud_firestore` (for [FieldValue]) plus the
// project's own model/error/service files — no cloud_functions, no storage.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/recipe_model.dart';
import '../services/firestore_service.dart';

/// Reads and writes recipe-related data (home feed, favorites, saved/generated
/// recipes) following the Backend Architecture schema (§6).
class RecipeRepository {
  /// Creates a repository backed by [_firestore] (constructor injection).
  RecipeRepository(this._firestore);

  final FirestoreService _firestore;

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
  // AI generation (M6 stub).
  // ---------------------------------------------------------------------------

  /// Generates a recipe from a free-text [prompt].
  ///
  /// Not yet available: wired in M6 via the `generateRecipe` Cloud Function.
  Future<Recipe> generateRecipe(String prompt) async {
    throw UnimplementedError(
      'Recipe generation is wired in M6 via the generateRecipe Cloud Function',
    );
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
  Future<void> saveRecipe(String uid, Recipe recipe) async {
    try {
      final String id = favoriteDocId(recipe);
      await _firestore.setDoc(
        '${_generatedPath(uid)}/$id',
        <String, dynamic>{
          'genId': id,
          'recipe': recipe.toJson(),
          'sourceType': recipe.sourceType,
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
