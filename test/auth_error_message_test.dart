// Guards the diagnosability of auth errors.
//
// On 2026-08-17 a Play-signed build refused every login and registration while
// showing only "Something went wrong". The real cause — Google rejecting the
// request because that build's signing certificate was not yet registered
// against the API key — was only visible over USB with `adb logcat`, and
// finding it cost most of a day.
//
// Two things came out of that and are pinned here: the blocked-client case has
// a message that points at the actual cause, and every auth message carries its
// code so a screenshot is enough to identify the failure.

import 'package:ai_recipe_generator/core/error/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMapper.withCode', () {
    test('appends the code so a user-facing error stays reportable', () {
      expect(
        ErrorMapper.withCode('That email looks invalid.', 'invalid-email'),
        'That email looks invalid. (invalid-email)',
      );
    });

    test('leaves the message alone when there is no code', () {
      const String message = 'Something went wrong.';
      expect(ErrorMapper.withCode(message, null), message);
      expect(ErrorMapper.withCode(message, ''), message);
      expect(ErrorMapper.withCode(message, '   '), message);
    });
  });

  group('blocked-client mapping', () {
    // The failure this whole file exists for. Firebase reports it as a bare
    // `internal-error`, which previously fell through to the generic fallback
    // and told the user — and the developer — nothing at all.
    test('names the cause instead of falling back to "something went wrong"',
        () {
      for (final String code in <String>[
        'app-not-authorized',
        'internal-error',
      ]) {
        final String message = ErrorMapper.authMessage(code);
        expect(
          message,
          isNot(contains('Something went wrong')),
          reason: '$code must not collapse into the generic fallback',
        );
        expect(message.toLowerCase(), contains('authorised'));
      }
    });
  });

  group('authMessage', () {
    test('still maps the everyday codes it always did', () {
      expect(ErrorMapper.authMessage('wrong-password'),
          contains('Incorrect password'));
      expect(ErrorMapper.authMessage('email-already-in-use'),
          contains('already exists'));
      expect(ErrorMapper.authMessage('network-request-failed'),
          contains('Network error'));
    });

    test('unknown codes keep the safe generic fallback', () {
      expect(
        ErrorMapper.authMessage('some-code-invented-tomorrow'),
        'Something went wrong. Please try again.',
      );
    });

    test('never leaks a raw exception or stack trace to the user', () {
      // The mapper takes a code, not an exception — this pins that the output
      // is a fixed sentence rather than anything echoed back from Firebase.
      final String message = ErrorMapper.authMessage(
        'Exception: FirebaseError at package:firebase_auth/foo.dart:42',
      );
      expect(message, 'Something went wrong. Please try again.');
    });
  });
}
