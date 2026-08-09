import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/ai_config.dart';
import 'core/utils/app_image_cache.dart';
import 'firebase_options.dart';
import 'providers/text_scale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/crash_reporter.dart';
import 'services/notification_service.dart';
import 'services/notification_store.dart';

/// Background/terminated-state FCM handler.
///
/// Must be a top-level (or static) function annotated with `vm:entry-point` so
/// the background isolate can find it. It runs in its own isolate, so it
/// initializes Firebase independently before touching any Firebase API. Kept
/// minimal and non-fatal: the OS already renders the `notification` payload in
/// the system tray, so there is nothing more to do here for a basic message.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Logged so a background/terminated delivery is visible in logcat — without
  // it, "the message never arrived" and "the message arrived and the OS drew
  // the tray notification" look identical from the developer's side.
  // Debug builds only — the payload is user-facing content and must not sit in
  // a release logcat that any app on the device can read.
  if (kDebugMode) {
    debugPrint(
      'FCM background message: id="${message.messageId}" '
      'title="${message.notification?.title}" '
      'body="${message.notification?.body}" data=${message.data}',
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Best-effort only — never let a background handler crash the isolate.
  }

  // Persist it so the in-app inbox shows notifications that arrived while the
  // app was closed, even if the user never taps the tray notification. This
  // isolate has no access to the provider graph, hence the static store; the
  // main isolate merges these in via `NotificationProvider.refresh()` on
  // resume. Best-effort — the store swallows its own failures.
  await NotificationStore.append(
    NotificationService.toAppNotification(message),
  );
}

Future<void> main() async {
  // Everything runs inside a guarded zone so an async error thrown outside the
  // widget tree (a repository future, a stream callback) is reported instead of
  // vanishing into the void. Without this, the app can misbehave in release
  // with nothing at all in the logs to explain why.
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Size the in-memory decoded-image cache for a budget Android phone.
      // Must run after the binding exists (it touches PaintingBinding) and is
      // cheap, so it goes first. See AppImageCache for the measured reasoning
      // behind the number — it is not an arbitrary round figure.
      AppImageCache.configureMemoryCache();

      // Framework-level errors (build/layout/paint). In debug, keep Flutter's
      // red-screen behaviour; in release, log and carry on rather than letting
      // an isolated widget failure take down the screen.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _reportError(details.exception, details.stack);
      };

      // Errors from the platform side (plugins, engine).
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _reportError(error, stack);
        return true;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // ── Crash reporting (M14) ──────────────────────────────────────────────
      // Prepared but NOT adopted: no reporting backend is wired, so the default
      // DebugCrashReporter stays installed (logs in debug, silent in release).
      // Adopting Crashlytics is ONE line, and it belongs right here — after
      // Firebase.initializeApp, since the reporter resolves
      // FirebaseCrashlytics.instance:
      //
      //   CrashReporter.instance = CrashlyticsCrashReporter();
      //
      // Full checklist (pubspec, Gradle plugin, Firebase console step) is in
      // the ADOPTION block at the top of services/crash_reporter.dart.

      // Register the background message handler (top-level, vm:entry-point)
      // after Firebase is initialized and before runApp. Non-fatal on failure.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Resolve the AI key/model once at startup. Tries Firebase Remote Config
      // first (owner-changeable post-deploy), then the bundled env.json, then
      // --dart-define. Requires Firebase to be initialized first (above).
      final AiConfig aiConfig = await AiConfig.load();

      // Resolve the saved light/dark preference before the first frame. Doing
      // this after runApp would paint one light frame and then correct itself,
      // which reads as a flash on every launch for a dark-mode user.
      final ThemeProvider themeProvider = await ThemeProvider.load(
        platformBrightness:
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );

      // Same reasoning as the theme: resolving the text size after the first
      // frame would paint once at the default and then reflow every screen.
      final TextScaleProvider textScaleProvider = await TextScaleProvider.load();

      runApp(
        RecipeGeneratorApp(
          aiConfig: aiConfig,
          themeProvider: themeProvider,
          textScaleProvider: textScaleProvider,
        ),
      );
    },
    _reportError,
  );
}

/// Single funnel for uncaught errors.
///
/// It stays one function so every error site — the guarded zone,
/// `FlutterError.onError`, and `PlatformDispatcher.onError` — reports through
/// the same path. The path itself is now the [CrashReporter] seam, so adopting
/// Crashlytics means installing a different reporter in `main()` rather than
/// editing this function; see the ADOPTION block in `services/crash_reporter.dart`.
///
/// Reported as NON-fatal: by the time these handlers run Flutter has already
/// contained the error and the app is still alive, so flagging a fatal crash
/// would misreport the app's stability.
///
/// The default [DebugCrashReporter] logs in debug and stays silent in release —
/// byte-for-byte what this function did inline before the seam existed.
void _reportError(Object error, StackTrace? stack) {
  CrashReporter.recordErrorSafely(error, stack);
}
