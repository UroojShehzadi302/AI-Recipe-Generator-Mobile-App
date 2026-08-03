// Central configuration for the generative-AI layer.
//
// This is the ONE place the app learns which Gemini model to call and what API
// key to use. Nothing else in the codebase reads the key directly, so rotating
// it, changing models, or moving to a server-side proxy (Cloud Functions) later
// touches only this file + the service implementation — never repositories,
// providers, or UI.
//
// ## Where the values come from (dev phase)
// Resolution order (see [AiConfig.load]):
//   1. **Firebase Remote Config** — parameters `gemini_api_key` + `gemini_model`.
//      This lets the owner change the key from the Firebase console AFTER the app
//      is published, WITHOUT rebuilding/republishing. Requires Firebase to be
//      initialized first (it is, in `main.dart`).
//   2. **Bundled `env.json` asset** — the local-dev fallback so `flutter run`
//      works before the console value is set (git-ignored; see `env.example.json`).
//   3. **Compile-time `--dart-define`s** ([AiConfig.fromEnvironment]) — last resort.
//
// `env.json` (git-ignored):
// ```json
// { "GEMINI_API_KEY": "AIza...", "GEMINI_MODEL": "gemini-flash-latest" }
// ```
//
// ## Owner step (production)
// Firebase console → Remote Config → add parameter `gemini_api_key` (value = the
// Gemini key) and optionally `gemini_model`, then Publish. The running app picks
// it up on the next fetch (min interval 1h) — no rebuild needed.
//
// ## Security note (read this)
// A key delivered to the client — via Remote Config, dart-define, OR env.json —
// is still extractable from the running app. That is an accepted trade-off for a
// free-tier, dev/portfolio build; it is exactly the reason the production plan
// proxies Gemini through a Cloud Function (backend doc D7). Remote Config only
// makes the key changeable without a rebuild — it does not hide it. Rotate/delete
// the key after demos.

import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Immutable configuration for the AI service (API key + model id).
class AiConfig {
  /// Creates an [AiConfig].
  const AiConfig({
    required this.apiKey,
    this.model = _defaultModel,
  });

  /// Resolves the configuration at startup (call once from `main.dart`).
  ///
  /// Order of precedence:
  /// 1. **Firebase Remote Config** (`gemini_api_key` / `gemini_model`) — lets the
  ///    owner change the key post-deploy from the console without a rebuild.
  /// 2. The bundled `env.json` asset (local-dev fallback).
  /// 3. Compile-time `--dart-define`s ([AiConfig.fromEnvironment]).
  ///
  /// Never throws: any Remote Config error (offline, Firebase not initialized in
  /// unit tests, parameter unset) is caught and falls through to (2)/(3), which
  /// yield an empty key → [isConfigured] is false → AI shows "coming soon".
  static Future<AiConfig> load() async {
    // 1. Firebase Remote Config (best-effort; never fatal).
    try {
      final AiConfig? fromRemote = await _loadFromRemoteConfig();
      if (fromRemote != null && fromRemote.isConfigured) return fromRemote;
    } catch (_) {
      // Remote Config unavailable (offline / not configured / no Firebase in
      // tests) — fall through to the bundled asset.
    }

    // 2. Bundled env.json asset (local-dev fallback).
    try {
      final String raw = await rootBundle.loadString('env.json');
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        final AiConfig fromAsset =
            AiConfig.fromMap(Map<String, dynamic>.from(decoded));
        if (fromAsset.isConfigured) return fromAsset;
      }
    } catch (_) {
      // No bundled env.json (or unreadable/invalid) — fall back to dart-define.
    }

    // 3. Compile-time dart-define values.
    return AiConfig.fromEnvironment();
  }

  /// Reads the key/model from Firebase Remote Config.
  ///
  /// Returns `null` (rather than throwing) so [load] can fall through cleanly.
  /// Requires `Firebase.initializeApp` to have run — in unit tests it hasn't, so
  /// accessing `FirebaseRemoteConfig.instance` throws and we fall back.
  static Future<AiConfig?> _loadFromRemoteConfig() async {
    final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Key changes propagate on the next fetch after this interval.
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.setDefaults(const <String, Object>{
      _keyParam: '',
      _modelParam: _defaultModel,
    });
    await remoteConfig.fetchAndActivate();

    final String key = remoteConfig.getString(_keyParam).trim();
    if (key.isEmpty) return null;

    final String model = remoteConfig.getString(_modelParam).trim();
    return AiConfig(apiKey: key, model: model.isEmpty ? _defaultModel : model);
  }

  /// Builds a config from a decoded `env.json` map (`GEMINI_API_KEY` /
  /// `GEMINI_MODEL`). Missing values become empty / the default model.
  factory AiConfig.fromMap(Map<String, dynamic> map) {
    final String key = (map['GEMINI_API_KEY'] ?? '').toString().trim();
    final String model = (map['GEMINI_MODEL'] ?? '').toString().trim();
    return AiConfig(apiKey: key, model: model.isEmpty ? _defaultModel : model);
  }

  /// Builds the config from compile-time environment values (dart-define).
  ///
  /// Returns an [AiConfig] with an empty [apiKey] when nothing is provided, so
  /// callers can branch on [isConfigured] rather than crashing at startup.
  factory AiConfig.fromEnvironment() {
    const String key = String.fromEnvironment('GEMINI_API_KEY');
    const String model =
        String.fromEnvironment('GEMINI_MODEL', defaultValue: _defaultModel);
    return const AiConfig(apiKey: key, model: model);
  }

  /// The Gemini Developer API key. Empty when unset.
  final String apiKey;

  /// The Gemini model id to call (e.g. `gemini-flash-latest`).
  final String model;

  /// Remote Config parameter name for the Gemini API key.
  static const String _keyParam = 'gemini_api_key';

  /// Remote Config parameter name for the Gemini model id.
  static const String _modelParam = 'gemini_model';

  /// Default model. Uses the `-latest` flash alias because pinned versions
  /// (e.g. `gemini-2.0-flash`) can have zero free-tier quota on some projects,
  /// whereas the alias routes to a model with free quota. Override via the
  /// `gemini_model` Remote Config parameter or `GEMINI_MODEL` in `env.json`.
  static const String _defaultModel = 'gemini-flash-latest';

  /// Whether a usable API key is present. When `false`, the app wires the
  /// [UnconfiguredAiService] and AI features report "coming soon" instead of
  /// making a network call.
  bool get isConfigured => apiKey.trim().isNotEmpty;
}
