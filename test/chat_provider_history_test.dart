// Unit tests for ChatProvider's session/history behavior with a fake repo.

import 'package:ai_recipe_generator/models/chat_message.dart';
import 'package:ai_recipe_generator/models/chat_session.dart';
import 'package:ai_recipe_generator/providers/chat_provider.dart';
import 'package:ai_recipe_generator/repositories/chat_repository.dart';
import 'package:ai_recipe_generator/services/unconfigured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(ai: const UnconfiguredAiService());

  final List<String> savedTexts = <String>[];
  List<ChatSession> chats = const <ChatSession>[];
  int createChatCalls = 0;

  /// When non-empty, generateTitle returns this (simulates an AI title).
  String aiTitle = '';

  @override
  Future<String> send(String message,
          {List<ChatMessage> history = const <ChatMessage>[]}) async =>
      'Sure — here is a tip.';

  @override
  Future<String> generateTitle(String message, String reply) async => aiTitle;

  @override
  Future<String> createChat(String uid, String title) async {
    createChatCalls++;
    chats = <ChatSession>[ChatSession(id: 'c1', title: title)];
    return 'c1';
  }

  @override
  Future<void> saveMessage(String uid, String chatId, ChatMessage msg) async {
    savedTexts.add(msg.text);
  }

  @override
  Future<void> touchChat(String uid, String chatId,
      {String? title, String? lastMessage}) async {
    if (chats.isEmpty) return;
    final ChatSession s = chats.first;
    chats = <ChatSession>[
      ChatSession(
        id: s.id,
        title: title ?? s.title,
        lastMessage: lastMessage ?? s.lastMessage,
      ),
    ];
  }

  @override
  Future<List<ChatSession>> getChats(String uid) async => chats;

  @override
  Future<List<ChatMessage>> getMessages(String uid, String chatId) async =>
      <ChatMessage>[ChatMessage.user('old q'), ChatMessage.bot('old a')];

  @override
  Future<void> deleteChat(String uid, String chatId) async {
    chats = const <ChatSession>[];
  }
}

void main() {
  test('sending with a uid persists the turn and creates a session', () async {
    final repo = _FakeChatRepository();
    final provider = ChatProvider(repo);

    await provider.sendMessage('How do I poach an egg?', uid: 'u1');

    expect(provider.messages, hasLength(2)); // user + bot
    expect(repo.createChatCalls, 1);
    expect(repo.savedTexts, contains('How do I poach an egg?'));
    expect(repo.savedTexts, contains('Sure — here is a tip.'));
    expect(provider.sessions, isNotEmpty);
  });

  test('sending without a uid does not persist', () async {
    final repo = _FakeChatRepository();
    final provider = ChatProvider(repo);

    await provider.sendMessage('hi');

    expect(provider.messages, hasLength(2));
    expect(repo.createChatCalls, 0);
    expect(repo.savedTexts, isEmpty);
  });

  test('a new chat gets an AI-generated title from the first exchange',
      () async {
    final repo = _FakeChatRepository()..aiTitle = 'Poaching Eggs';
    final provider = ChatProvider(repo);

    await provider.sendMessage('how do i poach an egg exactly', uid: 'u1');

    expect(provider.sessions, isNotEmpty);
    expect(provider.sessions.first.title, 'Poaching Eggs');
  });

  test('newChat clears the conversation', () async {
    final repo = _FakeChatRepository();
    final provider = ChatProvider(repo);
    await provider.sendMessage('hi', uid: 'u1');
    expect(provider.messages, isNotEmpty);

    provider.newChat();

    expect(provider.messages, isEmpty);
    expect(provider.hasMessages, isFalse);
  });

  test('openChat loads a saved conversation', () async {
    final provider = ChatProvider(_FakeChatRepository());

    await provider.openChat('u1', 'c1');

    expect(provider.messages, hasLength(2));
    expect(provider.messages.first.text, 'old q');
  });

  test('deleteSession removes it from the list', () async {
    final repo = _FakeChatRepository();
    final provider = ChatProvider(repo);
    await provider.sendMessage('hi', uid: 'u1');
    expect(provider.sessions, isNotEmpty);

    await provider.deleteSession('u1', 'c1');

    expect(provider.sessions, isEmpty);
  });
}
