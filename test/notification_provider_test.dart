// Unit tests for NotificationProvider — verifies it accumulates mapped
// notifications, tracks the unread count, and supports markAllRead/clear,
// all WITHOUT Firebase being initialized. A fake NotificationService drives
// controlled streams so no FirebaseMessaging call is ever made.

import 'dart:async';

import 'package:ai_recipe_generator/models/app_notification.dart';
import 'package:ai_recipe_generator/providers/notification_provider.dart';
import 'package:ai_recipe_generator/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

/// A NotificationService that never touches Firebase. Foreground messages are
/// pushed through [messageController]; permission/token/initial are stubbed.
class _FakeNotificationService extends NotificationService {
  final StreamController<RemoteMessage> messageController =
      StreamController<RemoteMessage>.broadcast();

  @override
  Future<NotificationSettings> requestPermission() async {
    // The provider swallows any error here; throwing avoids constructing a
    // fully-specified NotificationSettings just to satisfy the return type.
    throw UnimplementedError('permission not needed in tests');
  }

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Stream<RemoteMessage> get onMessage => messageController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      const Stream<RemoteMessage>.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

RemoteMessage _msg(String id, String title, String body) => RemoteMessage(
      messageId: id,
      notification: RemoteNotification(title: title, body: body),
    );

void main() {
  group('NotificationProvider', () {
    test('maps a RemoteMessage into an AppNotification', () {
      final RemoteMessage message = _msg('m1', 'Hello', 'World');
      final AppNotification n = NotificationService.toAppNotification(message);
      expect(n.id, 'm1');
      expect(n.title, 'Hello');
      expect(n.body, 'World');
      expect(n.read, isFalse);
    });

    test('accumulates foreground messages and counts unread', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();
      expect(provider.token, 'fake-token');
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.hasUnread, isFalse);

      service.messageController.add(_msg('m1', 'A', 'body a'));
      service.messageController.add(_msg('m2', 'B', 'body b'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.items.length, 2);
      // Newest first.
      expect(provider.items.first.title, 'B');
      expect(provider.unreadCount, 2);
      expect(provider.hasUnread, isTrue);

      await service.messageController.close();
    });

    test('de-duplicates by message id', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();

      service.messageController.add(_msg('dup', 'A', 'a'));
      service.messageController.add(_msg('dup', 'A', 'a'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.items.length, 1);
      await service.messageController.close();
    });

    test('markAllRead clears the unread count', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();

      service.messageController.add(_msg('m1', 'A', 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.unreadCount, 1);

      provider.markAllRead();
      expect(provider.unreadCount, 0);
      expect(provider.hasUnread, isFalse);
      expect(provider.items.length, 1); // still present, just read

      await service.messageController.close();
    });

    test('clear removes all notifications', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();

      service.messageController.add(_msg('m1', 'A', 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.items, isNotEmpty);

      provider.clear();
      expect(provider.items, isEmpty);

      await service.messageController.close();
    });
  });
}
