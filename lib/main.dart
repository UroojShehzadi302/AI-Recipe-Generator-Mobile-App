import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/ai_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Resolve the AI key/model once at startup (reads the bundled env.json, so
  // AI works regardless of how the app is launched).
  final AiConfig aiConfig = await AiConfig.load();

  runApp(RecipeGeneratorApp(aiConfig: aiConfig));
}
