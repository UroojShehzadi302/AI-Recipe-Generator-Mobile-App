// One recorded AI call and what it cost in Gemini tokens.
//
// A [UsageEntry] is written every time the app successfully calls Gemini —
// generating a recipe, sending a chat message, or naming a conversation. It
// records which kind of call it was, when it happened, and the token counts
// Gemini reported for that request, so the Credit Usage screen can show the
// user what they have actually consumed.
//
// Deliberately Firebase-free (plain maps in/out) so it can be unit-tested and
// so the model layer never depends on `cloud_firestore`.

/// Which AI feature produced a usage record.
enum UsageKind {
  /// A recipe generation (AI Hub → Generate).
  recipe,

  /// A chat message sent to the cooking assistant.
  chat,

  /// The background call that names a saved conversation.
  title;

  /// Parses the persisted string form, defaulting to [chat].
  static UsageKind fromName(String? raw) {
    return UsageKind.values.firstWhere(
      (UsageKind k) => k.name == raw,
      orElse: () => UsageKind.chat,
    );
  }

  /// Human-readable label for the Credit Usage list.
  String get label {
    switch (this) {
      case UsageKind.recipe:
        return 'Recipe generated';
      case UsageKind.chat:
        return 'Chat message';
      case UsageKind.title:
        return 'Chat title';
    }
  }
}

/// A single AI call's token cost, as shown in Credit Usage.
class UsageEntry {
  const UsageEntry({
    required this.id,
    required this.kind,
    required this.promptTokens,
    required this.outputTokens,
    required this.createdAt,
    this.model = '',
  });

  /// Document id. Client-generated (timestamp + kind) so a write needs no
  /// server round-trip to know where it landed.
  final String id;

  /// Which feature the call came from.
  final UsageKind kind;

  /// Input tokens Gemini billed for this call (`promptTokenCount`).
  final int promptTokens;

  /// Output tokens Gemini billed for this call (`candidatesTokenCount`).
  final int outputTokens;

  /// When the call happened.
  final DateTime createdAt;

  /// The Gemini model used, when known. Recorded because the token cost of a
  /// call is only meaningful alongside the model that produced it.
  final String model;

  /// Total tokens for this call — what the Credit Usage screen actually shows.
  int get totalTokens => promptTokens + outputTokens;

  /// Serializes for Firestore. `createdAt` is written by the repository as a
  /// server timestamp; the local value here is the fallback used offline.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'usageId': id,
        'kind': kind.name,
        'promptTokens': promptTokens,
        'outputTokens': outputTokens,
        'totalTokens': totalTokens,
        'model': model,
        'createdAtLocal': createdAt.toIso8601String(),
      };

  /// Builds an entry from a Firestore document map.
  ///
  /// Defensive on every field: a malformed or partially-written document yields
  /// a usable entry rather than throwing and breaking the whole list. Returns
  /// `null` only when there is nothing countable to show.
  static UsageEntry? fromMap(Map<String, dynamic> map) {
    final int prompt = _parseInt(map['promptTokens']);
    final int output = _parseInt(map['outputTokens']);

    // A record with no id AND no tokens carries no information worth a row.
    final Object? rawId = map['usageId'] ?? map['id'];
    final String id = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : '';
    if (id.isEmpty && prompt == 0 && output == 0) return null;

    final Object? rawModel = map['model'];

    return UsageEntry(
      id: id.isEmpty ? 'usage-${_parseDate(map['createdAt']).millisecondsSinceEpoch}' : id,
      kind: UsageKind.fromName(map['kind'] as String?),
      promptTokens: prompt,
      outputTokens: output,
      createdAt: _parseDate(map['createdAt'] ?? map['createdAtLocal']),
      model: rawModel is String ? rawModel.trim() : '',
    );
  }

  /// Reads an int that may arrive as an int, a double, or a numeric string.
  static int _parseInt(Object? raw) {
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is num) {
      final int v = raw.toInt();
      return v < 0 ? 0 : v;
    }
    if (raw is String) {
      final int v = int.tryParse(raw.trim()) ?? 0;
      return v < 0 ? 0 : v;
    }
    return 0;
  }

  /// Reads a Firestore `Timestamp`, an ISO string, or epoch millis.
  ///
  /// Accepts a `Timestamp` without importing `cloud_firestore` by duck-typing
  /// its `toDate()` — that keeps this model dependency-free while still
  /// handling the shape Firestore actually returns.
  static DateTime _parseDate(Object? raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final Object? converted = (raw as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      // Not a Timestamp — fall through to the epoch default.
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Aggregated totals over a list of [UsageEntry]s.
///
/// Computed client-side from the loaded list rather than maintained as a
/// server counter, for the same reason the Profile stat tiles are: there are no
/// Cloud Functions in the dev phase to keep a counter honest.
class UsageSummary {
  const UsageSummary({
    required this.totalTokens,
    required this.promptTokens,
    required this.outputTokens,
    required this.callCount,
    required this.byKind,
  });

  /// An empty summary — the state before anything has been generated.
  static const UsageSummary empty = UsageSummary(
    totalTokens: 0,
    promptTokens: 0,
    outputTokens: 0,
    callCount: 0,
    byKind: <UsageKind, int>{},
  );

  /// Every token consumed across all recorded calls.
  final int totalTokens;

  /// Input tokens across all recorded calls.
  final int promptTokens;

  /// Output tokens across all recorded calls.
  final int outputTokens;

  /// How many AI calls were recorded.
  final int callCount;

  /// Total tokens grouped by feature, for the breakdown rows.
  final Map<UsageKind, int> byKind;

  /// Folds [entries] into a summary.
  factory UsageSummary.from(List<UsageEntry> entries) {
    if (entries.isEmpty) return empty;

    int prompt = 0;
    int output = 0;
    final Map<UsageKind, int> byKind = <UsageKind, int>{};

    for (final UsageEntry e in entries) {
      prompt += e.promptTokens;
      output += e.outputTokens;
      byKind[e.kind] = (byKind[e.kind] ?? 0) + e.totalTokens;
    }

    return UsageSummary(
      totalTokens: prompt + output,
      promptTokens: prompt,
      outputTokens: output,
      callCount: entries.length,
      byKind: byKind,
    );
  }
}
