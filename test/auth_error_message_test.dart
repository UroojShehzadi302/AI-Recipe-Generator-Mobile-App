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
import 'package:ai_recipe_generator/core/widgets/error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('ErrorMapper.withDetail', () {
    test('keeps the provider text, which is the part worth screenshotting', () {
      final String out = ErrorMapper.withDetail(
        "This app build isn't authorised to reach the server yet.",
        'An internal error has occurred. [ Requests from this Android client '
            'application com.urooj.cookmate are blocked. ]',
        'internal-error',
      );
      expect(out, contains("isn't authorised"));
      expect(out, contains('are blocked'));
      expect(out, contains('com.urooj.cookmate'));
      expect(out, contains('(internal-error)'));
      expect(out, contains('Details:'));
    });

    test('degrades to just the code when there is no detail', () {
      expect(
        ErrorMapper.withDetail('Incorrect password.', null, 'wrong-password'),
        'Incorrect password. (wrong-password)',
      );
      expect(
        ErrorMapper.withDetail('Incorrect password.', '  ', 'wrong-password'),
        'Incorrect password. (wrong-password)',
      );
    });

    test('does not repeat the message back when the detail duplicates it', () {
      const String message = 'Network error. Please try again.';
      expect(
        ErrorMapper.withDetail(message, message, 'network-request-failed'),
        '$message (network-request-failed)',
      );
    });

    test('puts the detail on its own line so a one-line box cannot hide it',
        () {
      final String out = ErrorMapper.withDetail('Short.', 'Long raw.', 'code');
      expect(out, contains('\n'));
      expect(out.split('\n').first, 'Short.');
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

  group('showErrorSnackBar', () {
    Future<void> pumpWith(WidgetTester tester, String message) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => ElevatedButton(
                onPressed: () => showErrorSnackBar(context, message),
                child: const Text('fail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
    }

    // The bug this group exists for. A SnackBar is bounded by its own width
    // and the screen, so the first attempt at this feature still truncated on
    // a real device at "...Android client application co..." — dropping the
    // package name, which is the identifying half of the whole string.
    testWidgets('shows the full provider text, untruncated, for a long error',
        (WidgetTester tester) async {
      final String message = ErrorMapper.withDetail(
        "This app build isn't authorised to reach the server yet.",
        'An internal error has occurred. [ Requests from this Android client '
            'application com.urooj.cookmate are blocked. ]',
        'internal-error',
      );

      await pumpWith(tester, message);

      expect(find.byType(AlertDialog), findsOneWidget);

      final SelectableText body = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final String shown = body.data ?? '';
      // The tail of the message is what a SnackBar ate; assert it survives.
      expect(shown, contains('com.urooj.cookmate'));
      expect(shown, contains('are blocked'));
      expect(shown, contains('(internal-error)'));
      expect(shown, isNot(contains('…')));
      expect(shown, isNot(contains('...')));
    });

    testWidgets('offers Copy, so the text can reach a bug report intact',
        (WidgetTester tester) async {
      const String message = 'Short.\n\nDetails: something long. (code)';
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await pumpWith(tester, message);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(
        (clipboardCalls.single.arguments as Map<Object?, Object?>)['text'],
        message,
        reason: 'the copy must be the whole message, not the visible part',
      );
    });

    testWidgets('keeps a short error as a lightweight SnackBar',
        (WidgetTester tester) async {
      await pumpWith(tester, 'Incorrect password. (wrong-password)');

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'a mistyped password does not deserve a modal dialog',
      );
    });
  });
}
