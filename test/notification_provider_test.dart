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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_recipe_generator/services/notification_store.dart';

/// A NotificationService that never touches Firebase. Foreground messages are
/// pushed through [messageController]; permission/token/initial are stubbed.
class _FakeNotificationService extends NotificationService {
  final StreamController<RemoteMessage> messageController =
      StreamController<RemoteMessage>.broadcast();

  /// Drives [onMessageOpenedApp] — a tray notification the user tapped.
  final StreamController<RemoteMessage> openedController =
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
  Stream<RemoteMessage> get onMessageOpenedApp => openedController.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

RemoteMessage _msg(String id, String title, String body) => RemoteMessage(
      messageId: id,
      notification: RemoteNotification(title: title, body: body),
    );

void main() {
  // The provider persists through NotificationStore -> SharedPreferences, so
  // every test needs the in-memory prefs backend registered.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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

    test('a tapped tray notification stays unread so the bell badges', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();

      // The user tapped a notification in the Android tray, which opened the
      // app. That is delivery, not "read" — the badge must still appear.
      service.openedController.add(_msg('m1', 'Tapped', 'from the tray'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.items.length, 1);
      expect(provider.items.first.read, isFalse);
      expect(provider.unreadCount, 1);
      expect(provider.hasUnread, isTrue);

      await service.openedController.close();
      await service.messageController.close();
    });

    test('markRead clears only the tapped notification', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();
      service.messageController.add(_msg('m1', 'A', 'body a'));
      service.messageController.add(_msg('m2', 'B', 'body b'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.unreadCount, 2);

      provider.markRead('m1');

      expect(provider.unreadCount, 1);
      final AppNotification a =
          provider.items.firstWhere((AppNotification n) => n.id == 'm1');
      final AppNotification b =
          provider.items.firstWhere((AppNotification n) => n.id == 'm2');
      expect(a.read, isTrue);
      expect(b.read, isFalse, reason: 'the untapped one must stay unread');

      await service.messageController.close();
    });

    test('persists the inbox and restores it on the next launch', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();
      service.messageController.add(_msg('m1', 'Saved', 'survives restart'));
      await Future<void>.delayed(Duration.zero);
      provider.markRead('m1');
      // Let the fire-and-forget writes settle before reading back.
      await Future<void>.delayed(Duration.zero);

      // A brand-new provider stands in for a fresh app launch.
      final service2 = _FakeNotificationService();
      final provider2 = NotificationProvider(service2);
      await provider2.init();

      expect(provider2.items.length, 1);
      expect(provider2.items.first.id, 'm1');
      expect(provider2.items.first.title, 'Saved');
      expect(provider2.items.first.read, isTrue, reason: 'read state persists');

      await service.messageController.close();
      await service2.messageController.close();
    });

    test('clear wipes the stored inbox too', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();
      service.messageController.add(_msg('m1', 'A', 'body a'));
      await Future<void>.delayed(Duration.zero);
      provider.clear();
      await Future<void>.delayed(Duration.zero);

      expect(await NotificationStore.load(), isEmpty);

      await service.messageController.close();
    });

    test('refresh merges notifications the background isolate stored',
        () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();
      expect(provider.items, isEmpty);

      // Simulates the FCM background isolate writing while the app was closed.
      await NotificationStore.append(
        AppNotification(
          id: 'bg1',
          title: 'From background',
          body: 'arrived while closed',
          receivedAt: DateTime(2026, 7, 29, 12),
        ),
      );

      await provider.refresh();

      expect(provider.items.length, 1);
      expect(provider.items.first.id, 'bg1');
      expect(provider.unreadCount, 1);

      await service.messageController.close();
    });

    test('repeated refresh never duplicates an id-less notification', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();

      // FCM does not guarantee a messageId. Such an entry used to be treated as
      // "new" on every resume, so the inbox grew a copy each time the app came
      // back to the foreground and read ones reappeared unread.
      await NotificationStore.append(
        AppNotification(
          id: '',
          title: 'No id',
          body: 'stored by the background isolate',
          receivedAt: DateTime(2026, 7, 29, 12),
        ),
      );

      await provider.refresh();
      expect(provider.items.length, 1);

      // Three more resumes.
      await provider.refresh();
      await provider.refresh();
      await provider.refresh();

      expect(provider.items.length, 1, reason: 'resume must not duplicate');
      expect(provider.unreadCount, 1);

      // And reading it must survive further resumes.
      provider.markRead(provider.items.first.dedupeKey);
      await Future<void>.delayed(Duration.zero);
      await provider.refresh();

      expect(provider.items.length, 1);
      expect(provider.unreadCount, 0, reason: 'a read one must not come back');

      await service.messageController.close();
    });

    test('drops read notifications past retention, keeps unread ones',
        () async {
      final DateTime old =
          DateTime.now().subtract(NotificationProvider.readRetention * 2);

      await NotificationStore.save(<AppNotification>[
        AppNotification(
          id: 'old-read',
          title: 'Old and read',
          body: 'should be pruned',
          receivedAt: old,
          read: true,
        ),
        AppNotification(
          id: 'old-unread',
          title: 'Old but unread',
          body: 'must survive — the user never saw it',
          receivedAt: old,
        ),
        AppNotification(
          id: 'recent-read',
          title: 'Recent and read',
          body: 'still within retention',
          receivedAt: DateTime.now(),
          read: true,
        ),
      ]);

      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);
      await provider.init();

      final List<String> ids =
          provider.items.map((AppNotification n) => n.id).toList();
      expect(ids, isNot(contains('old-read')));
      expect(ids, contains('old-unread'));
      expect(ids, contains('recent-read'));

      await service.messageController.close();
    });

    test('remove deletes a single notification and persists it', () async {
      final service = _FakeNotificationService();
      final provider = NotificationProvider(service);

      await provider.init();
      service.messageController.add(_msg('m1', 'A', 'body a'));
      service.messageController.add(_msg('m2', 'B', 'body b'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.items.length, 2);

      provider.remove('m1');
      await Future<void>.delayed(Duration.zero);

      expect(provider.items.length, 1);
      expect(provider.items.single.id, 'm2');

      final List<AppNotification> stored = await NotificationStore.load();
      expect(stored.length, 1);
      expect(stored.single.id, 'm2');

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
