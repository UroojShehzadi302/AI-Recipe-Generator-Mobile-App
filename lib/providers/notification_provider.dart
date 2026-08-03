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
import '../services/notification_store.dart';

/// Exposes received push notifications and their unread state to the UI.
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  NotificationProvider(NotificationService service) : _service = service;

  /// How long a notification the user has already read is kept before it is
  /// dropped automatically. Unread notifications are never auto-dropped —
  /// silently discarding something the user has not seen would be worse than a
  /// long list. (The hard ceiling still applies: [NotificationStore.maxStored].)
  static const Duration readRetention = Duration(days: 7);

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

    // Restore the inbox from disk BEFORE subscribing, so notifications from
    // previous sessions (including ones the background isolate stored while the
    // app was closed) are present and counted in the badge.
    _items.addAll(await NotificationStore.load());

    // Housekeeping on launch: drop read notifications past their retention so
    // the inbox does not grow forever.
    final int dropped = _pruneExpired();
    if (dropped > 0) unawaited(NotificationStore.save(_items));

    if (_items.isNotEmpty) notifyListeners();

    try {
      final NotificationSettings settings = await _service.requestPermission();
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    } catch (e) {
      // Permission denial / platform quirks must never crash the app, but the
      // reason is logged — a silent failure here is indistinguishable from
      // success and makes on-device debugging impossible.
      debugPrint('FCM permission request failed: $e');
    }

    try {
      _token = await _service.getToken();
      if (_token != null) {
        // Debug builds only. The FCM token identifies this device and lets
        // anyone holding it push notifications to it, so it must never reach a
        // release log where other apps could read it via logcat.
        if (kDebugMode) debugPrint('FCM token: $_token');
      } else {
        debugPrint(
          'FCM token is NULL — device likely has no Google Play Services '
          '(common on emulators) or could not reach FCM.',
        );
      }
    } catch (e) {
      // Token may be unavailable (no Play Services, offline) — non-fatal, but
      // log it: no token means no notification can ever be delivered.
      debugPrint('FCM getToken failed: $e');
    }

    // Foreground messages: the OS does NOT show these automatically, so we
    // accumulate them in the inbox (and the badge) ourselves.
    _onMessageSub = _service.onMessage.listen(
      (RemoteMessage message) => _add(NotificationService.toAppNotification(message)),
      onError: (_) {},
    );

    // A tap that brought the app from background → foreground. Kept UNREAD:
    // tapping the system tray is not the same as reading it in the app, and
    // marking it read here would leave the bell with no badge — the user would
    // have no in-app signal that anything arrived.
    _onOpenedSub = _service.onMessageOpenedApp.listen(
      (RemoteMessage message) => _add(NotificationService.toAppNotification(message)),
      onError: (_) {},
    );

    // A tap that cold-launched the app from a terminated state. Unread for the
    // same reason as above.
    try {
      final RemoteMessage? initial = await _service.getInitialMessage();
      if (initial != null) {
        _add(NotificationService.toAppNotification(initial));
      }
    } catch (_) {
      // Ignore — best effort.
    }
  }

  /// Re-reads the persisted inbox and merges in anything not already held.
  ///
  /// Called when the app returns to the foreground: while it was backgrounded,
  /// the FCM background isolate may have appended notifications to the store
  /// that this (separate) isolate's in-memory list knows nothing about.
  Future<void> refresh() async {
    final List<AppNotification> stored = await NotificationStore.load();
    if (stored.isEmpty) return;

    final Set<String> known =
        _items.map((AppNotification n) => n.dedupeKey).toSet();

    // Only entries this isolate has never seen. Keying on [dedupeKey] (not the
    // raw id) matters: an id-less notification would otherwise be treated as
    // new on every single resume and pile up duplicate copies.
    final List<AppNotification> fresh = stored
        .where((AppNotification n) => !known.contains(n.dedupeKey))
        .toList();
    if (fresh.isEmpty) return;

    _items.insertAll(0, fresh);
    _sortNewestFirst();
    notifyListeners();
    unawaited(NotificationStore.save(_items));
  }

  /// Adds a notification to the top of the inbox, de-duplicating by id.
  void _add(AppNotification notification) {
    // Message content is user-facing data — debug builds only.
    if (kDebugMode) {
      debugPrint(
        'FCM message received (foreground/open): '
        'title="${notification.title}" body="${notification.body}" '
        'id="${notification.id}"',
      );
    }
    final String key = notification.dedupeKey;
    if (_items.any((AppNotification n) => n.dedupeKey == key)) return;

    _items.insert(0, notification);
    notifyListeners();
    unawaited(NotificationStore.save(_items));
  }

  /// Marks the single notification identified by [key] as read.
  ///
  /// [key] is an [AppNotification.dedupeKey] — not the raw id, which may be
  /// empty. Used when the user taps one row in the inbox: only that row clears,
  /// the rest stay unread and keep contributing to the badge.
  void markRead(String key) {
    if (key.isEmpty) return;
    final int index =
        _items.indexWhere((AppNotification n) => n.dedupeKey == key);
    if (index < 0 || _items[index].read) return;

    _items[index] = _items[index].copyWith(read: true);
    notifyListeners();
    unawaited(NotificationStore.save(_items));
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
    if (!changed) return;
    notifyListeners();
    unawaited(NotificationStore.save(_items));
  }

  /// Removes the single notification identified by [key] (its
  /// [AppNotification.dedupeKey]) — backs swipe-to-delete in the inbox.
  void remove(String key) {
    if (key.isEmpty) return;
    final int before = _items.length;
    _items.removeWhere((AppNotification n) => n.dedupeKey == key);
    if (_items.length == before) return;

    notifyListeners();
    unawaited(NotificationStore.save(_items));
  }

  /// Drops read notifications older than [readRetention]. Returns how many were
  /// removed. Does not notify — callers decide when to persist and rebuild.
  int _pruneExpired() {
    final DateTime cutoff = DateTime.now().subtract(readRetention);
    final int before = _items.length;
    _items.removeWhere(
      (AppNotification n) => n.read && n.receivedAt.isBefore(cutoff),
    );
    return before - _items.length;
  }

  /// Removes all notifications from the inbox, on screen and on disk.
  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    unawaited(NotificationStore.clear());
  }

  /// Keeps the list newest-first after a merge.
  void _sortNewestFirst() {
    _items.sort(
      (AppNotification a, AppNotification b) =>
          b.receivedAt.compareTo(a.receivedAt),
    );
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    super.dispose();
  }
}
