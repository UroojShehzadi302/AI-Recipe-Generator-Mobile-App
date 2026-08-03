import 'package:flutter/foundation.dart';

import '../core/error/failure.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../repositories/chat_repository.dart';

/// [ChangeNotifier] that drives the AI Chat screen.
///
/// Owns the visible conversation ([messages]), the in-flight state
/// ([isSending]) and the last user-facing error ([errorMessage]). It delegates
/// all I/O to a [ChatRepository] and never throws from [sendMessage]: repository
/// failures (including the current "coming soon" stub) are converted into a
/// friendly [errorMessage] so the UI stays stable.
class ChatProvider extends ChangeNotifier {
  /// The repository used to send messages and (optionally) persist history.
  final ChatRepository _repository;

  /// Creates a [ChatProvider] backed by [repository].
  ChatProvider(ChatRepository repository) : _repository = repository;

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _isSending = false;
  String? _errorMessage;

  /// Firestore id of the conversation being viewed. Null for a fresh, not-yet-
  /// persisted chat (created lazily on the first successful send).
  String? _chatId;

  /// The user's saved conversations, most recent first.
  List<ChatSession> _sessions = const <ChatSession>[];

  /// The conversation so far, oldest first. Unmodifiable to callers.
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);

  /// Whether a send is currently in flight (awaiting the AI reply).
  bool get isSending => _isSending;

  /// The last user-facing error message, or null if there is none.
  String? get errorMessage => _errorMessage;

  /// The user's saved chat sessions (for the history list).
  List<ChatSession> get sessions => List<ChatSession>.unmodifiable(_sessions);

  /// Whether the current conversation has any messages.
  bool get hasMessages => _messages.isNotEmpty;

  /// Sends [text] as a user message and appends the AI reply on success.
  ///
  /// Flow:
  /// 1. Ignore empty/whitespace-only input.
  /// 2. Append the user's message, mark [isSending], clear any prior error.
  /// 3. Await [ChatRepository.send]; on success append the bot reply.
  /// 4. On a domain [Failure] set [errorMessage] and append a bot error bubble
  ///    so the failure is visible inline.
  /// 5. Always clear [isSending] and notify listeners.
  ///
  /// Never rethrows — including the current [UnimplementedError]/[AiFailure]
  /// stub path, which surfaces as a friendly message instead.
  Future<void> sendMessage(String text, {String? uid}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final ChatMessage userMessage = ChatMessage.user(trimmed);
    _messages.add(userMessage);
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    ChatMessage? botMessage;
    try {
      // Pass the prior conversation (everything before the just-added message)
      // as context for the model.
      final List<ChatMessage> history =
          _messages.sublist(0, _messages.length - 1);
      final String reply = await _repository.send(trimmed, history: history);
      botMessage = ChatMessage.bot(reply);
      _messages.add(botMessage);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _messages.add(ChatMessage.bot(failure.message));
    } catch (e) {
      // Defensive: the repository is expected to only throw Failures, but we
      // never want an unexpected error to crash the UI.
      _errorMessage = 'Something went wrong. Please try again.';
      _messages.add(ChatMessage.bot(_errorMessage!));
    } finally {
      _isSending = false;
      notifyListeners();
    }

    // Persist the turn for signed-in users (best-effort — a save failure must
    // never disrupt the visible conversation). Only a successful exchange is
    // saved so failed sends don't create empty history entries.
    if (uid != null && botMessage != null) {
      await _persistTurn(uid, trimmed, userMessage, botMessage);
    }
  }

  /// Saves a user+bot turn, creating the chat session on the first message.
  Future<void> _persistTurn(
    String uid,
    String prompt,
    ChatMessage userMessage,
    ChatMessage botMessage,
  ) async {
    try {
      final bool isNewChat = _chatId == null;
      _chatId ??= await _repository.createChat(uid, _titleFrom(prompt));
      final String chatId = _chatId!;
      await _repository.saveMessage(uid, chatId, userMessage);
      await _repository.saveMessage(uid, chatId, botMessage);
      await _repository.touchChat(uid, chatId, lastMessage: botMessage.text);

      // For a brand-new chat, upgrade the provisional (truncated-prompt) title
      // to an AI-generated one from the first exchange. Best-effort.
      if (isNewChat) {
        final String title =
            await _repository.generateTitle(prompt, botMessage.text);
        if (title.trim().isNotEmpty) {
          await _repository.touchChat(uid, chatId, title: title.trim());
        }
      }

      await loadSessions(uid);
    } catch (_) {
      // Persistence is best-effort; the in-memory conversation is unaffected.
    }
  }

  /// Loads the user's saved chat sessions for the history list.
  Future<void> loadSessions(String uid) async {
    try {
      _sessions = await _repository.getChats(uid);
    } catch (_) {
      _sessions = const <ChatSession>[];
    }
    notifyListeners();
  }

  /// Starts a fresh conversation (clears the view; the session is created
  /// lazily on the next successful send).
  void newChat() {
    _messages.clear();
    _chatId = null;
    _errorMessage = null;
    _isSending = false;
    notifyListeners();
  }

  /// Opens a saved conversation, loading its messages into the view.
  Future<void> openChat(String uid, String chatId) async {
    try {
      final List<ChatMessage> loaded =
          await _repository.getMessages(uid, chatId);
      _messages
        ..clear()
        ..addAll(loaded);
      _chatId = chatId;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Could not open this conversation.';
    }
    notifyListeners();
  }

  /// Deletes a saved conversation. If it is the one being viewed, resets to a
  /// fresh chat.
  Future<void> deleteSession(String uid, String chatId) async {
    try {
      await _repository.deleteChat(uid, chatId);
    } catch (_) {
      // Ignore — the list is refreshed below regardless.
    }
    _sessions =
        _sessions.where((ChatSession s) => s.id != chatId).toList();
    if (_chatId == chatId) {
      _messages.clear();
      _chatId = null;
    }
    notifyListeners();
  }

  /// Derives a short session title from the first user message.
  String _titleFrom(String prompt) {
    final String t = prompt.trim();
    if (t.length <= 40) return t;
    return '${t.substring(0, 40).trimRight()}…';
  }

  /// Clears the current [errorMessage] (e.g. after showing a snackbar).
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Resets the provider to an empty conversation with no error.
  void reset() {
    _messages.clear();
    _chatId = null;
    _errorMessage = null;
    _isSending = false;
    notifyListeners();
  }
}
