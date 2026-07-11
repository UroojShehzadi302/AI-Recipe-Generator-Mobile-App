/// Service boundary for the AI Recipe Generator's generative-AI calls.
///
/// This class is the single seam between the app and the backend AI. In the
/// final architecture the model is **never** called directly from the client;
/// instead the client invokes Firebase **Cloud Functions** that wrap the
/// Gemini model server-side (keeping API keys and prompt logic off-device and
/// enforcing per-user quotas / safety settings).
///
/// ## M9 wiring (future)
/// When `cloud_functions` is added to the project, [sendChatMessage] will call
/// the callable `chat` function, roughly:
///
/// ```dart
/// import 'package:cloud_functions/cloud_functions.dart';
///
/// final callable = FirebaseFunctions.instance.httpsCallable('chat');
/// final result = await callable.call(<String, dynamic>{
///   'message': message,
///   'history': history, // [{'role': 'user'|'model', 'text': '...'}]
/// });
/// return (result.data as Map)['reply'] as String;
/// ```
///
/// A sibling `generateRecipe` callable will be wrapped by an analogous method
/// in the same milestone.
///
/// For now `cloud_functions` is **not** installed, so the network call is a
/// stub that throws [UnimplementedError]. The class is deliberately kept
/// instantiable (no static-only API) so the repository can hold a reference to
/// it and swap in a real/mocked implementation later.
class GeminiService {
  /// Creates a [GeminiService].
  ///
  /// Takes no dependencies today; in M9 it will optionally accept a
  /// `FirebaseFunctions` instance (defaulting to `FirebaseFunctions.instance`)
  /// to make the callable target injectable for tests.
  const GeminiService();

  /// Sends a chat [message] (with optional prior [history]) to the AI and
  /// returns the model's reply text.
  ///
  /// [history] is the prior turns of the conversation in the wire format the
  /// `chat` Cloud Function expects: a list of `{'role': 'user'|'model',
  /// 'text': '...'}` maps, oldest first, excluding the current [message].
  ///
  /// In M9 this wraps `FirebaseFunctions.instance.httpsCallable('chat')`.
  ///
  /// Until then it throws [UnimplementedError] because the `cloud_functions`
  /// dependency is not yet installed.
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async {
    throw UnimplementedError(
      'AI chat is wired in M9 via the chat Cloud Function',
    );
  }
}
