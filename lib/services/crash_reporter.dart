// The seam between the app and a crash-reporting backend (M14).
//
// Every uncaught error in this app already funnels through ONE place —
// `_reportError` in `main.dart`, fed by `runZonedGuarded`, `FlutterError.onError`
// and `PlatformDispatcher.instance.onError`. This file turns that funnel into a
// swappable seam, mirroring [AiService] and [ShareService]: `main.dart` depends
// on THIS interface, never on a concrete reporter, so adopting Crashlytics (or
// Sentry, or a self-hosted sink) does not touch the error-handling wiring.
//
// Implementations:
// * [DebugCrashReporter] — the default today. Prints to the console in debug
//                          and is completely silent in release. This is exactly
//                          what `_reportError` did before the seam existed, so
//                          installing the seam changed no behaviour at all.
// * (future) a Crashlytics-backed reporter — see the ADOPTION block below.
//
// Contract notes:
// * NO METHOD MAY EVER THROW. A crash reporter that crashes is worse than no
//   crash reporter: it turns one recoverable error into an unrecoverable one,
//   inside the very handler meant to contain it. Implementations swallow their
//   own failures, the same way `UsageRepository.record` and [NotificationStore]
//   do. [CrashReporter.report] enforces this defensively for ALL
//   implementations, including third-party ones.
// * NO METHOD MAY BLOCK. Reporting is bookkeeping on an error path; callers are
//   synchronous handlers (`FlutterError.onError` returns void) and will not
//   await anything.
// * NOTHING SENSITIVE MAY BE LOGGED. `debugPrint` is NOT stripped in release,
//   so anything printed unguarded is readable by any app on the device via
//   logcat — the same reason the FCM token and notification payloads sit behind
//   `kDebugMode`. Callers must not pass credentials, tokens, prompts, or user
//   content as breadcrumbs; see [log].
//
// ── Status (M14): ADOPTED ────────────────────────────────────────────────────
// `CrashlyticsCrashReporter` is installed in `main()` right after
// `Firebase.initializeApp`. The Gradle plugin is applied in both
// `android/settings.gradle.kts` and `android/app/build.gradle.kts` — required,
// not optional, because this app ships with R8 and that plugin uploads the
// obfuscation mapping file. Without it every release stack trace is unreadable.
//
// ⚠️ OWNER STEP OUTSTANDING: reports have nowhere to land until Crashlytics is
// enabled in the Firebase console (Release & Monitor → Crashlytics) for the
// **com.urooj.cookmate** app — two stale Android apps are also registered in
// this project, so pick carefully. Free plan; no Blaze needed. Crashlytics
// batches, so a crash uploads on the NEXT launch: relaunch before concluding it
// is broken. To force one from a debug build:
// `FirebaseCrashlytics.instance.crash();`
//
// Optional follow-up, not wired: call `CrashReporter.report.setUserId(uid)` on
// sign-in and `setUserId(null)` on sign-out from `AuthProvider` to correlate
// reports with an account. The Firebase uid is opaque, not PII — never pass an
// email or display name.
//
// The FCM background isolate has its OWN copy of every static, so it would need
// `CrashReporter.instance` set again inside `_firebaseMessagingBackgroundHandler`
// to report from there. Left unset it degrades to [DebugCrashReporter], which is
// safe — never a crash.

import 'package:flutter/foundation.dart';

/// Transport-level contract for reporting errors to a crash-reporting backend.
///
/// Implementations MUST NOT throw, MUST NOT block, and MUST NOT log anything
/// sensitive in release builds. Prefer calling through [CrashReporter.report],
/// which guarantees the non-throwing part even for implementations that forget.
abstract interface class CrashReporter {
  /// Records a non-fatal or fatal error with its [stack].
  ///
  /// [stack] is nullable because not every error site has one — a
  /// `PlatformDispatcher.onError` always supplies a stack, but a hand-rolled
  /// `reportError(e, null)` from a catch block may not.
  ///
  /// [fatal] marks the error as one that took the app down. The app's global
  /// handlers report non-fatally: Flutter has already contained the error by
  /// the time they run, so claiming a fatal crash would misreport stability.
  void recordError(Object error, StackTrace? stack, {bool fatal = false});

  /// Leaves a breadcrumb attached to any subsequent report.
  ///
  /// Breadcrumbs are what turn a bare stack trace into a reproducible story
  /// ("opened recipe → tapped save → crash"). Keep them to short, structural
  /// messages.
  ///
  /// ⚠️ NEVER pass user content or secrets — no API keys, no FCM tokens, no
  /// emails, no AI prompts, no recipe text. Breadcrumbs are uploaded to a
  /// third-party backend AND, in the default reporter, printed to the console.
  void log(String message);

  /// Associates subsequent reports with [userId], or clears it when `null`.
  ///
  /// Use the Firebase uid — an opaque identifier. It answers "is this one
  /// user hitting this a hundred times, or a hundred users once", which is the
  /// difference between a corrupt local state and a real bug.
  ///
  /// ⚠️ Never pass an email address, display name, or anything else that
  /// identifies a person directly.
  void setUserId(String? userId);

  // ---------------------------------------------------------------------------
  // Static access point.
  // ---------------------------------------------------------------------------
  //
  // WHY A STATIC HOLDER RATHER THAN A PROVIDER-GRAPH DEPENDENCY
  // ----------------------------------------------------------
  // The same reason [NotificationStore] is static, and it applies twice here:
  //
  // 1. The CALLERS are static. `FlutterError.onError`,
  //    `PlatformDispatcher.instance.onError` and the `runZonedGuarded` handler
  //    are global callbacks with no `BuildContext` and no access to the
  //    provider graph, and two of them are installed BEFORE `runApp`. There is
  //    nothing to inject into.
  //
  // 2. Errors happen when the graph may be gone. An error thrown while
  //    building the DI graph, during `Firebase.initializeApp`, or inside the
  //    FCM background isolate (a separate isolate with no providers at all)
  //    must still be reportable. A reporter reachable only through
  //    `context.read` is unreachable in exactly the situations that matter
  //    most.
  //
  // Note the shape: the INTERFACE is a normal instance interface — implementable,
  // mockable, injectable — and only the ACCESS POINT is static. That keeps the
  // seam swappable (`AiService`/`ShareService` style) while still being callable
  // from a static handler. A fully static class, by contrast, could not be
  // faked in a test.

  /// The active reporter. Defaults to [DebugCrashReporter] — console output in
  /// debug, silence in release — so the app behaves identically until a real
  /// backend is installed. Never `null`, so callers need no null check.
  ///
  /// Swap it once, early in `main()`, via [instance].
  static CrashReporter _instance = const DebugCrashReporter();

  /// The active reporter, guaranteed non-null.
  ///
  /// Read this rather than holding a reference, so a later [instance]
  /// assignment takes effect everywhere.
  static CrashReporter get report => _instance;

  /// Installs [reporter] as the active crash reporter.
  ///
  /// Passing `null` restores the default [DebugCrashReporter], which is what
  /// tests use to undo an override.
  static set instance(CrashReporter? reporter) {
    _instance = reporter ?? const DebugCrashReporter();
  }

  // ---------------------------------------------------------------------------
  // Guarded convenience wrappers.
  // ---------------------------------------------------------------------------
  //
  // Call sites use these instead of `report.recordError(...)` directly. They
  // wrap the active implementation in a try/catch so the "never throws" rule
  // holds even for an implementation that breaks it — including a third-party
  // one we do not control. This matters more than usual: the caller is an error
  // handler, so a throw here escapes into the zone that was supposed to contain
  // the original error.

  /// Reports [error] through the active reporter. Never throws.
  static void recordErrorSafely(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) {
    try {
      _instance.recordError(error, stack, fatal: fatal);
    } catch (_) {
      // Deliberately swallowed. A failure to report a crash must never become
      // a second crash — this runs inside the app's global error handler.
    }
  }

  /// Leaves a breadcrumb through the active reporter. Never throws.
  static void logSafely(String message) {
    try {
      _instance.log(message);
    } catch (_) {
      // See [recordErrorSafely].
    }
  }

  /// Sets the correlation id on the active reporter. Never throws.
  static void setUserIdSafely(String? userId) {
    try {
      _instance.setUserId(userId);
    } catch (_) {
      // See [recordErrorSafely].
    }
  }
}

/// The default [CrashReporter]: console output in debug, silence in release.
///
/// This reproduces EXACTLY what `_reportError` in `main.dart` did before the
/// seam existed — same `debugPrint` calls, same two lines, same order — so
/// introducing the seam is behaviour-neutral. It ships as the default because
/// no reporting backend is wired yet (M14 is prepared, not adopted).
///
/// ⚠️ The [kDebugMode] guards are load-bearing, not stylistic. `debugPrint` is
/// NOT compiled out of a release build, so an unguarded print here would push
/// error strings — which routinely embed URLs, ids, and fragments of user
/// content — into a release logcat that any other app on the device can read.
/// This is the same rule the FCM token and notification payloads follow.
class DebugCrashReporter implements CrashReporter {
  /// Creates a [DebugCrashReporter].
  const DebugCrashReporter();

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!kDebugMode) return;
    debugPrint('UNCAUGHT ERROR: $error');
    if (stack != null) debugPrint('$stack');
  }

  @override
  void log(String message) {
    if (!kDebugMode) return;
    debugPrint('[crash] $message');
  }

  @override
  void setUserId(String? userId) {
    // Nothing to correlate against without a backend. Deliberately silent even
    // in debug: a uid is an account identifier, and printing it on every
    // sign-in would put it in the log of every developer build for no benefit.
  }
}

/// A [CrashReporter] that discards everything, including in debug.
///
/// For tests that exercise error paths and would otherwise flood the output,
/// and for anywhere a reporter is structurally required but reporting is not
/// wanted. [DebugCrashReporter], not this, is the app default — silence is the
/// wrong default when a developer is looking at the console.
class NullCrashReporter implements CrashReporter {
  /// Creates a [NullCrashReporter].
  const NullCrashReporter();

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    // Intentionally empty.
  }

  @override
  void log(String message) {
    // Intentionally empty.
  }

  @override
  void setUserId(String? userId) {
    // Intentionally empty.
  }
}
