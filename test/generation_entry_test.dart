// Unit tests for the Usage History entry model.
//
// [GenerationEntry.fromMap] parses documents written by RecipeRepository, and
// has to survive partially-written or legacy documents (no prompt, no status,
// an unresolved server timestamp) without throwing — one bad row must not take
// down the whole history list.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_recipe_generator/models/generation_entry.dart';

/// The minimum a stored document needs for the entry to be usable.
Map<String, dynamic> _doc({
  Object? prompt,
  Object? status,
  Object? createdAt,
  Object? genId,
  Object? recipe,
}) {
  final Map<String, dynamic> map = <String, dynamic>{
    'genId': genId ?? 'chicken-biryani',
    'recipe': recipe ?? <String, dynamic>{'title': 'Chicken Biryani'},
  };
  // Assigned conditionally so each test can omit a field entirely and exercise
  // the "legacy document" path, rather than storing an explicit null.
  if (prompt != null) map['prompt'] = prompt;
  if (status != null) map['status'] = status;
  if (createdAt != null) map['createdAt'] = createdAt;
  return map;
}

/// Stands in for a Firestore `Timestamp`, which the model duck-types via
/// `toDate()` so it can stay free of a cloud_firestore import.
class _FakeTimestamp {
  _FakeTimestamp(this._value);
  final DateTime _value;
  DateTime toDate() => _value;
}

void main() {
  group('GenerationEntry.fromMap', () {
    test('parses a fully-populated document', () {
      final DateTime when = DateTime(2026, 3, 12, 14, 30);
      final GenerationEntry? entry = GenerationEntry.fromMap(
        _doc(
          prompt: '  vegan pasta for two  ',
          status: 'saved',
          createdAt: when,
        ),
      );

      expect(entry, isNotNull);
      expect(entry!.id, 'chicken-biryani');
      expect(entry.title, 'Chicken Biryani');
      // The prompt is trimmed so stray whitespace doesn't skew the layout.
      expect(entry.prompt, 'vegan pasta for two');
      expect(entry.hasPrompt, isTrue);
      expect(entry.status, GenerationStatus.saved);
      expect(entry.createdAt, when);
    });

    test('returns null when there is no recipe to show', () {
      expect(GenerationEntry.fromMap(<String, dynamic>{}), isNull);
      expect(
        GenerationEntry.fromMap(<String, dynamic>{'recipe': 'not-a-map'}),
        isNull,
      );
    });

    test('tolerates a legacy document with no prompt or status', () {
      final GenerationEntry? entry = GenerationEntry.fromMap(_doc());

      expect(entry, isNotNull);
      expect(entry!.prompt, isEmpty);
      expect(entry.hasPrompt, isFalse);
      // Unknown/missing status must not throw — it falls back to `generated`.
      expect(entry.status, GenerationStatus.generated);
      expect(entry.createdAt.millisecondsSinceEpoch, 0);
    });

    test('falls back to `generated` for an unrecognised status string', () {
      final GenerationEntry? entry =
          GenerationEntry.fromMap(_doc(status: 'something-else'));
      expect(entry!.status, GenerationStatus.generated);
    });

    test('reads a Firestore-style Timestamp via toDate()', () {
      final DateTime when = DateTime(2026, 1, 2, 3, 4);
      final GenerationEntry? entry =
          GenerationEntry.fromMap(_doc(createdAt: _FakeTimestamp(when)));
      expect(entry!.createdAt, when);
    });

    test('reads ISO strings and epoch millis', () {
      final GenerationEntry? iso = GenerationEntry.fromMap(
        _doc(createdAt: '2026-05-06T07:08:09.000'),
      );
      expect(iso!.createdAt, DateTime.parse('2026-05-06T07:08:09.000'));

      final GenerationEntry? millis =
          GenerationEntry.fromMap(_doc(createdAt: 1700000000000));
      expect(
        millis!.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('an unparseable date degrades to the epoch instead of throwing', () {
      final GenerationEntry? entry =
          GenerationEntry.fromMap(_doc(createdAt: 'not-a-date'));
      expect(entry!.createdAt.millisecondsSinceEpoch, 0);
    });

    test('falls back to the recipe title when the document has no id', () {
      final GenerationEntry? entry = GenerationEntry.fromMap(
        <String, dynamic>{
          'recipe': <String, dynamic>{'title': 'Karahi'},
        },
      );
      expect(entry!.id, 'Karahi');
    });

    test('title falls back for an untitled recipe', () {
      final GenerationEntry? entry = GenerationEntry.fromMap(
        <String, dynamic>{'recipe': <String, dynamic>{'title': '   '}},
      );
      expect(entry!.title, 'Untitled recipe');
    });
  });

  group('copyWith', () {
    test('changes only the status', () {
      final GenerationEntry entry =
          GenerationEntry.fromMap(_doc(prompt: 'p', status: 'generated'))!;
      final GenerationEntry updated =
          entry.copyWith(status: GenerationStatus.saved);

      expect(updated.status, GenerationStatus.saved);
      expect(updated.id, entry.id);
      expect(updated.prompt, entry.prompt);
      expect(updated.createdAt, entry.createdAt);
    });
  });
}
