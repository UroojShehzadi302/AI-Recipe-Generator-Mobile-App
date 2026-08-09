// On-device persistence for user preferences set on the Settings screen.
//
// A thin seam over `shared_preferences`, built exactly like
// `notification_store.dart`: Firebase-free, **static** methods, and every one of
// them best-effort — a storage failure reports the default / becomes a no-op and
// is never thrown at the UI. Losing a preference is cosmetic; crashing over it
// is not acceptable.
//
// Static (rather than an injected instance) for the same reason the notification
// store is: the FCM **background isolate** has no access to the app's provider
// graph, so `_firebaseMessagingBackgroundHandler` in `main.dart` must be able to
// read the notifications preference on its own before appending to the inbox.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the user's on-device settings.
class SettingsStore {
  SettingsStore._();

  /// SharedPreferences key for the "receive notifications" preference.
  static const String notificationsKey = 'settings_notifications_enabled';

  /// Notifications are ON unless the user has explicitly turned them off — the
  /// app already asked for OS permission, so defaulting to off would silently
  /// discard messages the user agreed to receive.
  static const bool notificationsDefault = true;

  /// Whether the user wants notifications collected in the in-app inbox.
  ///
  /// Calls `reload()` first for the same reason [NotificationStore.load] does:
  /// SharedPreferences caches per isolate, so the background isolate would
  /// otherwise keep serving whatever value it read when it started.
  static Future<bool> notificationsEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(notificationsKey) ?? notificationsDefault;
    } catch (e) {
      debugPrint('SettingsStore.notificationsEnabled failed: $e');
      return notificationsDefault;
    }
  }

  /// Persists the notifications preference.
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(notificationsKey, enabled);
    } catch (e) {
      debugPrint('SettingsStore.setNotificationsEnabled failed: $e');
    }
  }
}
