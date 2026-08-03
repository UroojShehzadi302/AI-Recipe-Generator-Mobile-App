import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/ai_service.dart';

/// Data-layer boundary for the AI chat feature.
///
/// Sits between [ChatProvider] (UI state) and the outside world:
/// * delegates the actual model call to an [AiService] (direct Gemini in dev,
///   a Cloud Functions proxy later — this layer doesn't care which), and
/// * persists / reads chat history from Cloud Firestore under
///   `users/{uid}/chats/{chatId}/messages`.
///
/// Errors are translated into domain [Failure] values so the UI never sees raw
/// exceptions. History persistence is intentionally decoupled from the send
/// flow: a failure to save a message must not break the conversation, so
/// callers should treat [saveMessage] / [getMessages] as best-effort.
class ChatRepository {
  /// The AI service used to produce chat replies.
  final AiService _ai;

  /// Injected Firestore instance (tests); otherwise resolved lazily.
  final FirebaseFirestore? _injectedFirestore;

  /// Firestore instance used for history persistence. Resolved lazily (getter,
  /// not constructor) so the repository — and the providers that hold it — can
  /// be constructed in unit tests without initializing Firebase.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Creates a [ChatRepository].
  ///
  /// [ai] is required. [firestore] is injectable for testing; when omitted the
  /// default `FirebaseFirestore.instance` resolves lazily on first use.
  ChatRepository({
    required AiService ai,
    FirebaseFirestore? firestore,
  })  : _ai = ai,
        _injectedFirestore = firestore;

  /// Sends [message] to the AI and returns the reply text.
  ///
  /// [history] is the prior conversation (oldest first); it is converted into
  /// the `{'role', 'text'}` map format the [AiService] expects.
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
      return await _ai.sendChatMessage(message, history: wireHistory);
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

  /// Firestore collection reference for a user's chat sessions.
  CollectionReference<Map<String, dynamic>> _chatsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chats');
  }

  /// Firestore collection reference for a given chat's messages.
  CollectionReference<Map<String, dynamic>> _messagesRef(
    String uid,
    String chatId,
  ) {
    return _chatsRef(uid).doc(chatId).collection('messages');
  }

  /// Creates a new chat session document and returns its generated id.
  Future<String> createChat(String uid, String title) async {
    final DocumentReference<Map<String, dynamic>> doc = _chatsRef(uid).doc();
    await doc.set(<String, dynamic>{
      'title': title,
      'lastMessage': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Updates a chat's [title] / [lastMessage] preview and `updatedAt` (so
  /// recent chats sort first). Only the provided fields are written.
  Future<void> touchChat(
    String uid,
    String chatId, {
    String? title,
    String? lastMessage,
  }) {
    return _chatsRef(uid).doc(chatId).set(<String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'title': ?title,
      'lastMessage': ?lastMessage,
    }, SetOptions(merge: true));
  }

  /// Generates a short title for a conversation from its first exchange.
  ///
  /// Best-effort: returns an empty string on any failure so callers can keep
  /// the provisional title rather than surfacing an error.
  Future<String> generateTitle(String message, String reply) async {
    try {
      return await _ai.generateTitle(message, reply);
    } catch (_) {
      return '';
    }
  }

  /// Lists a user's chat sessions, most recently updated first.
  Future<List<ChatSession>> getChats(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _chatsRef(uid).orderBy('updatedAt', descending: true).get();

    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      final Object? updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp) {
        data['updatedAt'] = updatedAt.toDate();
      }
      return ChatSession.fromJson(data);
    }).toList();
  }

  /// Deletes a chat session and all its messages (best-effort).
  Future<void> deleteChat(String uid, String chatId) async {
    final QuerySnapshot<Map<String, dynamic>> messages =
        await _messagesRef(uid, chatId).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in messages.docs) {
      await doc.reference.delete();
    }
    await _chatsRef(uid).doc(chatId).delete();
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
