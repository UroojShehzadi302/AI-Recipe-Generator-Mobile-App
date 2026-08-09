// Recipe sharing: text composition + the ShareService seam.
//
// The composition half is the valuable part and is exercised hard here, because
// it is pure Dart with no platform dependency: a Recipe can arrive straight
// from an LLM with missing fields, empty lists, or absurd lengths, and
// `RecipeShareText.compose` must never throw on any of it.
//
// The service half is covered at the seam only — asserting that the interface's
// contract (never throws, reports which path ran) holds — since the actual
// platform channel has no handler in a test environment.

import 'package:ai_recipe_generator/core/constants/app_strings.dart';
import 'package:ai_recipe_generator/core/utils/recipe_share_text.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';
import 'package:ai_recipe_generator/services/platform_share_service.dart';
import 'package:ai_recipe_generator/services/share_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fully-populated recipe, representing the happy path.
Recipe _fullRecipe() => const Recipe(
      recipeId: 'r1',
      title: 'Chicken Karahi',
      description: 'A rich Pakistani classic cooked in a wok.',
      imageUrl: 'https://example.com/karahi.jpg',
      category: 'dinner',
      cookingTimeMinutes: 45,
      difficulty: 'medium',
      servings: 4,
      calories: 520,
      nutrition: Nutrition(protein: 35, carbs: 12, fat: 30, fiber: 3),
      ingredients: <Ingredient>[
        Ingredient(name: 'chicken', quantity: '1 kg'),
        Ingredient(name: 'tomatoes', quantity: '4 medium'),
        Ingredient(name: 'ginger', quantity: '2 tbsp'),
      ],
      instructions: <String>[
        'Heat oil in a karahi.',
        'Add chicken and sear until golden.',
        'Add tomatoes and simmer.',
      ],
      tips: <String>['Serve with naan.'],
      tags: <String>['pakistani', 'spicy'],
      sourceType: 'curated',
    );

void main() {
  // Required by the seam tests below, which mock the platform channel. The
  // composition tests need no binding, but initializing once is harmless.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeShareText.compose — full recipe', () {
    test('includes title, description, stats, ingredients and steps', () {
      final String text = RecipeShareText.compose(_fullRecipe());

      expect(text, contains('Chicken Karahi'));
      expect(text, contains('A rich Pakistani classic cooked in a wok.'));

      // Stats appear with their labels and values.
      expect(text, contains('${AppStrings.shareTimeLabel}: 45'));
      expect(text, contains('${AppStrings.shareServesLabel}: 4'));
      expect(text, contains('${AppStrings.shareCaloriesLabel}: 520'));

      // Ingredients are bulleted as "quantity name".
      expect(text, contains(AppStrings.shareIngredientsHeading));
      expect(text, contains('• 1 kg chicken'));
      expect(text, contains('• 4 medium tomatoes'));

      // Instructions are numbered from 1.
      expect(text, contains(AppStrings.shareInstructionsHeading));
      expect(text, contains('1. Heat oil in a karahi.'));
      expect(text, contains('2. Add chicken and sear until golden.'));
      expect(text, contains('3. Add tomatoes and simmer.'));
    });

    test('always ends with the attribution line', () {
      final String text = RecipeShareText.compose(_fullRecipe());
      expect(text.trimRight(), endsWith(AppStrings.shareAttribution));
      expect(text, contains(AppStrings.appName));
    });

    test('does not leak internal fields the reader has no use for', () {
      final String text = RecipeShareText.compose(_fullRecipe());
      // The image URL and the storage id are plumbing, not content.
      expect(text, isNot(contains('https://example.com/karahi.jpg')));
      expect(text, isNot(contains('r1')));
    });
  });

  group('RecipeShareText.compose — missing and empty fields', () {
    test('a completely empty recipe still produces usable text', () {
      final String text = RecipeShareText.compose(const Recipe());

      expect(text, isNotEmpty);
      expect(text, contains(AppStrings.shareUntitledRecipe));
      expect(text, contains(AppStrings.shareAttribution));
    });

    test('Recipe.empty does not throw and omits every optional section', () {
      final String text = RecipeShareText.compose(Recipe.empty);

      expect(text, isNot(contains(AppStrings.shareIngredientsHeading)));
      expect(text, isNot(contains(AppStrings.shareInstructionsHeading)));
      expect(text, isNot(contains(AppStrings.shareTimeLabel)));
      expect(text, isNot(contains(AppStrings.shareServesLabel)));
      expect(text, isNot(contains(AppStrings.shareCaloriesLabel)));
    });

    test('an empty title falls back rather than emitting a blank line', () {
      final String text = RecipeShareText.compose(
        const Recipe(title: '', description: 'Tasty.'),
      );
      expect(text, contains(AppStrings.shareUntitledRecipe));
      expect(text.trimLeft(), startsWith(AppStrings.shareUntitledRecipe));
    });

    test('a whitespace-only title is treated as empty', () {
      final String text = RecipeShareText.compose(
        const Recipe(title: '   \n\t  '),
      );
      expect(text, contains(AppStrings.shareUntitledRecipe));
    });

    test('zero stats are omitted, not printed as 0', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Mystery Dish',
          cookingTimeMinutes: 0,
          servings: 0,
          calories: 0,
        ),
      );
      expect(text, isNot(contains('${AppStrings.shareTimeLabel}: 0')));
      expect(text, isNot(contains('${AppStrings.shareServesLabel}: 0')));
      expect(text, isNot(contains('${AppStrings.shareCaloriesLabel}: 0')));
    });

    test('a partial stat line prints only the stats that exist', () {
      final String text = RecipeShareText.compose(
        const Recipe(title: 'Half Known', cookingTimeMinutes: 20),
      );
      expect(text, contains('${AppStrings.shareTimeLabel}: 20'));
      expect(text, isNot(contains(AppStrings.shareServesLabel)));
      expect(text, isNot(contains(AppStrings.shareCaloriesLabel)));
    });
  });

  group('RecipeShareText.compose — no ingredients', () {
    test('omits the ingredients heading entirely when the list is empty', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Boiled Water',
          instructions: <String>['Boil it.'],
        ),
      );
      expect(text, isNot(contains(AppStrings.shareIngredientsHeading)));
      // The instructions section is unaffected.
      expect(text, contains(AppStrings.shareInstructionsHeading));
      expect(text, contains('1. Boil it.'));
    });

    test('skips ingredients that carry neither name nor quantity', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Sparse',
          ingredients: <Ingredient>[
            Ingredient(),
            Ingredient(name: 'salt', quantity: '1 tsp'),
            Ingredient(name: '', quantity: ''),
          ],
        ),
      );
      expect(text, contains('• 1 tsp salt'));
      // Exactly one bullet survived.
      expect('•'.allMatches(text).length, 1);
    });

    test('renders name-only and quantity-only ingredients without a gap', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Loose',
          ingredients: <Ingredient>[
            Ingredient(name: 'basil'),
            Ingredient(quantity: 'a pinch'),
          ],
        ),
      );
      expect(text, contains('• basil'));
      expect(text, contains('• a pinch'));
      // No double space from a missing half.
      expect(text, isNot(contains('•  ')));
    });

    test('a recipe with only blank ingredients drops the whole section', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Nothing',
          ingredients: <Ingredient>[Ingredient(), Ingredient()],
        ),
      );
      expect(text, isNot(contains(AppStrings.shareIngredientsHeading)));
    });
  });

  group('RecipeShareText.compose — instruction numbering', () {
    test('blank steps are skipped without leaving a gap in the numbers', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Gappy',
          instructions: <String>['First.', '', '   ', 'Second.', 'Third.'],
        ),
      );
      expect(text, contains('1. First.'));
      expect(text, contains('2. Second.'));
      expect(text, contains('3. Third.'));
      expect(text, isNot(contains('4.')));
    });

    test('omits the instructions heading when every step is blank', () {
      final String text = RecipeShareText.compose(
        const Recipe(title: 'Silent', instructions: <String>['', '  ']),
      );
      expect(text, isNot(contains(AppStrings.shareInstructionsHeading)));
    });
  });

  group('RecipeShareText.compose — long text', () {
    test('a very long field is elided at maxFieldLength', () {
      final String longDescription = 'x' * 2000;
      final String text = RecipeShareText.compose(
        Recipe(title: 'Long', description: longDescription),
      );

      expect(text, contains('…'));
      // The full 2000-char run must not survive.
      expect(text, isNot(contains('x' * 2000)));
      expect(text.length, lessThan(2000));
    });

    test('a pathological recipe is clamped to maxLength', () {
      final Recipe huge = Recipe(
        title: 'Huge',
        description: 'd' * 5000,
        ingredients: List<Ingredient>.generate(
          500,
          (int i) => Ingredient(name: 'ingredient $i', quantity: '$i g'),
        ),
        instructions: List<String>.generate(
          500,
          (int i) => 'Step number $i, described at some length.',
        ),
      );

      final String text = RecipeShareText.compose(huge);
      expect(text.length, lessThanOrEqualTo(RecipeShareText.maxLength + 1));
    });

    test('a long but reasonable recipe is not truncated', () {
      final String text = RecipeShareText.compose(_fullRecipe());
      expect(text.length, lessThan(RecipeShareText.maxLength));
      expect(text, isNot(contains('…')));
    });

    test('embedded newlines are collapsed so lists stay intact', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Multi\nLine\nTitle',
          instructions: <String>['Do this\nthen that.'],
        ),
      );
      // The title collapses onto one line.
      expect(text, contains('Multi Line Title'));
      // The step stays a single numbered entry.
      expect(text, contains('1. Do this then that.'));
    });
  });

  group('RecipeShareText.compose — special characters', () {
    test('preserves unicode, emoji, accents and scripts', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: 'Crème Brûlée 🍮',
          description: 'مزیدار — very tasty',
          ingredients: <Ingredient>[
            Ingredient(name: 'crème fraîche', quantity: '½ cup'),
          ],
          instructions: <String>['Caramelise the sugar 🔥'],
        ),
      );

      expect(text, contains('Crème Brûlée 🍮'));
      expect(text, contains('مزیدار'));
      expect(text, contains('½ cup crème fraîche'));
      expect(text, contains('Caramelise the sugar 🔥'));
    });

    test('does not corrupt surrogate pairs when truncating', () {
      // A long run of emoji, each a surrogate pair, forced past the field cap.
      final String emojiRun = '🍲' * 1000;
      final String text = RecipeShareText.compose(
        Recipe(title: 'Emoji', description: emojiRun),
      );

      // The result must be a valid string: re-encoding its runes round-trips.
      expect(() => String.fromCharCodes(text.runes), returnsNormally);
      expect(String.fromCharCodes(text.runes), text);
      // No lone surrogate survived the cut.
      for (final int unit in text.codeUnits) {
        if (unit >= 0xD800 && unit <= 0xDBFF) {
          // A high surrogate must be followed by a low surrogate.
          final int index = text.codeUnits.indexOf(unit);
          expect(index + 1, lessThan(text.codeUnits.length));
        }
      }
    });

    test('markdown and control characters pass through as literal text', () {
      final String text = RecipeShareText.compose(
        const Recipe(
          title: '**Bold** & <script>alert(1)</script>',
          instructions: <String>[r'Use 100% heat; add "salt" & $pepper'],
        ),
      );
      expect(text, contains('**Bold** & <script>alert(1)</script>'));
      expect(text, contains(r'Use 100% heat; add "salt" & $pepper'));
    });

    test('never throws on any hostile combination', () {
      final List<Recipe> hostile = <Recipe>[
        const Recipe(),
        Recipe.empty,
        const Recipe(title: ' '),
        Recipe(title: '\n' * 100, description: '\t' * 100),
        Recipe(
          title: '🍲' * 400,
          ingredients: <Ingredient>[Ingredient(name: '\n' * 600)],
          instructions: <String>['​' * 600],
        ),
      ];

      for (final Recipe recipe in hostile) {
        expect(
          () => RecipeShareText.compose(recipe),
          returnsNormally,
          reason: 'compose must never throw; failed on $recipe',
        );
      }
    });
  });

  group('PlatformShareService — the seam contract', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      // Tests run on the host (Windows/macOS/Linux), so the service would take
      // its clipboard path by default. Pretend to be Android for the tests that
      // exercise the share sheet; the desktop test overrides this itself.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('invokes Share.invoke with the composed text', () async {
      const ShareService service = PlatformShareService();
      final String text = RecipeShareText.compose(_fullRecipe());

      final ShareOutcome outcome = await service.share(text, subject: 'Karahi');

      expect(outcome, ShareOutcome.shared);
      final MethodCall shareCall =
          calls.firstWhere((MethodCall c) => c.method == 'Share.invoke');
      expect(shareCall.arguments, text);
    });

    test('uses the share sheet on iOS as well as Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const ShareService service = PlatformShareService();

      expect(await service.share('Recipe text'), ShareOutcome.shared);
      expect(
        calls.any((MethodCall c) => c.method == 'Share.invoke'),
        isTrue,
      );
    });

    test('empty text is a no-op rather than an empty share sheet', () async {
      const ShareService service = PlatformShareService();

      expect(await service.share(''), ShareOutcome.failed);
      expect(await service.share('   \n '), ShareOutcome.failed);
      expect(
        calls.where((MethodCall c) => c.method == 'Share.invoke'),
        isEmpty,
      );
    });

    test('falls back to the clipboard on a platform with no share sheet',
        () async {
      // Desktop/web: `Share.invoke` is not implemented there. Critically, that
      // case does NOT throw — SystemChannels.platform answers every call — so
      // the service must decide by platform, and this test pins that. An
      // exception-based implementation passes on Android and silently reports a
      // phantom success here.
      // Cleared by the group's tearDown.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      const ShareService service = PlatformShareService();
      final ShareOutcome outcome = await service.share('Recipe text');

      expect(outcome, ShareOutcome.copiedToClipboard);
      // The share sheet was never attempted...
      expect(
        calls.where((MethodCall c) => c.method == 'Share.invoke'),
        isEmpty,
      );
      // ...and the text really did reach the clipboard.
      expect(
        calls.any((MethodCall c) => c.method == 'Clipboard.setData'),
        isTrue,
      );
    });

    test('a platform error still degrades to the clipboard, never throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Share.invoke') {
          throw PlatformException(code: 'FAILED', message: 'target rejected');
        }
        return null;
      });

      const ShareService service = PlatformShareService();

      // The contract is that a platform failure surfaces as an outcome, never
      // as a thrown exception the caller has to catch.
      final ShareOutcome outcome = await service.share('Recipe text');
      expect(outcome, ShareOutcome.copiedToClipboard);
    });
  });
}
