import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/ai_config.dart';
import 'firebase_options.dart';
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
  debugPrint(
    'FCM background message: id="${message.messageId}" '
    'title="${message.notification?.title}" '
    'body="${message.notification?.body}" data=${message.data}',
  );

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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the background message handler (top-level, vm:entry-point) after
  // Firebase is initialized and before runApp. Non-fatal on failure.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Resolve the AI key/model once at startup. Tries Firebase Remote Config
  // first (owner-changeable post-deploy), then the bundled env.json, then
  // --dart-define. Requires Firebase to be initialized first (above).
  final AiConfig aiConfig = await AiConfig.load();

  runApp(RecipeGeneratorApp(aiConfig: aiConfig));
}
