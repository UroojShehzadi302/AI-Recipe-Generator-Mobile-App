// The seam through which an [AiService] reports what a call cost.
//
// Why a sink instead of changing [AiService]'s return types: every method on
// that interface returns the model's raw text, and repositories/providers are
// built around that. Threading a `(text, usage)` pair through all of them would
// churn four layers to carry a number the UI reads separately anyway.
//
// So token reporting travels on its own channel. [GeminiDirectService] takes an
// optional [UsageSink] and calls [record] after each successful response; the
// DI graph wires that sink to the repository that persists it. Nothing in the
// chat/recipe call paths changes shape, and a future Cloud Functions-backed
// service can either report through the same sink or leave it null (the server
// would own accounting at that point).
//
// Implementations MUST be non-throwing and non-blocking: usage accounting is
// bookkeeping, and a failure to record it must never turn a successful AI reply
// into an error the user sees.

import '../models/usage_entry.dart';

/// Receives token-usage reports from an [AiService] implementation.
abstract interface class UsageSink {
  /// Records that a [kind] call consumed [promptTokens] input and
  /// [outputTokens] output tokens on [model].
  ///
  /// Called only after a successful response. Implementations must swallow
  /// their own errors — the caller does not await this and will not handle a
  /// rejection.
  void record({
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  });
}

/// A [UsageSink] that drops every report.
///
/// Used when no user is signed in (there is nowhere to attribute the usage) and
/// as the default in tests, so a service under test needs no sink wiring.
class NullUsageSink implements UsageSink {
  /// Creates a [NullUsageSink].
  const NullUsageSink();

  @override
  void record({
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  }) {
    // Intentionally empty.
  }
}
