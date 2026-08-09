// Dependency-free [ConnectivityService]: learn from real failures, confirm with
// a DNS lookup.
//
// WHY THERE IS NO `connectivity_plus` HERE
// ----------------------------------------
// Adding a package is the owner's call and has not been authorised, so this is
// built on `dart:io`'s [InternetAddress.lookup] — which needs no plugin, no
// Gradle change, and no manifest entry.
//
// WHAT THIS CAN AND CANNOT DETECT — read before trusting it
// ---------------------------------------------------------
// CAN detect:
//  * A request the app itself made failing at the transport layer. This is the
//    PRIMARY signal and it is the honest one: it is not a proxy for
//    connectivity, it IS the thing the user cares about (the app couldn't
//    fetch). Both `MealDbService` and `GeminiDirectService` already collapse
//    socket/DNS/timeout errors into `NetworkFailure`, so the signal is free.
//  * Total absence of a route, via the confirmation lookup: with no network,
//    `InternetAddress.lookup` fails fast with a `SocketException`.
//  * Recovery, the moment any request succeeds.
//
// CANNOT detect:
//  * A connection that comes back while the app is idle. Nothing polls, so the
//    banner clears on the next successful request, an app resume, or a Retry —
//    not spontaneously a second after Wi-Fi reconnects. This is a deliberate
//    trade of freshness for battery; `connectivity_plus` fixes exactly this
//    (see the TODO box).
//  * A captive portal (hotel/airport Wi-Fi). DNS often resolves inside the
//    walled garden, so the lookup succeeds and this reports `online` while
//    every real request is being redirected to a login page. `connectivity_plus`
//    does not fix this either — nothing short of an authenticated HTTP probe
//    does.
//  * Which transport is in use (Wi-Fi vs cellular vs none). `dart:io` does not
//    expose it. Nothing in this app needs it today; a "you're on mobile data"
//    warning would require the package.
//  * A DNS-level block or a poisoned resolver, which looks identical to being
//    offline.
//
// In short: a successful lookup means "DNS answered", NOT "the network works".
// That asymmetry is why the lookup is only ever used to CONFIRM a failure the
// app already observed, and never on its own to assert that things are fine.
//
// COST CONTROL
// ------------
// A lookup is a real network round trip, so it is rate-limited by
// [ProbeConnectivityService.minProbeInterval] and never scheduled on a timer.
// In steady state — the
// normal case, where everything works — this class makes ZERO network calls of
// its own and simply records that requests succeeded.
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ TODO(connectivity_plus): UPGRADING IS A CONTAINED CHANGE.                │
// │                                                                          │
// │ If the owner authorises the dependency, the win is push-based detection: │
// │ the banner would appear/disappear the instant the OS changes network     │
// │ state, with no request needed and no idle-recovery blind spot.           │
// │                                                                          │
// │ 1. Add `connectivity_plus` to pubspec.yaml.                              │
// │ 2. Add a NEW file `lib/services/plugin_connectivity_service.dart`        │
// │    implementing `ConnectivityService`:                                   │
// │      - `Connectivity().onConnectivityChanged` → map                      │
// │        `ConnectivityResult.none` to ConnectivityStatus.offline and       │
// │        anything else to .online, and push onto the same broadcast        │
// │        controller this class uses.                                       │
// │      - `check()` → `await Connectivity().checkConnectivity()`.           │
// │      - KEEP `reportFailure`/`reportSuccess` doing what they do here.     │
// │        The plugin reports whether an INTERFACE is up, which still says   │
// │        nothing about a captive portal — the app's own request outcomes   │
// │        remain the more truthful signal, so the two should be combined,   │
// │        not swapped.                                                      │
// │ 3. Change ONE line in `app/app.dart`:                                    │
// │      FROM: final connectivityService = ProbeConnectivityService();       │
// │      TO:   final connectivityService = PluginConnectivityService();      │
// │                                                                          │
// │ Nothing else changes: `ConnectivityService`, `ConnectivityProvider`,     │
// │ `OfflineBanner`, the repositories and every test depend on the           │
// │ interface, not on this file.                                             │
// └──────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// A [ConnectivityService] driven by the app's own request outcomes, with a
/// `dart:io` DNS lookup used only to confirm a suspected outage.
class ProbeConnectivityService implements ConnectivityService {
  /// Creates a [ProbeConnectivityService].
  ///
  /// [probe] is injectable so tests never touch the real network; it defaults
  /// to a DNS lookup. [probeTimeout] bounds it — a lookup on a dead network can
  /// otherwise hang for the platform's own (long) resolver timeout.
  ProbeConnectivityService({
    Future<bool> Function()? probe,
    this.probeTimeout = const Duration(seconds: 4),
    this.minProbeInterval = const Duration(seconds: 10),
  }) : _probe = probe ?? _dnsLookup;

  /// Host resolved by the default probe.
  ///
  /// A DNS root nameserver: it exists solely to answer lookups, is not blocked
  /// the way a single vendor's domain can be, and resolving it transfers a few
  /// dozen bytes rather than fetching a page.
  static const String _probeHost = 'a.root-servers.net';

  final Future<bool> Function() _probe;

  /// Upper bound on a single lookup. A resolver on a dead network can otherwise
  /// hang for the platform's own (much longer) timeout.
  final Duration probeTimeout;

  /// Floor on how often [check] will actually hit the network. Repeated calls
  /// inside this window reuse the last result instead of issuing a lookup.
  final Duration minProbeInterval;

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  /// Optimistic start: the app has not tried anything yet, so it has no
  /// evidence of a problem. Showing an offline banner at launch before a single
  /// request has been made would be a guess, and usually a wrong one.
  ConnectivityStatus _status = ConnectivityStatus.online;

  DateTime? _lastProbeAt;
  Future<ConnectivityStatus>? _inFlight;
  bool _disposed = false;

  @override
  ConnectivityStatus get status => _status;

  @override
  Stream<ConnectivityStatus> get onStatusChange => _controller.stream;

  @override
  void reportSuccess() {
    // A completed request is the strongest evidence available — stronger than
    // any probe, because it proves the actual route the app uses works. It
    // clears an outage immediately and with no network cost.
    _set(ConnectivityStatus.online);
  }

  @override
  void reportFailure() {
    // Already known-offline: nothing to learn, and re-probing on every failed
    // request while offline would burn battery for no new information.
    if (_status == ConnectivityStatus.offline) return;

    // Do NOT go straight to offline. A single failed request is far more often
    // a 500, a bad URL, or a rate limit than a dead connection, and an
    // "offline" banner shown to someone with working Wi-Fi is worse than no
    // banner. Sit in `unknown` (which renders nothing) while a probe decides.
    _set(ConnectivityStatus.unknown);
    unawaited(_runProbe(force: true));
  }

  @override
  Future<ConnectivityStatus> check() => _runProbe();

  /// Runs the confirmation probe, subject to rate limiting.
  ///
  /// [force] bypasses only the *interval* check, not an in-flight probe: a
  /// burst of failed requests should coalesce into one lookup, not one each.
  Future<ConnectivityStatus> _runProbe({bool force = false}) {
    if (_disposed) return Future<ConnectivityStatus>.value(_status);

    // Coalesce concurrent callers onto the single lookup already running.
    final Future<ConnectivityStatus>? existing = _inFlight;
    if (existing != null) return existing;

    final DateTime? last = _lastProbeAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < minProbeInterval) {
      return Future<ConnectivityStatus>.value(_status);
    }

    final Future<ConnectivityStatus> run = _doProbe();
    _inFlight = run;
    return run.whenComplete(() => _inFlight = null);
  }

  Future<ConnectivityStatus> _doProbe() async {
    _lastProbeAt = DateTime.now();

    bool reachable;
    try {
      reachable = await _probe().timeout(probeTimeout);
    } catch (error) {
      // Any throw — SocketException, TimeoutException, a platform quirk — is
      // treated as "could not reach anything". This is the one place where an
      // error legitimately means offline rather than needing to be surfaced.
      if (kDebugMode) {
        debugPrint('ProbeConnectivityService: probe failed: $error');
      }
      reachable = false;
    }

    // Note the asymmetry, and it is deliberate: a FAILED lookup is decent
    // evidence of being offline, but a SUCCESSFUL one only proves DNS answered
    // (see the header on captive portals). Success therefore returns to
    // `online` — the app's "no known problem" state — rather than asserting
    // that the network is healthy.
    _set(reachable ? ConnectivityStatus.online : ConnectivityStatus.offline);
    return _status;
  }

  /// The default probe: resolve a hostname, without fetching anything.
  ///
  /// With no route at all this fails fast with a [SocketException], which is
  /// exactly the case worth detecting.
  static Future<bool> _dnsLookup() async {
    final List<InternetAddress> result =
        await InternetAddress.lookup(_probeHost);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  }

  /// Updates [status] and emits, but only on a genuine transition — a repeat of
  /// the current value would rebuild every listening widget for nothing.
  void _set(ConnectivityStatus next) {
    if (_disposed || next == _status) return;
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
