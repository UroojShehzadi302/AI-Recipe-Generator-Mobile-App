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
// For ThemeMode only — this file stays widget-free so the FCM background
// isolate can use it.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/text_scale_provider.dart' show AppTextScale;

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

  /// SharedPreferences key for the light/dark/system theme preference.
  static const String themeModeKey = 'settings_theme_mode';

  /// Stored as a stable string rather than [ThemeMode.index].
  ///
  /// The index would silently change meaning if the enum were ever reordered,
  /// turning a stored "dark" into "light" on upgrade. Names cost nothing and
  /// cannot rot that way.
  static const String _system = 'system';
  static const String _light = 'light';
  static const String _dark = 'dark';

  /// The user's saved theme choice, defaulting to [ThemeMode.system].
  ///
  /// Following the device is the right default for a fresh install: asserting a
  /// preference the user never expressed is worse than matching their phone.
  /// An unrecognised stored value also falls back to system.
  static Future<ThemeMode> loadThemeMode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      switch (prefs.getString(themeModeKey)) {
        case _light:
          return ThemeMode.light;
        case _dark:
          return ThemeMode.dark;
        case _system:
          return ThemeMode.system;
        default:
          return ThemeMode.system;
      }
    } catch (e) {
      debugPrint('SettingsStore.loadThemeMode failed: $e');
      return ThemeMode.system;
    }
  }

  /// Persists the theme choice.
  static Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModeKey, _nameFor(mode));
    } catch (e) {
      debugPrint('SettingsStore.saveThemeMode failed: $e');
    }
  }

  static String _nameFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _light;
      case ThemeMode.dark:
        return _dark;
      case ThemeMode.system:
        return _system;
    }
  }

  /// SharedPreferences key for the text size preference.
  static const String textScaleKey = 'settings_text_scale';

  /// The user's saved text size, defaulting to [AppTextScale.medium].
  ///
  /// Stored by stable name for exactly the reason [loadThemeMode] is: an enum
  /// index would silently change meaning if the enum were ever reordered, so a
  /// user who chose "Large" could be upgraded into "Small". An unrecognised
  /// value falls back to medium — the size the app shipped with.
  static Future<AppTextScale> loadTextScale() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return AppTextScale.fromName(prefs.getString(textScaleKey));
    } catch (e) {
      debugPrint('SettingsStore.loadTextScale failed: $e');
      return AppTextScale.medium;
    }
  }

  /// Persists the text size choice.
  static Future<void> saveTextScale(AppTextScale scale) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(textScaleKey, scale.storageName);
    } catch (e) {
      debugPrint('SettingsStore.saveTextScale failed: $e');
    }
  }
}
