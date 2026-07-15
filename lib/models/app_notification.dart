// In-app notification item for the AI Recipe Generator's notifications inbox.
//
// A plain, Firebase-free view model. FCM `RemoteMessage` values are mapped into
// this shape one layer up (in `NotificationService`/`NotificationProvider`) so
// no Firebase Messaging type ever leaks into the model or the widget tree.

/// A single received push notification, as shown in the in-app inbox.
///
/// Immutable (final fields, const constructor). [read] defaults to `false`;
/// use [copyWith] to flip it when the user opens the inbox.
class AppNotification {
  /// Optional stable id (from the FCM `messageId`), used to de-duplicate.
  final String id;

  /// Notification title (from `notification.title` or a `data['title']`).
  final String title;

  /// Notification body (from `notification.body` or a `data['body']`).
  final String body;

  /// When the notification was received on this device.
  final DateTime receivedAt;

  /// Whether the user has seen this notification in the inbox.
  final bool read;

  const AppNotification({
    this.id = '',
    this.title = '',
    this.body = '',
    required this.receivedAt,
    this.read = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? receivedAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      receivedAt: receivedAt ?? this.receivedAt,
      read: read ?? this.read,
    );
  }

  @override
  String toString() =>
      'AppNotification(id: $id, title: $title, read: $read)';
}
