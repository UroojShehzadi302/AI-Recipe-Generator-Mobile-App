// Turns a [Recipe] into the plain-text block the user shares.
//
// This is deliberately a PURE function with no Flutter, Firebase, or plugin
// dependency: it is the part of the share feature worth testing, and keeping it
// off the platform means it can be exercised exhaustively in a plain unit test.
// The [ShareService] implementations only move the resulting string; they never
// decide what is in it.
//
// Robustness contract (mirrors `Recipe.fromJson`, which is equally defensive):
// composition MUST NEVER THROW. A `Recipe` can arrive straight from an LLM
// response with missing fields, empty lists, wrong-typed values coerced to
// empty strings, or absurdly long text. Every section here is individually
// optional and is omitted when it has nothing to say, so a nearly-empty recipe
// still produces a sensible (if short) message rather than a wall of empty
// headings.

import '../constants/app_strings.dart';
import '../../models/recipe_model.dart';

/// Composes the plain-text representation of a [Recipe] for sharing.
class RecipeShareText {
  RecipeShareText._();

  /// Hard cap on the composed message.
  ///
  /// Android delivers share payloads through a Binder transaction with a ~1 MB
  /// limit shared across the whole transaction, and some targets (SMS, certain
  /// chat apps) silently truncate far earlier. A recipe never legitimately runs
  /// this long, so exceeding it means the text is junk — clamping keeps a
  /// malformed AI response from producing an unusable share.
  static const int maxLength = 5000;

  /// The longest a single field is allowed to be before it is elided.
  ///
  /// Applied per-field so one runaway value (an AI description that never
  /// stopped) cannot crowd out the ingredients and steps that follow it.
  static const int maxFieldLength = 500;

  /// Builds the shareable text for [recipe].
  ///
  /// Sections with no content are omitted entirely. Never throws: a completely
  /// empty [Recipe] yields just the title fallback and the attribution line.
  static String compose(Recipe recipe) {
    final StringBuffer buffer = StringBuffer();

    // --- Title ---
    final String title = _clean(recipe.title);
    buffer.writeln(title.isEmpty ? AppStrings.shareUntitledRecipe : title);

    // --- Description ---
    final String description = _clean(recipe.description);
    if (description.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(description);
    }

    // --- Stat line (only the facts we actually have) ---
    final List<String> stats = <String>[
      if (recipe.hasCookingTime)
        '${AppStrings.shareTimeLabel}: ${recipe.cookingTimeMinutes} '
            '${AppStrings.shareMinutesSuffix}',
      if (recipe.hasServings)
        '${AppStrings.shareServesLabel}: ${recipe.servings}',
      if (recipe.hasCalories)
        '${AppStrings.shareCaloriesLabel}: ${recipe.calories}',
    ];
    if (stats.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(stats.join('  •  '));
    }

    // --- Ingredients ---
    // An ingredient with neither name nor quantity is skipped rather than
    // emitted as a bare bullet; a list of those collapses the section away.
    final List<String> ingredientLines = <String>[];
    for (final Ingredient ingredient in recipe.ingredients) {
      final String name = _clean(ingredient.name);
      final String quantity = _clean(ingredient.quantity);
      if (name.isEmpty && quantity.isEmpty) continue;
      if (name.isEmpty) {
        ingredientLines.add('• $quantity');
      } else if (quantity.isEmpty) {
        ingredientLines.add('• $name');
      } else {
        ingredientLines.add('• $quantity $name');
      }
    }
    if (ingredientLines.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(AppStrings.shareIngredientsHeading);
      for (final String line in ingredientLines) {
        buffer.writeln(line);
      }
    }

    // --- Instructions ---
    // Numbered from the surviving steps, so skipping a blank one does not leave
    // a gap in the sequence.
    final List<String> steps = <String>[];
    for (final String instruction in recipe.instructions) {
      final String step = _clean(instruction);
      if (step.isEmpty) continue;
      steps.add(step);
    }
    if (steps.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(AppStrings.shareInstructionsHeading);
      for (int i = 0; i < steps.length; i++) {
        buffer.writeln('${i + 1}. ${steps[i]}');
      }
    }

    // --- Attribution ---
    // Always present: it is what makes a forwarded recipe traceable back to the
    // app, and it is the only line guaranteed to survive an empty recipe.
    buffer
      ..writeln()
      ..write(AppStrings.shareAttribution);

    return _clamp(buffer.toString());
  }

  /// Normalises one field: trims, collapses runs of whitespace, and elides
  /// anything past [maxFieldLength].
  ///
  /// Collapsing whitespace matters because AI-generated text frequently carries
  /// embedded newlines mid-sentence, which would otherwise break the bullet and
  /// numbered-list formatting apart.
  static String _clean(String value) {
    final String collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxFieldLength) return collapsed;
    // Cut on a rune boundary so an elided emoji/accented character cannot be
    // split into an invalid surrogate pair.
    return '${_truncateOnRuneBoundary(collapsed, maxFieldLength)}…';
  }

  /// Clamps the whole message to [maxLength], appending an ellipsis when cut.
  static String _clamp(String value) {
    if (value.length <= maxLength) return value;
    return '${_truncateOnRuneBoundary(value, maxLength)}…';
  }

  /// Truncates [value] to at most [limit] code units without splitting a
  /// surrogate pair (which would produce an invalid, un-renderable string).
  static String _truncateOnRuneBoundary(String value, int limit) {
    if (value.length <= limit) return value;
    int end = limit;
    // A high surrogate at the cut point means its low surrogate is on the other
    // side; step back one so the pair stays intact.
    final int unit = value.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      end -= 1;
    }
    return value.substring(0, end).trimRight();
  }
}
