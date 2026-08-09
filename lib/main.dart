import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/ai_config.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
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

      runApp(
        RecipeGeneratorApp(aiConfig: aiConfig, themeProvider: themeProvider),
      );
    },
    _reportError,
  );
}

/// Single funnel for uncaught errors.
///
/// Today it logs. It is deliberately one function so wiring a crash reporter
/// (Crashlytics et al.) later is a one-line change here rather than a hunt
/// through every error site.
void _reportError(Object error, StackTrace? stack) {
  debugPrint('UNCAUGHT ERROR: $error');
  if (stack != null) debugPrint('$stack');
}
