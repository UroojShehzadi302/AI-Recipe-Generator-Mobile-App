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

import '../core/constants/sample_recipes.dart';
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
  // Home catalog (live rails).
  //
  // Drives the Home tab's horizontal rails from the live, cached catalog (the
  // repository's TheMealDB source + the curated desi set) instead of static
  // placeholder data. Three rails load together:
  //   * popular  — a live network category (many real cards).
  //   * desi     — the curated Pakistani set (local, always available).
  //   * quick    — a second live network category.
  // Desi is loaded first and independently so it still shows when the network
  // rails fail (offline). Source-agnostic: a future Firestore feed swaps in
  // behind [RecipeRepository.getRecipesByCategory] without touching this code.
  // ---------------------------------------------------------------------------

  /// App categories backing the two live (network) Home rails.
  static const String _popularCategory = 'Dinner';
  static const String _quickCategory = 'Breakfast';

  /// App category backing the curated desi Home rail.
  static const String _desiCategory = 'Pakistani';

  LoadStatus _homeCatalogStatus = LoadStatus.idle;
  String? _homeCatalogError;
  List<Recipe> _popularRail = const <Recipe>[];
  List<Recipe> _desiRail = const <Recipe>[];
  List<Recipe> _quickRail = const <Recipe>[];

  /// Status of the live Home rails load.
  LoadStatus get homeCatalogStatus => _homeCatalogStatus;

  /// User-friendly message for the last failed Home catalog load, or `null`.
  String? get homeCatalogError => _homeCatalogError;

  /// Popular recipes rail (live network category).
  List<Recipe> get popularRail => _popularRail;

  /// Curated Pakistani / desi recipes rail (local, always available).
  List<Recipe> get desiRail => _desiRail;

  /// Quick & easy recipes rail (live network category).
  List<Recipe> get quickRail => _quickRail;

  /// Loads the Home rails. Cheap to call repeatedly: it no-ops once loaded
  /// unless [force] is set (pull-to-refresh). Never throws.
  ///
  /// Two phases so Home is **never empty or stuck on a spinner**:
  ///  1. Seed instantly with curated content — the desi set (local) plus
  ///     curated sample rails for Popular / Quick — and mark the catalog loaded
  ///     right away.
  ///  2. Upgrade Popular & Quick to the live TheMealDB catalog in the
  ///     background. Any failure or timeout silently keeps the curated seed, so
  ///     a slow/absent network degrades gracefully instead of spinning forever.
  Future<void> loadHomeCatalog({bool force = false}) async {
    if (!force && _homeCatalogStatus == LoadStatus.loaded) return;

    // Phase 1 — instant curated seed. The desi source is local (no network),
    // and the sample rails guarantee the network rails show *something* at once.
    try {
      _desiRail = await _repository.getRecipesByCategory(_desiCategory);
    } catch (_) {
      _desiRail = const <Recipe>[];
    }
    if (_popularRail.isEmpty) _popularRail = SampleRecipes.popular;
    if (_quickRail.isEmpty) _quickRail = SampleRecipes.quickAndEasy;
    _homeCatalogStatus = LoadStatus.loaded;
    _homeCatalogError = null;
    notifyListeners();

    // Phase 2 — upgrade to the live catalog in the background; keep the seed on
    // any failure so the rails never revert to a spinner or an empty state.
    try {
      final List<List<Recipe>> live = await Future.wait(<Future<List<Recipe>>>[
        _repository.getRecipesByCategory(_popularCategory),
        _repository.getRecipesByCategory(_quickCategory),
      ]);
      if (live[0].isNotEmpty) _popularRail = live[0];
      if (live[1].isNotEmpty) _quickRail = live[1];
      notifyListeners();
    } catch (_) {
      // Keep the curated seed — nothing to surface to the user.
    }
  }

  /// Reloads the live Home rails from scratch (pull-to-refresh / retry).
  Future<void> retryHomeCatalog() => loadHomeCatalog(force: true);

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
  // Search & catalog state.
  // ---------------------------------------------------------------------------
  //
  // TODO(M5/content-source): the catalog now comes from the repository's
  // TheMealDB source (via [RecipeRepository.searchRecipes] /
  // [getRecipesByCategory] / [getRecipeById]). When the real content source
  // lands (Open Decision 1), the repository swaps to Firestore behind the same
  // signatures, so nothing in this provider changes.

  LoadStatus _searchStatus = LoadStatus.idle;
  List<Recipe> _searchResults = const <Recipe>[];
  String? _searchError;
  String _searchQuery = '';
  String? _searchCategory;
  final List<String> _recentSearches = <String>[];

  /// Status of the last [search] call.
  LoadStatus get searchStatus => _searchStatus;

  /// Recipes matching the last [search] call.
  List<Recipe> get searchResults => _searchResults;

  /// User-friendly message for the last failed [search], or `null`.
  String? get searchError => _searchError;

  /// The current search query text.
  String get searchQuery => _searchQuery;

  /// The user's recent search terms, most-recent first (read-only view).
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Searches the catalog for [query], optionally narrowed to [category].
  ///
  /// An empty [query] with no meaningful [category] (null, blank, or
  /// `'For You'`) short-circuits to an idle empty result — no network call — so
  /// the screen can show recent/popular instead. Otherwise delegates to
  /// [RecipeRepository.searchRecipes]. Never throws: a domain [Failure] surfaces
  /// its message on [searchError], anything else the generic message.
  Future<void> search(String query, {String? category}) async {
    _searchQuery = query;
    _searchCategory = category;

    final bool emptyCategory = category == null ||
        category.trim().isEmpty ||
        category.trim().toLowerCase() == 'for you';
    if (query.trim().isEmpty && emptyCategory) {
      _searchResults = const <Recipe>[];
      _searchStatus = LoadStatus.idle;
      _searchError = null;
      notifyListeners();
      return;
    }

    _searchStatus = LoadStatus.loading;
    _searchError = null;
    notifyListeners();

    try {
      _searchResults =
          await _repository.searchRecipes(query, appCategory: category);
      _searchStatus = LoadStatus.loaded;
    } on Failure catch (failure) {
      _searchError = failure.message;
      _searchStatus = LoadStatus.error;
    } catch (_) {
      _searchError = _genericError;
      _searchStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Retries the last [search] with the same query and category filter.
  Future<void> retrySearch() => search(_searchQuery, category: _searchCategory);

  /// Records [term] as a recent search: trimmed, de-duplicated
  /// (case-insensitive), inserted at the front, and capped at 8 entries.
  void addRecentSearch(String term) {
    final String trimmed = term.trim();
    if (trimmed.isEmpty) return;

    _recentSearches
        .removeWhere((String t) => t.toLowerCase() == trimmed.toLowerCase());
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 8) {
      _recentSearches.removeRange(8, _recentSearches.length);
    }
    notifyListeners();
  }

  /// Clears the current query and results, settling into `idle` (recent
  /// searches are kept).
  void clearSearch() {
    _searchQuery = '';
    _searchResults = const <Recipe>[];
    _searchStatus = LoadStatus.idle;
    _searchError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Category catalog state.
  // ---------------------------------------------------------------------------

  LoadStatus _categoryStatus = LoadStatus.idle;
  List<Recipe> _categoryRecipes = const <Recipe>[];
  String? _categoryError;
  String _categoryName = '';

  /// Status of the last [loadCategory] call.
  LoadStatus get categoryStatus => _categoryStatus;

  /// Recipes for the last loaded category (partial cards — resolve full detail
  /// with [getRecipeDetails]).
  List<Recipe> get categoryRecipes => _categoryRecipes;

  /// User-friendly message for the last failed [loadCategory], or `null`.
  String? get categoryError => _categoryError;

  /// The app category name of the last [loadCategory] call.
  String get categoryName => _categoryName;

  /// Loads catalog recipes for [appCategory] via
  /// [RecipeRepository.getRecipesByCategory].
  ///
  /// Never throws: a domain [Failure] surfaces its message on [categoryError],
  /// anything else the generic message.
  Future<void> loadCategory(String appCategory) async {
    _categoryName = appCategory;
    _categoryStatus = LoadStatus.loading;
    _categoryError = null;
    notifyListeners();

    try {
      _categoryRecipes = await _repository.getRecipesByCategory(appCategory);
      _categoryStatus = LoadStatus.loaded;
    } on Failure catch (failure) {
      _categoryError = failure.message;
      _categoryStatus = LoadStatus.error;
    } catch (_) {
      _categoryError = _genericError;
      _categoryStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Retries the last [loadCategory].
  Future<void> retryCategory() => loadCategory(_categoryName);

  /// Resolves a partial (category-list) recipe to full detail by [id] via
  /// [RecipeRepository.getRecipeById].
  ///
  /// Returns the full [Recipe] on success, or `null` when not found or on any
  /// error (no global status — the screen shows its own inline loading and a
  /// snackbar on `null`).
  Future<Recipe?> getRecipeDetails(String id) async {
    try {
      return await _repository.getRecipeById(id);
    } on Failure catch (_) {
      return null;
    } catch (_) {
      return null;
    }
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
