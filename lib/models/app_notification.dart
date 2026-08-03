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

  /// Stable key used to recognise the same notification twice.
  ///
  /// Prefers the FCM [id]. FCM does not *guarantee* a `messageId`, and an
  /// id-less notification must still de-duplicate — the same message is seen
  /// twice whenever the background isolate stores it and the user then taps it
  /// open. Falling back to the content keeps that a single inbox entry.
  ///
  /// Tradeoff: two notifications with an identical title AND body AND no
  /// message id collapse into one. That is far preferable to the alternative,
  /// where every app resume re-adds another copy of the same notification.
  String get dedupeKey => id.isNotEmpty ? id : '$title|$body';

  /// Serializes to a plain JSON map for on-device persistence.
  ///
  /// [receivedAt] is stored as milliseconds since epoch (UTC-safe and stable
  /// across locales) rather than a formatted string.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
        'read': read,
      };

  /// Rebuilds an [AppNotification] from [toJson] output.
  ///
  /// Defensive: any missing or wrongly-typed field falls back to a sane default
  /// so a corrupted stored entry degrades instead of throwing.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final Object? millis = json['receivedAt'];
    return AppNotification(
      id: json['id'] is String ? json['id'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      body: json['body'] is String ? json['body'] as String : '',
      receivedAt: millis is int
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
      read: json['read'] is bool ? json['read'] as bool : false,
    );
  }

  @override
  String toString() =>
      'AppNotification(id: $id, title: $title, read: $read)';
}
