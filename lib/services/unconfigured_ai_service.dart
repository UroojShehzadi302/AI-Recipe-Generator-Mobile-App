// AI service used when no Gemini API key is configured.
//
// Selected by the DI graph (`app/app.dart`) whenever `AiConfig.isConfigured`
// is false. Every call throws [UnimplementedError], which the repository layer
// already maps to a friendly "coming soon" message — so with no key the app
// behaves exactly as it did before the AI layer was wired.

import 'ai_service.dart';

/// A no-op [AiService] whose methods throw [UnimplementedError].
class UnconfiguredAiService implements AiService {
  /// Creates an [UnconfiguredAiService].
  const UnconfiguredAiService();

  static Never _unconfigured() => throw UnimplementedError(
        'AI is not configured. Provide GEMINI_API_KEY via '
        '--dart-define-from-file=env.json to enable AI features.',
      );

  @override
  Future<String> generateRecipe(String prompt) async => _unconfigured();

  @override
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async =>
      _unconfigured();

  @override
  Future<String> generateTitle(String message, String reply) async =>
      _unconfigured();
}
