// The single seam between the app and generative AI.
//
// Repositories depend on THIS interface, never on a concrete implementation.
// That is what lets us run the free Gemini Developer API directly from the app
// during development and later swap to a Cloud Functions proxy by changing only
// the wiring in `app/app.dart` — repositories, providers, and UI are untouched.
//
// Implementations:
// * [GeminiDirectService]      — dev: calls the Gemini Developer API directly.
// * [UnconfiguredAiService]    — no API key set: throws so features degrade to
//                                a friendly "coming soon".
// * (future) a Cloud Functions-backed service for production (backend doc D7).
//
// Contract notes:
// * Methods return the model's RAW text output. Domain mapping (e.g. parsing a
//   recipe JSON string into a `Recipe`) is the repository's job, so the return
//   types stay stable across every implementation.
// * Implementations should throw a domain `Failure` (see `core/error`) on a
//   handled error, or let an [UnimplementedError] signal "not wired yet"; the
//   repository layer maps these to user-safe messages.

/// Transport-level contract for generative-AI calls (chat + recipe generation).
abstract interface class AiService {
  /// Generates a recipe from a free-text [prompt] and returns the model's raw
  /// response text (expected to be JSON the repository parses into a `Recipe`).
  ///
  /// The prompt/system instructions and JSON-schema shaping live inside the
  /// implementation, so a future server-side version can own them instead
  /// without changing this signature.
  Future<String> generateRecipe(String prompt);

  /// Sends a chat [message] (with optional prior [history]) and returns the
  /// model's reply text.
  ///
  /// [history] is the prior turns, oldest first, excluding [message], in the
  /// wire format `{'role': 'user'|'model', 'text': '...'}`.
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  });

  /// Produces a short (2–5 word) title summarizing a conversation from its
  /// first [message] and the assistant's [reply]. Used to label saved chats in
  /// the history list.
  Future<String> generateTitle(String message, String reply);
}
