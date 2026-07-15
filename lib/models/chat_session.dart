// Metadata for one saved conversation in the AI chat history.
//
// Mirrors a `users/{uid}/chats/{chatId}` document. Messages live in the
// `messages` subcollection (see [ChatMessage]); this model is just the
// lightweight summary shown in the history list.

/// A saved chat conversation summary.
class ChatSession {
  final String id;

  /// Short title derived from the first user message.
  final String title;

  /// Preview of the most recent message.
  final String lastMessage;

  /// Last-updated time (server timestamp, normalized to [DateTime]).
  final DateTime? updatedAt;

  const ChatSession({
    this.id = '',
    this.title = '',
    this.lastMessage = '',
    this.updatedAt,
  });

  /// Tolerant parser: never throws on missing / wrong-typed fields.
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final Object? rawDate = json['updatedAt'];
    final DateTime? updatedAt = rawDate is DateTime
        ? rawDate
        : (rawDate is String ? DateTime.tryParse(rawDate) : null);

    return ChatSession(
      id: json['id'] is String ? json['id'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      lastMessage:
          json['lastMessage'] is String ? json['lastMessage'] as String : '',
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'lastMessage': lastMessage,
      };
}
