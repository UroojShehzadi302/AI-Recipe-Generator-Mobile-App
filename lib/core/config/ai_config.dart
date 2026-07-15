// Central configuration for the generative-AI layer.
//
// This is the ONE place the app learns which Gemini model to call and what API
// key to use. Nothing else in the codebase reads the key directly, so rotating
// it, changing models, or moving to a server-side proxy (Cloud Functions) later
// touches only this file + the service implementation — never repositories,
// providers, or UI.
//
// ## Where the values come from (dev phase)
// Values are injected at build time via `--dart-define-from-file=env.json`
// (see `env.example.json`). This keeps the key out of source control and out of
// the bundled Flutter assets. Example run:
//
// ```
// flutter run --dart-define-from-file=env.json
// ```
//
// `env.json` (git-ignored):
// ```json
// { "GEMINI_API_KEY": "AIza...", "GEMINI_MODEL": "gemini-2.0-flash" }
// ```
//
// [AiConfig.load] (called once in `main.dart`) reads `env.json` at RUNTIME —
// bundled as a Flutter asset — so AI works no matter how the app is launched
// (IDE Run button, `flutter run`, a release build), without needing the
// `--dart-define-from-file` flag. If the asset is absent it falls back to the
// compile-time dart-define values ([AiConfig.fromEnvironment]).
//
// ## Security note (read this)
// A key shipped in the client — via dart-define OR .env — is extractable from
// the built APK. That is an accepted trade-off for a free-tier, dev/portfolio
// build; it is exactly the reason the production plan proxies Gemini through a
// Cloud Function (backend doc D7). Keep `env.json` git-ignored and rotate/delete
// the key after demos.

import 'dart:convert';

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
  /// 1. The bundled `env.json` asset (runtime read — works with any launch
  ///    method, no build flag needed).
  /// 2. Compile-time `--dart-define`s ([AiConfig.fromEnvironment]).
  ///
  /// Never throws: a missing/unreadable asset falls through to (2), which
  /// yields an empty key → [isConfigured] is false → AI shows "coming soon".
  static Future<AiConfig> load() async {
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
    return AiConfig.fromEnvironment();
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

  /// The Gemini model id to call (e.g. `gemini-2.0-flash`).
  final String model;

  /// Default model. Uses the `-latest` flash alias because pinned versions
  /// (e.g. `gemini-2.0-flash`) can have zero free-tier quota on some projects,
  /// whereas the alias routes to a model with free quota. Override via
  /// `GEMINI_MODEL` in `env.json`.
  static const String _defaultModel = 'gemini-flash-latest';

  /// Whether a usable API key is present. When `false`, the app wires the
  /// [UnconfiguredAiService] and AI features report "coming soon" instead of
  /// making a network call.
  bool get isConfigured => apiKey.trim().isNotEmpty;
}
