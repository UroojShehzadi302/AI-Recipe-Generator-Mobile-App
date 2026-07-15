import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/ai_config.dart';
import 'firebase_options.dart';

/// Background/terminated-state FCM handler.
///
/// Must be a top-level (or static) function annotated with `vm:entry-point` so
/// the background isolate can find it. It runs in its own isolate, so it
/// initializes Firebase independently before touching any Firebase API. Kept
/// minimal and non-fatal: the OS already renders the `notification` payload in
/// the system tray, so there is nothing more to do here for a basic message.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Best-effort only — never let a background handler crash the isolate.
  }
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
