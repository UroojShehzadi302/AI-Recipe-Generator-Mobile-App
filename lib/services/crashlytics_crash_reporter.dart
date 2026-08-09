// The Crashlytics-backed [CrashReporter] (M14).
//
// This is the ONLY file in the app allowed to import `firebase_crashlytics`.
// Everything else — `main.dart`'s `_reportError`, and any future caller —
// depends on the [CrashReporter] interface, so swapping backends (or removing
// crash reporting entirely) touches one line in `main.dart` and this file.

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'crash_reporter.dart';

/// Reports errors to Firebase Crashlytics.
///
/// Installed in `main()` after `Firebase.initializeApp`. Until the owner
/// completes the console step (Release & Monitor → Crashlytics → Enable),
/// reports are collected by the SDK and simply have nowhere to land — this is
/// harmless and needs no code change when it is switched on.
class CrashlyticsCrashReporter implements CrashReporter {
  const CrashlyticsCrashReporter();

  /// Resolved lazily, never in the constructor.
  ///
  /// Same rule every other service here follows (see `auth_service.dart`,
  /// `notification_service.dart`): touching `FirebaseCrashlytics.instance` at
  /// construction time would make this un-constructible in a unit test with no
  /// Firebase, and would break `main()`, which builds the reporter on the same
  /// line it installs it.
  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Records [error] with its [stack].
  ///
  /// Deliberately NOT awaited. Callers are synchronous void handlers
  /// (`FlutterError.onError`, `PlatformDispatcher.onError`), and blocking an
  /// error handler on a network-backed write would turn a contained error into
  /// a visible stall. `unawaited` states that the fire-and-forget is intended
  /// rather than an overlooked future.
  ///
  /// Any failure is swallowed by [CrashReporter.recordErrorSafely], which wraps
  /// every call — a crash reporter that throws inside a crash handler turns one
  /// recoverable error into an unrecoverable one.
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    unawaited(_crashlytics.recordError(error, stack, fatal: fatal));
  }

  /// Adds a breadcrumb shown alongside the next report.
  ///
  /// ⚠️ Breadcrumbs ship off-device. Never pass credentials, API keys, AI
  /// prompts, or user content — see the contract note in `crash_reporter.dart`.
  @override
  void log(String message) => unawaited(_crashlytics.log(message));

  /// Associates subsequent reports with [userId], or clears it when null.
  ///
  /// The Firebase uid is an opaque identifier, not PII. Never pass the email
  /// address or display name. Crashlytics has no "unset" call, so clearing is
  /// an empty string.
  @override
  void setUserId(String? userId) =>
      unawaited(_crashlytics.setUserIdentifier(userId ?? ''));
}
