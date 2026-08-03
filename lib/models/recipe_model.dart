// Recipe data models for the AI Recipe Generator.
//
// These types mirror the canonical `Recipe` shape defined in the project's
// Backend Architecture doc (§6.2 / §6.3 — the embedded Recipe shape the
// Recipe Detail screen binds to). They are plain, null-safe Dart with no
// Flutter or Firebase dependencies so they compile against the current
// pubspec and can be reused on any layer.
//
// A core requirement: every `fromJson` here is DEFENSIVE. A Recipe may be
// constructed from an LLM/Gemini JSON response that omits fields or returns
// wrong-typed values (a number where a string is expected, `null` lists,
// etc.). Parsing must NEVER throw — missing or malformed fields fall back to
// sensible empty defaults.

// ---------------------------------------------------------------------------
// Internal safe-cast helpers (file-private).
// ---------------------------------------------------------------------------

/// Reads a value as a [String], tolerating `null`, numbers, bools, etc.
/// Missing / null -> empty string.
String _asString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

/// Reads a value as an [int], tolerating `num`, numeric strings, `null`.
int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a value as a [double], tolerating `num`, numeric strings, `null`.
double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a value as a `List<String>`, tolerating `null` and non-list values.
/// Non-string elements are coerced with [_asString]; a single non-list value
/// is ignored (returns empty list).
List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map(_asString).toList(growable: false);
  }
  return const <String>[];
}

/// A single recipe ingredient: a human-readable [name] and free-text
/// [quantity] (e.g. "2 cups", "a pinch").
class Ingredient {
  final String name;
  final String quantity;

  const Ingredient({
    this.name = '',
    this.quantity = '',
  });

  /// Tolerant parser: missing fields become empty strings; never throws.
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: _asString(json['name']),
      quantity: _asString(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'quantity': quantity,
      };

  Ingredient copyWith({String? name, String? quantity}) => Ingredient(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
      );

  @override
  String toString() => 'Ingredient(name: $name, quantity: $quantity)';
}

/// Estimated nutrition per serving, in grams. Values are AI estimates and
/// should be labeled as such in the UI (Backend doc §12.2).
class Nutrition {
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const Nutrition({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  /// All-zero nutrition, useful as a default / fallback.
  static const Nutrition zero = Nutrition();

  /// Tolerant parser: any missing or non-numeric value becomes 0.
  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      protein: _asDouble(json['protein']),
      carbs: _asDouble(json['carbs']),
      fat: _asDouble(json['fat']),
      fiber: _asDouble(json['fiber']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  Nutrition copyWith({
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
  }) =>
      Nutrition(
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        fiber: fiber ?? this.fiber,
      );

  @override
  String toString() =>
      'Nutrition(protein: $protein, carbs: $carbs, fat: $fat, fiber: $fiber)';
}

/// The canonical Recipe shape bound to the Recipe Detail screen.
///
/// Mirrors Backend Architecture §6.3 (the embedded shape = curated recipe
/// §6.2 minus the ranking fields popularityScore/trendingScore/isFeatured).
/// [recipeId] is null for freshly generated recipes that have not been
/// persisted yet. [sourceType] is `'curated'` or `'generated'` (§6.5).
class Recipe {
  /// Present when the recipe originates from the curated `/recipes`
  /// collection; null for a just-generated recipe.
  final String? recipeId;
  final String title;
  final String description;

  /// Image URL (curated images are URLs, D6). May be empty for generated
  /// recipes where the model returns no image.
  final String imageUrl;

  /// One of the `category` enum values (breakfast, lunch, ...); see §6.5.
  final String category;
  final int cookingTimeMinutes;

  /// One of `easy` | `medium` | `hard` (§6.5). Defaults to `'easy'`.
  final String difficulty;
  final int servings;
  final int calories;
  final Nutrition nutrition;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> tips;
  final List<String> tags;

  /// `'curated'` | `'generated'` (§6.5). Defaults to `'generated'`.
  final String sourceType;

  const Recipe({
    this.recipeId,
    this.title = '',
    this.description = '',
    this.imageUrl = '',
    this.category = '',
    this.cookingTimeMinutes = 0,
    this.difficulty = 'easy',
    this.servings = 0,
    this.calories = 0,
    this.nutrition = Nutrition.zero,
    this.ingredients = const <Ingredient>[],
    this.instructions = const <String>[],
    this.tips = const <String>[],
    this.tags = const <String>[],
    this.sourceType = 'generated',
  });

  /// A fully-empty fallback Recipe, safe to render as a placeholder.
  static const Recipe empty = Recipe();

  /// DEFENSIVE factory: never throws on missing or wrong-typed fields.
  ///
  /// Safe to call directly on an unvalidated LLM/JSON payload. Unknown or
  /// malformed values collapse to the same defaults as the const constructor.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Nutrition: accept a nested map, tolerate anything else.
    final Object? rawNutrition = json['nutrition'];
    final Nutrition nutrition = rawNutrition is Map
        ? Nutrition.fromJson(Map<String, dynamic>.from(rawNutrition))
        : Nutrition.zero;

    // Ingredients: accept a list of maps; skip / coerce anything else.
    final Object? rawIngredients = json['ingredients'];
    final List<Ingredient> ingredients = rawIngredients is List
        ? rawIngredients
            .map((Object? e) => e is Map
                ? Ingredient.fromJson(Map<String, dynamic>.from(e))
                : const Ingredient())
            .toList(growable: false)
        : const <Ingredient>[];

    // recipeId is optional; keep it null when absent/empty rather than ''.
    final Object? rawId = json['recipeId'];
    final String? recipeId =
        (rawId == null) ? null : (_asString(rawId).isEmpty ? null : _asString(rawId));

    final String difficulty = _asString(json['difficulty']);
    final String sourceType = _asString(json['sourceType']);

    return Recipe(
      recipeId: recipeId,
      title: _asString(json['title']),
      description: _asString(json['description']),
      imageUrl: _asString(json['imageUrl']),
      category: _asString(json['category']),
      cookingTimeMinutes: _asInt(json['cookingTimeMinutes']),
      difficulty: difficulty.isEmpty ? 'easy' : difficulty,
      servings: _asInt(json['servings']),
      calories: _asInt(json['calories']),
      nutrition: nutrition,
      ingredients: ingredients,
      instructions: _asStringList(json['instructions']),
      tips: _asStringList(json['tips']),
      tags: _asStringList(json['tags']),
      sourceType: sourceType.isEmpty ? 'generated' : sourceType,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (recipeId != null) 'recipeId': recipeId,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'category': category,
        'cookingTimeMinutes': cookingTimeMinutes,
        'difficulty': difficulty,
        'servings': servings,
        'calories': calories,
        'nutrition': nutrition.toJson(),
        'ingredients':
            ingredients.map((Ingredient i) => i.toJson()).toList(growable: false),
        'instructions': instructions,
        'tips': tips,
        'tags': tags,
        'sourceType': sourceType,
      };

  Recipe copyWith({
    String? recipeId,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    int? cookingTimeMinutes,
    String? difficulty,
    int? servings,
    int? calories,
    Nutrition? nutrition,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    List<String>? tips,
    List<String>? tags,
    String? sourceType,
  }) {
    return Recipe(
      recipeId: recipeId ?? this.recipeId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      nutrition: nutrition ?? this.nutrition,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tips: tips ?? this.tips,
      tags: tags ?? this.tags,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  /// Whether a real calorie value is available (0 == unknown, e.g. TheMealDB).
  bool get hasCalories => calories > 0;

  /// Whether a cooking time is available (0 == unknown).
  bool get hasCookingTime => cookingTimeMinutes > 0;

  /// Whether a servings count is available (0 == unknown).
  bool get hasServings => servings > 0;

  /// Whether any nutrition macro is present (all-zero == unavailable).
  bool get hasNutrition =>
      nutrition.protein > 0 ||
      nutrition.carbs > 0 ||
      nutrition.fat > 0 ||
      nutrition.fiber > 0;

  @override
  String toString() =>
      'Recipe(recipeId: $recipeId, title: $title, category: $category, '
      'sourceType: $sourceType)';
}
