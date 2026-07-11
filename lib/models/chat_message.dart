// Chat message model for the AI Recipe Generator's AI Hub (Chat mode).
//
// Mirrors `/users/{uid}/chats/{chatId}/messages/{messageId}` from the
// Backend Architecture doc §6.1. The `role` enum values serialize to the
// exact strings the backend / security rules expect: `'user'` | `'model'`
// (§6.5). Plain, null-safe Dart — no Firebase dependency. Firestore
// `Timestamp` <-> `DateTime` conversion happens in the repository layer;
// here [createdAt] is a nullable [DateTime] parsed tolerantly from an ISO
// 8601 string (or left null).

/// Who authored a chat message. Serializes to `'user'` / `'model'`.
enum ChatRole { user, model }

/// Maps a role string from the backend to a [ChatRole]; unknown -> user.
ChatRole _roleFromString(Object? value) {
  if (value is String && value.trim().toLowerCase() == 'model') {
    return ChatRole.model;
  }
  return ChatRole.user;
}

/// Serializes a [ChatRole] to its backend string.
String _roleToString(ChatRole role) =>
    role == ChatRole.model ? 'model' : 'user';

/// Parses a [DateTime] from an ISO 8601 string; null / invalid -> null.
DateTime? _parseDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// A single chat message. Immutable (final fields, const constructor).
///
/// Model messages may contain markdown (§6.1). [createdAt] is nullable
/// because a locally-constructed message may not yet have a server timestamp.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    this.id = '',
    this.role = ChatRole.user,
    this.text = '',
    this.createdAt,
  });

  /// Convenience factory for a message authored by the user.
  factory ChatMessage.user(String text, {String id = '', DateTime? createdAt}) {
    return ChatMessage(
      id: id,
      role: ChatRole.user,
      text: text,
      createdAt: createdAt,
    );
  }

  /// Convenience factory for a message authored by the model / bot.
  factory ChatMessage.bot(String text, {String id = '', DateTime? createdAt}) {
    return ChatMessage(
      id: id,
      role: ChatRole.model,
      text: text,
      createdAt: createdAt,
    );
  }

  /// Tolerant parser: never throws on missing / wrong-typed fields.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is String
          ? json['id'] as String
          : (json['messageId'] is String ? json['messageId'] as String : ''),
      role: _roleFromString(json['role']),
      text: json['text'] is String ? json['text'] as String : '',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': _roleToString(role),
        'text': text,
        'createdAt': createdAt?.toIso8601String(),
      };

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? text,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'ChatMessage(id: $id, role: ${_roleToString(role)}, text: $text)';
}
