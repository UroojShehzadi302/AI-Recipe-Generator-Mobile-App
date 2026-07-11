// Presentation-layer state for the Recipe feature.
//
// [RecipeProvider] is a [ChangeNotifier] that drives the Home feed, the AI
// generator screen, favorites, and saved (AI-generated) recipes. It delegates
// all data access to a [RecipeRepository] and exposes plain, immutable-ish
// view state (status enums, lists, and friendly error strings) for the UI to
// bind to via `provider`.
//
// Every repository call is guarded: a domain [Failure] surfaces its
// user-friendly [Failure.message] on the relevant error field, and any other
// error collapses to a generic message. Nothing here throws to the UI, and
// [notifyListeners] is always called after a state transition.
//
// Only `flutter/foundation` (for [ChangeNotifier]) and project files are
// imported.

import 'package:flutter/foundation.dart';

import '../core/error/failure.dart';
import '../models/recipe_model.dart';
import '../repositories/recipe_repository.dart';

/// Coarse lifecycle status for an async section of the screen.
enum LoadStatus {
  /// Nothing loaded yet.
  idle,

  /// A load/operation is in flight.
  loading,

  /// Data is available.
  loaded,

  /// The last operation failed; see the matching error field.
  error,
}

/// Generic fallback shown when an error is not a domain [Failure].
const String _genericError = 'Something went wrong. Please try again.';

/// Holds and coordinates all recipe-related UI state.
class RecipeProvider extends ChangeNotifier {
  /// Creates a provider backed by [_repository].
  RecipeProvider(this._repository);

  final RecipeRepository _repository;

  // ---------------------------------------------------------------------------
  // Home feed state.
  // ---------------------------------------------------------------------------

  LoadStatus _homeStatus = LoadStatus.idle;
  List<Recipe> _homeRecipes = const <Recipe>[];
  String? _homeError;

  /// Status of the Home feed load.
  LoadStatus get homeStatus => _homeStatus;

  /// Recipes flattened from the cached home feed.
  List<Recipe> get homeRecipes => _homeRecipes;

  /// User-friendly message for the last failed Home load, or `null`.
  String? get homeError => _homeError;

  /// Loads the cached home feed. Never throws; sets [homeError] on failure.
  ///
  /// A missing feed document resolves to an empty list (a valid `loaded`
  /// state), not an error.
  Future<void> loadHomeFeed() async {
    _homeStatus = LoadStatus.loading;
    _homeError = null;
    notifyListeners();

    try {
      _homeRecipes = await _repository.getHomeFeed();
      _homeStatus = LoadStatus.loaded;
    } on Failure catch (failure) {
      _homeError = failure.message;
      _homeStatus = LoadStatus.error;
    } catch (_) {
      _homeError = _genericError;
      _homeStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // AI generation state.
  // ---------------------------------------------------------------------------

  LoadStatus _genStatus = LoadStatus.idle;
  Recipe? _generated;
  String? _genError;

  /// Status of the last generation attempt.
  LoadStatus get genStatus => _genStatus;

  /// The most recently generated recipe, or `null`.
  Recipe? get generated => _generated;

  /// User-friendly message for the last failed generation, or `null`.
  String? get genError => _genError;

  /// Attempts to generate a recipe from [prompt].
  ///
  /// AI generation ships in M6. Until then the repository throws
  /// [UnimplementedError]; this method catches it and settles into an `error`
  /// state with a friendly "AI generation coming soon" message rather than
  /// crashing. Returns the generated [Recipe] on success, otherwise `null`.
  Future<Recipe?> generate(String prompt) async {
    _genStatus = LoadStatus.loading;
    _genError = null;
    notifyListeners();

    try {
      final Recipe recipe = await _repository.generateRecipe(prompt);
      _generated = recipe;
      _genStatus = LoadStatus.loaded;
      notifyListeners();
      return recipe;
    } on UnimplementedError {
      _genError = 'AI generation coming soon';
      _genStatus = LoadStatus.error;
      notifyListeners();
      return null;
    } on Failure catch (failure) {
      _genError = failure.message;
      _genStatus = LoadStatus.error;
      notifyListeners();
      return null;
    } catch (_) {
      _genError = 'AI generation coming soon';
      _genStatus = LoadStatus.error;
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Favorites state.
  // ---------------------------------------------------------------------------

  List<Recipe> _favorites = const <Recipe>[];
  String? _favoritesError;

  /// The user's favorite recipes.
  List<Recipe> get favorites => _favorites;

  /// User-friendly message for the last failed favorites operation, or `null`.
  String? get favoritesError => _favoritesError;

  /// Whether [recipe] is currently in [favorites] (matched by id or title).
  bool isFavorite(Recipe recipe) =>
      _favorites.any((Recipe r) => _sameRecipe(r, recipe));

  /// Loads [uid]'s favorites. Never throws; sets [favoritesError] on failure.
  Future<void> loadFavorites(String uid) async {
    try {
      _favorites = await _repository.getFavorites(uid);
      _favoritesError = null;
    } on Failure catch (failure) {
      _favoritesError = failure.message;
    } catch (_) {
      _favoritesError = _genericError;
    }
    notifyListeners();
  }

  /// Toggles [recipe] in [uid]'s favorites: removes it when already present
  /// (by id or title), otherwise adds it. Optimistically updates local state
  /// and never throws.
  Future<void> toggleFavorite(String uid, Recipe recipe) async {
    try {
      if (isFavorite(recipe)) {
        await _repository.removeFavorite(
          uid,
          _repository.favoriteDocId(recipe),
        );
        _favorites = _favorites
            .where((Recipe r) => !_sameRecipe(r, recipe))
            .toList(growable: false);
      } else {
        await _repository.addFavorite(uid, recipe);
        _favorites = <Recipe>[..._favorites, recipe];
      }
      _favoritesError = null;
    } on Failure catch (failure) {
      _favoritesError = failure.message;
    } catch (_) {
      _favoritesError = _genericError;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Saved (AI-generated) recipes state.
  // ---------------------------------------------------------------------------

  List<Recipe> _saved = const <Recipe>[];
  String? _savedError;

  /// The user's saved (AI-generated) recipes.
  List<Recipe> get saved => _saved;

  /// User-friendly message for the last failed saved-recipes load, or `null`.
  String? get savedError => _savedError;

  /// Saves [recipe] to [uid]'s kept collection and updates local state.
  ///
  /// Returns `true` on success. Never throws; sets [savedError] on failure.
  Future<bool> saveRecipe(String uid, Recipe recipe) async {
    try {
      await _repository.saveRecipe(uid, recipe);
      if (!_saved.any((Recipe r) => _sameRecipe(r, recipe))) {
        _saved = <Recipe>[recipe, ..._saved];
      }
      _savedError = null;
      notifyListeners();
      return true;
    } on Failure catch (failure) {
      _savedError = failure.message;
      notifyListeners();
      return false;
    } catch (_) {
      _savedError = _genericError;
      notifyListeners();
      return false;
    }
  }

  /// Loads [uid]'s saved recipes. Never throws; sets [savedError] on failure.
  Future<void> loadSaved(String uid) async {
    try {
      _saved = await _repository.getSavedRecipes(uid);
      _savedError = null;
    } on Failure catch (failure) {
      _savedError = failure.message;
    } catch (_) {
      _savedError = _genericError;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers.
  // ---------------------------------------------------------------------------

  /// Identity test used for favorite matching: same non-empty [Recipe.recipeId]
  /// when both have one, else a case-insensitive title match.
  bool _sameRecipe(Recipe a, Recipe b) {
    final String? aId = a.recipeId;
    final String? bId = b.recipeId;
    if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty) {
      return aId == bId;
    }
    return a.title.trim().toLowerCase() == b.title.trim().toLowerCase();
  }
}
