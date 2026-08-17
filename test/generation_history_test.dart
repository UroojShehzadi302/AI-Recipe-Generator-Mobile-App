// Tests for recording an AI generation in Usage History.
//
// Until 2026-08-17 only `saveRecipe` wrote to `users/{uid}/generatedRecipes`,
// so a user who generated ten recipes and kept none opened Usage History to an
// empty screen — while the screen itself, CLAUDE.md, and the Play listing all
// promised "every recipe you've generated". `recordGeneration` closes that gap.
//
// The interesting rule is that a generation must never overwrite a *kept*
// recipe's status: re-generating something already saved would otherwise
// silently unsave it.

import 'package:ai_recipe_generator/models/recipe_model.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures writes and serves scripted reads, with no Firebase behind it.
class _FakeFirestoreService extends FirestoreService {
  _FakeFirestoreService({this.existing});

  /// Document returned by [getDoc], or null for "does not exist".
  final Map<String, dynamic>? existing;

  final List<({String path, Map<String, dynamic> data, bool merge})> writes =
      <({String path, Map<String, dynamic> data, bool merge})>[];

  int getDocCalls = 0;
  bool throwOnWrite = false;

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async {
    getDocCalls++;
    return existing;
  }

  @override
  Future<void> setDoc(
    String path,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    if (throwOnWrite) throw StateError('firestore is down');
    writes.add((path: path, data: data, merge: merge));
  }
}

/// A repository wired to [firestore]; the AI and TheMealDB collaborators are
/// never reached by the code under test.
RecipeRepository _repoWith(FirestoreService firestore) => RecipeRepository(
      firestore,
      const UnconfiguredAiService(),
      MealDbService(),
    );

void main() {
  const Recipe recipe = Recipe(
    title: 'Chana Chaat',
    sourceType: 'ai',
  );

  group('recordGeneration', () {
    test('files a generated recipe so Usage History is not empty', () async {
      final _FakeFirestoreService firestore = _FakeFirestoreService();
      final RecipeRepository repo = _repoWith(firestore);

      await repo.recordGeneration('u1', recipe, prompt: 'something with chana');

      expect(firestore.writes, hasLength(1));
      final write = firestore.writes.single;
      expect(write.path, startsWith('users/u1/generatedRecipes/'));
      expect(write.data['status'], 'generated');
      expect(write.data['prompt'], 'something with chana');
      expect(write.merge, isTrue);
    });

    // The rule worth guarding. Same deterministic doc id as saveRecipe, so a
    // careless merge would flip a kept recipe back to merely 'generated'.
    test('never downgrades a recipe the user already saved', () async {
      final _FakeFirestoreService firestore = _FakeFirestoreService(
        existing: <String, dynamic>{'status': 'saved'},
      );
      final RecipeRepository repo = _repoWith(firestore);

      await repo.recordGeneration('u1', recipe, prompt: 'again');

      expect(firestore.writes, hasLength(1));
      expect(
        firestore.writes.single.data.containsKey('status'),
        isFalse,
        reason: 'status must be left alone so "saved" survives the merge',
      );
      // The prompt is still refreshed — the user did just ask for this again.
      expect(firestore.writes.single.data['prompt'], 'again');
    });

    test('omits an absent or blank prompt rather than storing an empty one',
        () async {
      for (final String? prompt in <String?>[null, '', '   ']) {
        final _FakeFirestoreService firestore = _FakeFirestoreService();
        final RecipeRepository repo = _repoWith(firestore);

        await repo.recordGeneration('u1', recipe, prompt: prompt);

        expect(firestore.writes.single.data.containsKey('prompt'), isFalse);
      }
    });

    // Bookkeeping must never break the thing being booked. The recipe is
    // already on screen by this point.
    test('swallows a write failure instead of surfacing it', () async {
      final _FakeFirestoreService firestore = _FakeFirestoreService()
        ..throwOnWrite = true;
      final RecipeRepository repo = _repoWith(firestore);

      await expectLater(
        repo.recordGeneration('u1', recipe, prompt: 'x'),
        completes,
      );
    });
  });
}
