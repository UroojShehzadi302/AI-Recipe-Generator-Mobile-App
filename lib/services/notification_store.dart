// On-device persistence for the notifications inbox.
//
// A thin seam over `shared_preferences` holding the received notifications as a
// JSON string, so the inbox survives app restarts. Deliberately Firebase-free
// and built from **static** methods: the FCM background isolate (see
// `_firebaseMessagingBackgroundHandler` in `main.dart`) has no access to the
// app's provider graph, so it needs to append to the same store on its own.
//
// Every method is best-effort — storage failures are swallowed and reported as
// an empty list / a no-op, never thrown at the UI. Losing the local inbox is a
// cosmetic problem; crashing over it is not acceptable.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

/// Reads and writes the persisted notifications inbox.
class NotificationStore {
  NotificationStore._();

  /// SharedPreferences key holding the JSON-encoded notification list.
  static const String storageKey = 'notifications_inbox';

  /// Maximum notifications kept on device. Oldest entries beyond this are
  /// dropped so the store cannot grow without bound.
  static const int maxStored = 50;

  /// Loads the persisted notifications, newest first. Returns an empty list if
  /// nothing is stored or the stored value cannot be parsed.
  static Future<List<AppNotification>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // SharedPreferences caches values per isolate. The FCM background isolate
      // writes to the same file, so without an explicit reload the main isolate
      // keeps serving a stale snapshot and never sees those notifications.
      await prefs.reload();

      final String? raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return <AppNotification>[];

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AppNotification>[];

      final List<AppNotification> items = <AppNotification>[];
      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          items.add(AppNotification.fromJson(entry));
        }
      }
      return items;
    } catch (e) {
      debugPrint('NotificationStore.load failed: $e');
      return <AppNotification>[];
    }
  }

  /// Overwrites the stored inbox with [items] (capped at [maxStored]).
  static Future<void> save(List<AppNotification> items) async {
    try {
      final List<AppNotification> capped = items.length > maxStored
          ? items.sublist(0, maxStored)
          : items;
      final String raw = jsonEncode(
        capped.map((AppNotification n) => n.toJson()).toList(),
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, raw);
    } catch (e) {
      debugPrint('NotificationStore.save failed: $e');
    }
  }

  /// Inserts [notification] at the top of the stored inbox, skipping it if an
  /// entry with the same non-empty id is already there.
  ///
  /// This is the entry point the **background isolate** uses, so a notification
  /// that arrives while the app is closed is still in the inbox next launch —
  /// even if the user never taps the tray notification.
  static Future<void> append(AppNotification notification) async {
    try {
      final List<AppNotification> items = await load();
      final String key = notification.dedupeKey;
      if (items.any((AppNotification n) => n.dedupeKey == key)) return;

      await save(<AppNotification>[notification, ...items]);
    } catch (e) {
      debugPrint('NotificationStore.append failed: $e');
    }
  }

  /// Removes every stored notification.
  static Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (e) {
      debugPrint('NotificationStore.clear failed: $e');
    }
  }
}
