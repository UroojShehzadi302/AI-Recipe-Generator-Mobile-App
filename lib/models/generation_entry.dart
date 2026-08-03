// One entry in the user's AI generation history.
//
// A [GenerationEntry] records that the user asked the AI for a recipe: the
// prompt they typed, the recipe that came back, when it happened, and whether
// they kept it. It is what the Usage History screen lists.
//
// Deliberately Firebase-free (plain maps in/out) so it can be unit-tested and
// so the model layer never depends on `cloud_firestore`.

import 'recipe_model.dart';

/// What became of a generated recipe.
enum GenerationStatus {
  /// Generated and kept by the user (present in `generatedRecipes`).
  saved,

  /// Generated but not kept.
  generated;

  /// Parses the persisted string form, defaulting to [generated].
  static GenerationStatus fromName(String? raw) {
    return GenerationStatus.values.firstWhere(
      (GenerationStatus s) => s.name == raw,
      orElse: () => GenerationStatus.generated,
    );
  }
}

/// A single AI generation, as shown in Usage History.
class GenerationEntry {
  const GenerationEntry({
    required this.id,
    required this.recipe,
    required this.prompt,
    required this.createdAt,
    this.status = GenerationStatus.generated,
  });

  /// Document id — the same deterministic id used by the saved-recipe doc, so
  /// history and saved state refer to the same thing.
  final String id;

  /// The recipe that was produced.
  final Recipe recipe;

  /// The user's original request. May be empty for entries written before the
  /// prompt was recorded.
  final String prompt;

  /// When the generation happened. Falls back to the epoch when the server
  /// timestamp has not resolved yet.
  final DateTime createdAt;

  /// Whether the user kept this recipe.
  final GenerationStatus status;

  /// True when a prompt was actually recorded (older entries have none).
  bool get hasPrompt => prompt.trim().isNotEmpty;

  /// The recipe title, or a sensible stand-in.
  String get title =>
      recipe.title.trim().isEmpty ? 'Untitled recipe' : recipe.title.trim();

  /// Builds an entry from a Firestore document map.
  ///
  /// Defensive on every field: a malformed or partially-written document
  /// yields a usable entry rather than throwing and breaking the whole list.
  /// Returns `null` only when there is no recipe to show at all.
  static GenerationEntry? fromMap(Map<String, dynamic> map) {
    final Object? rawRecipe = map['recipe'];
    if (rawRecipe is! Map) return null;

    final Recipe recipe =
        Recipe.fromJson(Map<String, dynamic>.from(rawRecipe));

    final Object? rawId = map['genId'] ?? map['id'];
    final String id = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : recipe.title;

    final Object? rawPrompt = map['prompt'];
    final String prompt = rawPrompt is String ? rawPrompt.trim() : '';

    return GenerationEntry(
      id: id,
      recipe: recipe,
      prompt: prompt,
      createdAt: _parseDate(map['createdAt']),
      status: GenerationStatus.fromName(map['status'] as String?),
    );
  }

  /// Reads a Firestore `Timestamp`, an ISO string, or epoch millis.
  ///
  /// Accepts a `Timestamp` without importing `cloud_firestore` by duck-typing
  /// its `toDate()` — that keeps this model dependency-free while still
  /// handling the shape Firestore actually returns.
  static DateTime _parseDate(Object? raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final Object? converted = (raw as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      // Not a Timestamp — fall through to the epoch default.
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  GenerationEntry copyWith({GenerationStatus? status}) => GenerationEntry(
        id: id,
        recipe: recipe,
        prompt: prompt,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}
