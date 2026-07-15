// Presentation-layer state holder for PUSH NOTIFICATIONS (FCM).
//
// A [ChangeNotifier] the UI (the Home bell + inbox) listens to. It drives
// [NotificationService], accumulates received messages as [AppNotification]s,
// tracks an unread count, and never throws to the UI — all Firebase calls are
// best-effort and swallowed.
//
// IMPORTANT: construction must NOT touch Firebase, so the provider stays
// constructible in unit tests without Firebase initialized. All Firebase access
// is deferred to [init], which the widget tree calls after the first frame.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Exposes received push notifications and their unread state to the UI.
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  NotificationProvider(NotificationService service) : _service = service;

  final List<AppNotification> _items = <AppNotification>[];
  bool _initialized = false;
  String? _token;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Received notifications, newest first. Unmodifiable to callers.
  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);

  /// Number of notifications the user has not yet seen in the inbox.
  int get unreadCount => _items.where((AppNotification n) => !n.read).length;

  /// Whether there are any unread notifications (drives the bell badge).
  bool get hasUnread => unreadCount > 0;

  /// The FCM registration token for this device, once resolved. The owner can
  /// paste this into the Firebase console to target this device directly.
  String? get token => _token;

  /// One-time initialization: requests permission, resolves the FCM token, and
  /// subscribes to the foreground + tap-to-open message streams. Safe to call
  /// more than once (subsequent calls are no-ops). Never throws.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _service.requestPermission();
    } catch (_) {
      // Permission denial / platform quirks must never crash the app.
    }

    try {
      _token = await _service.getToken();
      if (_token != null) {
        debugPrint('FCM token: $_token');
      }
    } catch (_) {
      // Token may be unavailable (no Play Services, offline) — ignore.
    }

    // Foreground messages: the OS does NOT show these automatically, so we
    // accumulate them in the inbox (and the badge) ourselves.
    _onMessageSub = _service.onMessage.listen(
      (RemoteMessage message) => _add(NotificationService.toAppNotification(message)),
      onError: (_) {},
    );

    // A tap that brought the app from background → foreground. Record it as
    // read (the user just engaged with it).
    _onOpenedSub = _service.onMessageOpenedApp.listen(
      (RemoteMessage message) => _add(
        NotificationService.toAppNotification(message).copyWith(read: true),
      ),
      onError: (_) {},
    );

    // A tap that cold-launched the app from a terminated state.
    try {
      final RemoteMessage? initial = await _service.getInitialMessage();
      if (initial != null) {
        _add(
          NotificationService.toAppNotification(initial).copyWith(read: true),
        );
      }
    } catch (_) {
      // Ignore — best effort.
    }
  }

  /// Adds a notification to the top of the inbox, de-duplicating by id.
  void _add(AppNotification notification) {
    if (notification.id.isNotEmpty &&
        _items.any((AppNotification n) => n.id == notification.id)) {
      return;
    }
    _items.insert(0, notification);
    notifyListeners();
  }

  /// Marks every notification as read (clears the badge).
  void markAllRead() {
    bool changed = false;
    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Removes all notifications from the inbox.
  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    super.dispose();
  }
}
