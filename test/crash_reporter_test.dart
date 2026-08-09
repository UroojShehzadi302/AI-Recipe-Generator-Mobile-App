// The crash-reporting seam (M14): it must record what it is given, and it must
// never throw.
//
// The second half matters more than the first. Every caller of this seam is
// itself an error handler — `runZonedGuarded`, `FlutterError.onError`,
// `PlatformDispatcher.onError` — so a throw from the reporter escapes into the
// zone that was supposed to contain the original error, turning one contained
// failure into an uncontained one. These tests therefore push deliberately
// hostile input at it: null stacks, error objects whose `toString` throws,
// `null` itself, and an implementation that throws on every method.
//
// Firebase-free throughout, like the rest of the suite.

import 'package:ai_recipe_generator/services/crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [CrashReporter] that remembers every call, so tests can assert on what the
/// seam actually forwarded.
class _RecordingCrashReporter implements CrashReporter {
  final List<Map<String, Object?>> errors = <Map<String, Object?>>[];
  final List<String> logs = <String>[];
  final List<String?> userIds = <String?>[];

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    errors.add(<String, Object?>{
      'error': error,
      'stack': stack,
      'fatal': fatal,
    });
  }

  @override
  void log(String message) => logs.add(message);

  @override
  void setUserId(String? userId) => userIds.add(userId);
}

/// A reporter that fails on every method, standing in for a broken backend (or
/// a third-party SDK that throws where it promised not to).
class _ThrowingCrashReporter implements CrashReporter {
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    throw StateError('reporter is down');
  }

  @override
  void log(String message) => throw StateError('reporter is down');

  @override
  void setUserId(String? userId) => throw StateError('reporter is down');
}

/// An error object whose `toString` throws.
///
/// Not hypothetical: a model or exception class with a buggy `toString` is a
/// real thing, and it would blow up any reporter that interpolates the error
/// into a string — which is exactly what [DebugCrashReporter] does.
class _HostileError {
  @override
  String toString() => throw StateError('toString is broken');
}

void main() {
  // The seam is a global, so every test restores the default to avoid leaking
  // an override into the next one.
  tearDown(() => CrashReporter.instance = null);

  group('default reporter', () {
    test('is a DebugCrashReporter before anything is installed', () {
      expect(CrashReporter.report, isA<DebugCrashReporter>());
    });

    test('setting instance to null restores the default', () {
      CrashReporter.instance = _RecordingCrashReporter();
      expect(CrashReporter.report, isA<_RecordingCrashReporter>());

      CrashReporter.instance = null;
      expect(CrashReporter.report, isA<DebugCrashReporter>());
    });

    test('report always resolves to a non-null reporter', () {
      // Callers are error handlers; a null check there is a null check that
      // will one day be forgotten.
      expect(CrashReporter.report, isNotNull);
    });
  });

  group('DebugCrashReporter never throws', () {
    const DebugCrashReporter reporter = DebugCrashReporter();

    test('with an error and a real stack trace', () {
      expect(
        () => reporter.recordError(
          Exception('boom'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('with a null stack trace', () {
      expect(
        () => reporter.recordError(Exception('boom'), null),
        returnsNormally,
      );
    });

    test('with a weird error object', () {
      // Anything can be thrown in Dart, not just Exceptions.
      expect(() => reporter.recordError(42, null), returnsNormally);
      expect(() => reporter.recordError('a bare string', null), returnsNormally);
      expect(
        () => reporter.recordError(<String, int>{'a': 1}, null),
        returnsNormally,
      );
      expect(
        () => reporter.recordError(_HostileError(), null),
        // The reporter interpolates the error into a string. A `toString` that
        // throws must be contained by the seam, not propagated.
        throwsA(anything),
        reason: 'raw impl may throw; the seam is what must contain it',
      );
    });

    test('when called repeatedly', () {
      // Only a handful, because this reporter really does print: a 200-call
      // loop would bury the rest of the suite's output in stack traces. The
      // point is that it holds no state that could degrade, not that it
      // survives volume.
      for (int i = 0; i < 5; i++) {
        expect(
          () => reporter.recordError(Exception('boom $i'), StackTrace.current),
          returnsNormally,
        );
      }
    });

    test('for log and setUserId, including null and empty values', () {
      expect(() => reporter.log(''), returnsNormally);
      expect(() => reporter.log('opened recipe detail'), returnsNormally);
      expect(() => reporter.setUserId(null), returnsNormally);
      expect(() => reporter.setUserId(''), returnsNormally);
      expect(() => reporter.setUserId('uid-123'), returnsNormally);
    });
  });

  group('NullCrashReporter', () {
    const NullCrashReporter reporter = NullCrashReporter();

    test('discards everything without throwing', () {
      expect(
        () => reporter.recordError(_HostileError(), null),
        returnsNormally,
        reason: 'it never touches the error object',
      );
      expect(() => reporter.recordError(Exception('x'), null), returnsNormally);
      expect(() => reporter.log('x'), returnsNormally);
      expect(() => reporter.setUserId('x'), returnsNormally);
    });
  });

  group('the seam records what it is given', () {
    late _RecordingCrashReporter reporter;

    setUp(() {
      reporter = _RecordingCrashReporter();
      CrashReporter.instance = reporter;
    });

    test('forwards the error, the stack, and the fatal flag', () {
      final Exception error = Exception('kaboom');
      final StackTrace stack = StackTrace.current;

      CrashReporter.recordErrorSafely(error, stack, fatal: true);

      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single['error'], same(error));
      expect(reporter.errors.single['stack'], same(stack));
      expect(reporter.errors.single['fatal'], isTrue);
    });

    test('defaults to non-fatal', () {
      // The app's global handlers report non-fatally: Flutter has already
      // contained the error by then, so marking it fatal would misreport
      // crash-free-user stability.
      CrashReporter.recordErrorSafely(Exception('x'), null);
      expect(reporter.errors.single['fatal'], isFalse);
    });

    test('forwards a null stack unchanged', () {
      CrashReporter.recordErrorSafely(Exception('x'), null);
      expect(reporter.errors.single['stack'], isNull);
    });

    test('forwards breadcrumbs and user ids', () {
      CrashReporter.logSafely('tapped save');
      CrashReporter.setUserIdSafely('uid-abc');
      CrashReporter.setUserIdSafely(null);

      expect(reporter.logs, <String>['tapped save']);
      expect(reporter.userIds, <String?>['uid-abc', null]);
    });

    test('records every call in order', () {
      for (int i = 0; i < 5; i++) {
        CrashReporter.recordErrorSafely(Exception('e$i'), null);
      }
      expect(reporter.errors, hasLength(5));
      expect(
        reporter.errors.first['error'].toString(),
        contains('e0'),
      );
      expect(
        reporter.errors.last['error'].toString(),
        contains('e4'),
      );
    });

    test('a later install replaces the earlier reporter', () {
      final _RecordingCrashReporter second = _RecordingCrashReporter();
      CrashReporter.instance = second;

      CrashReporter.recordErrorSafely(Exception('x'), null);

      expect(reporter.errors, isEmpty);
      expect(second.errors, hasLength(1));
    });
  });

  group('the seam contains a broken implementation', () {
    // The critical property: a crash reporter that crashes is worse than none,
    // because the caller IS the app's global error handler.
    setUp(() => CrashReporter.instance = _ThrowingCrashReporter());

    test('recordErrorSafely swallows the reporter s failure', () {
      expect(
        () => CrashReporter.recordErrorSafely(
          Exception('boom'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('logSafely and setUserIdSafely swallow it too', () {
      expect(() => CrashReporter.logSafely('x'), returnsNormally);
      expect(() => CrashReporter.setUserIdSafely('uid'), returnsNormally);
    });

    test('keeps swallowing across repeated calls', () {
      for (int i = 0; i < 50; i++) {
        expect(
          () => CrashReporter.recordErrorSafely(Exception('e$i'), null),
          returnsNormally,
        );
      }
    });
  });

  group('the seam survives hostile input end to end', () {
    test('a default reporter given an error whose toString throws', () {
      // DebugCrashReporter interpolates the error, so this throws inside the
      // implementation — and the seam must absorb it. This is precisely the
      // case `recordErrorSafely` exists for.
      expect(
        () => CrashReporter.recordErrorSafely(_HostileError(), null),
        returnsNormally,
      );
    });

    test('null-ish and unusual error objects reach a recording reporter', () {
      final _RecordingCrashReporter reporter = _RecordingCrashReporter();
      CrashReporter.instance = reporter;

      CrashReporter.recordErrorSafely(0, null);
      CrashReporter.recordErrorSafely('', null);
      CrashReporter.recordErrorSafely(<int>[], StackTrace.empty);

      expect(reporter.errors, hasLength(3));
      expect(reporter.errors[2]['stack'], StackTrace.empty);
    });
  });
}
