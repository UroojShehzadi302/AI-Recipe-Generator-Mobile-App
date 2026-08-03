// Locks in the password policy. These are security rules, not cosmetics: a
// regression here silently re-opens the app to trivially guessable passwords,
// and nothing else in the suite would catch it.

import 'package:ai_recipe_generator/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.password', () {
    test('accepts a password with letters and digits at the minimum length', () {
      expect(Validators.password('secret12'), isNull);
      expect(Validators.password('MyRecipe2026'), isNull);
    });

    test('rejects an empty password', () {
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password(null), 'Password is required');
      expect(Validators.password('        '), 'Password is required');
    });

    test('rejects anything shorter than the minimum', () {
      expect(Validators.passwordMinLength, 8);
      expect(Validators.password('abc1234'), contains('at least 8'));
    });

    test('rejects digits-only and letters-only passwords', () {
      // The two shapes people actually pick when only a length rule exists.
      expect(
        Validators.password('11111111'),
        'Password must include a letter and a number',
      );
      expect(
        Validators.password('password'),
        'Password must include a letter and a number',
      );
    });

    test('rejects an absurdly long password', () {
      final String tooLong = 'a1' * 100; // 200 chars
      expect(Validators.password(tooLong), contains('under'));
    });
  });

  group('Validators.aiPrompt', () {
    test('caps prompt length so one paste cannot drain the AI quota', () {
      expect(Validators.aiPrompt('x' * Validators.aiPromptMaxLength), isNull);
      expect(
        Validators.aiPrompt('x' * (Validators.aiPromptMaxLength + 1)),
        contains('or fewer'),
      );
    });
  });
}
