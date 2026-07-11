import 'package:flutter/foundation.dart';

import '../core/error/failure.dart';
import '../models/chat_message.dart';
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

  /// The conversation so far, oldest first. Unmodifiable to callers.
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);

  /// Whether a send is currently in flight (awaiting the AI reply).
  bool get isSending => _isSending;

  /// The last user-facing error message, or null if there is none.
  String? get errorMessage => _errorMessage;

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
  Future<void> sendMessage(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _messages.add(ChatMessage.user(trimmed));
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Pass the prior conversation (everything before the just-added message)
      // as context for the model.
      final List<ChatMessage> history =
          _messages.sublist(0, _messages.length - 1);
      final String reply = await _repository.send(trimmed, history: history);
      _messages.add(ChatMessage.bot(reply));
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
    _errorMessage = null;
    _isSending = false;
    notifyListeners();
  }
}
