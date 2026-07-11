import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';

/// Data-layer boundary for the AI chat feature.
///
/// Sits between [ChatProvider] (UI state) and the outside world:
/// * delegates the actual model call to [GeminiService], and
/// * persists / reads chat history from Cloud Firestore under
///   `users/{uid}/chats/{chatId}/messages`.
///
/// Errors are translated into domain [Failure] values so the UI never sees raw
/// exceptions. History persistence is intentionally decoupled from the send
/// flow: a failure to save a message must not break the conversation, so
/// callers should treat [saveMessage] / [getMessages] as best-effort.
class ChatRepository {
  /// The AI service used to produce chat replies.
  final GeminiService _gemini;

  /// Firestore instance used for history persistence.
  final FirebaseFirestore _firestore;

  /// Creates a [ChatRepository].
  ///
  /// [gemini] is required. [firestore] defaults to
  /// [FirebaseFirestore.instance] but can be injected for testing.
  ChatRepository({
    required GeminiService gemini,
    FirebaseFirestore? firestore,
  })  : _gemini = gemini,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Sends [message] to the AI and returns the reply text.
  ///
  /// [history] is the prior conversation (oldest first); it is converted into
  /// the `{'role', 'text'}` map format the [GeminiService] expects.
  ///
  /// All failures are surfaced as [Failure] values:
  /// * the current [UnimplementedError] stub becomes a friendly
  ///   [AiFailure] ('AI chat coming soon');
  /// * anything else becomes an [AiFailure] / [UnknownFailure] via
  ///   [ErrorMapper].
  Future<String> send(
    String message, {
    List<ChatMessage> history = const <ChatMessage>[],
  }) async {
    final List<Map<String, String>> wireHistory = history
        .map((ChatMessage m) => <String, String>{
              'role': m.role == ChatRole.model ? 'model' : 'user',
              'text': m.text,
            })
        .toList();

    try {
      return await _gemini.sendChatMessage(message, history: wireHistory);
    } on UnimplementedError {
      // The AI backend is not wired yet (M9). Present a friendly message
      // instead of leaking the raw error to the UI.
      throw const AiFailure('AI chat coming soon');
    } on Failure {
      // Already a domain failure — let it propagate unchanged.
      rethrow;
    } catch (e) {
      // Try to extract a `code` (e.g. from a callable exception) for a more
      // specific message; otherwise fall back to a generic one.
      final String? code = _extractCode(e);
      if (code != null) {
        throw AiFailure(ErrorMapper.aiMessage(code));
      }
      throw UnknownFailure(ErrorMapper.generic(e));
    }
  }

  /// Attempts to read a `code` property off an arbitrary error object without
  /// depending on any Firebase types. Returns null if none is present.
  String? _extractCode(Object error) {
    try {
      final dynamic dyn = error;
      final dynamic code = dyn.code;
      if (code is String && code.trim().isNotEmpty) return code;
    } catch (_) {
      // No `code` getter — ignore.
    }
    return null;
  }

  // --- History persistence (best-effort; never blocks the send flow) -------

  /// Firestore collection reference for a given chat's messages.
  CollectionReference<Map<String, dynamic>> _messagesRef(
    String uid,
    String chatId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages');
  }

  /// Persists a single [msg] to `users/{uid}/chats/{chatId}/messages`.
  ///
  /// Uses the message id as the document id when present; otherwise lets
  /// Firestore auto-generate one. A server timestamp is written for ordering
  /// when the message has no [ChatMessage.createdAt].
  Future<void> saveMessage(String uid, String chatId, ChatMessage msg) async {
    final Map<String, dynamic> data = msg.toJson();
    // Prefer a real server timestamp for reliable ordering across clients.
    if (msg.createdAt == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    final CollectionReference<Map<String, dynamic>> ref =
        _messagesRef(uid, chatId);
    if (msg.id.isNotEmpty) {
      await ref.doc(msg.id).set(data);
    } else {
      await ref.add(data);
    }
  }

  /// Reads all messages for a chat, oldest first.
  ///
  /// Mapping is tolerant: each document is parsed via
  /// [ChatMessage.fromJson], and Firestore [Timestamp]s are normalized to
  /// [DateTime] before parsing so ordering and display work correctly.
  Future<List<ChatMessage>> getMessages(String uid, String chatId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _messagesRef(uid, chatId).orderBy('createdAt').get();

    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      // Ensure an id is present even if the stored document omitted it.
      data['id'] = (data['id'] is String && (data['id'] as String).isNotEmpty)
          ? data['id']
          : doc.id;
      // Normalize Firestore Timestamp -> DateTime for the tolerant parser.
      final Object? createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate();
      }
      return ChatMessage.fromJson(data);
    }).toList();
  }
}
