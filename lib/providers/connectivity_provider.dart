// Presentation-layer state for CONNECTIVITY.
//
// A thin [ChangeNotifier] over [ConnectivityService]: it holds no logic of its
// own, it mirrors the service's status into something the widget tree can watch
// and rebuilds when that status changes.
//
// IMPORTANT: construction must NOT touch Firebase, `WidgetsBinding`, or the
// network — this provider is built in plain unit tests. That rule is not
// theoretical here: [ThemeProvider] was recently broken by reaching for the
// binding in its constructor, which made it un-constructible without one. The
// constructor below subscribes to a stream and does nothing else; the service
// decides whether that stream ever costs a network call.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Exposes the app's current connectivity belief to the UI.
class ConnectivityProvider extends ChangeNotifier {
  /// Creates a provider mirroring [service].
  ///
  /// Subscribes immediately so a status change that happens before the first
  /// frame is not missed. Safe in a unit test: [ConnectivityService] is an
  /// interface, and the default implementation makes no network call until
  /// something actually fails.
  ConnectivityProvider(this._service) {
    _status = _service.status;
    _subscription = _service.onStatusChange.listen(
      _onStatus,
      // A connectivity stream erroring must never propagate. Connectivity is
      // advisory: if the signal breaks, the app should behave as though it has
      // no evidence of a problem rather than crash or show a false banner.
      onError: (Object _) => _onStatus(ConnectivityStatus.online),
    );
  }

  final ConnectivityService _service;
  StreamSubscription<ConnectivityStatus>? _subscription;

  ConnectivityStatus _status = ConnectivityStatus.online;

  /// The current connectivity belief.
  ///
  /// ⚠️ [ConnectivityStatus.online] means "no known problem", not a guarantee —
  /// see the header of `connectivity_service.dart`.
  ConnectivityStatus get status => _status;

  /// Whether the app has CONFIRMED evidence that it is offline.
  ///
  /// This is the only thing the UI should gate an "offline" message on.
  /// [ConnectivityStatus.unknown] deliberately reads as *not* offline: one
  /// failed request is usually a server problem, and telling a user with
  /// working Wi-Fi that they have no connection is a worse error than saying
  /// nothing.
  bool get isOffline => _status == ConnectivityStatus.offline;

  /// Records that a network request the app made failed at the transport layer.
  ///
  /// Called from the provider layer when a repository surfaces a
  /// `NetworkFailure`. The service decides what to do with it (it confirms with
  /// a probe before declaring an outage).
  void reportFailure() => _service.reportFailure();

  /// Records that a network request succeeded — clears an offline state at
  /// zero network cost.
  void reportSuccess() => _service.reportSuccess();

  /// Actively re-checks connectivity now.
  ///
  /// Costs a network round trip, so call it on a user-visible moment (a Retry
  /// tap, an app resume) rather than on a timer. Never throws.
  Future<void> refresh() async {
    try {
      await _service.check();
    } catch (_) {
      // The service contract says this never throws; belt-and-braces so a
      // future implementation cannot take the UI down with it.
    }
  }

  void _onStatus(ConnectivityStatus next) {
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
