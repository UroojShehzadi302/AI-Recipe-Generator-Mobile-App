// Thin wrapper around [FirebaseMessaging] for push notifications (FCM).
//
// Like the other SDK seams in this app, this service is a *pure pass-through*
// over `FirebaseMessaging.instance`: it requests permission, hands back the FCM
// token, and exposes the message streams. It performs no app-level state
// management and does not throw domain errors — the `NotificationProvider` one
// layer up owns state and error swallowing.
//
// The `FirebaseMessaging.instance` is resolved **lazily** (a getter, not the
// constructor) so constructing this service never requires Firebase to be
// initialized — keeping providers/services constructible in unit tests.

import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';

/// A minimal, testable facade over [FirebaseMessaging].
class NotificationService {
  final FirebaseMessaging? _injected;

  /// Creates a [NotificationService].
  ///
  /// [messaging] is injectable for testing. The default
  /// `FirebaseMessaging.instance` is resolved lazily on first use, so
  /// constructing this service never requires Firebase to be initialized.
  NotificationService({FirebaseMessaging? messaging}) : _injected = messaging;

  FirebaseMessaging get _messaging => _injected ?? FirebaseMessaging.instance;

  /// Requests notification permission from the OS.
  ///
  /// On Android 13+ this drives the `POST_NOTIFICATIONS` runtime prompt; on
  /// older Android it is a no-op that reports authorized. Returns the resulting
  /// [NotificationSettings] (the caller may inspect `authorizationStatus`).
  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission();
  }

  /// The current FCM registration token for this device, or `null` if it could
  /// not be obtained. The owner can paste this into the Firebase console to
  /// send a test notification to this specific device.
  Future<String?> getToken() => _messaging.getToken();

  /// Emits when the app receives a message while in the **foreground**.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Emits when the user taps a notification that opened the app from the
  /// **background** (but not terminated) state.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// The message that launched the app from a **terminated** state via a
  /// notification tap, or `null` if the app was not opened that way.
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  /// Maps an FCM [RemoteMessage] to the app's Firebase-free [AppNotification].
  ///
  /// Prefers the `notification` block (title/body) and falls back to matching
  /// `data` keys so data-only messages still surface something readable.
  static AppNotification toAppNotification(RemoteMessage message) {
    final RemoteNotification? n = message.notification;
    final Map<String, dynamic> data = message.data;

    String pick(String? primary, String dataKey) {
      if (primary != null && primary.trim().isNotEmpty) return primary.trim();
      final Object? d = data[dataKey];
      return d is String ? d.trim() : '';
    }

    return AppNotification(
      id: message.messageId ?? '',
      title: pick(n?.title, 'title'),
      body: pick(n?.body, 'body'),
      receivedAt: message.sentTime ?? DateTime.now(),
    );
  }
}
