// The seam between the app and "is there a working internet connection?".
//
// Mirrors the [AiService] / [ShareService] pattern: providers depend on THIS
// interface, never on a concrete implementation, so how connectivity is
// detected can change without touching anything above it.
//
// Implementations:
// * [ProbeConnectivityService] — dev/prod today: dependency-free. Learns from
//                                the app's OWN request failures and confirms
//                                with an occasional DNS lookup.
// * (future) a `connectivity_plus`-backed service — see the TODO box in
//   [ProbeConnectivityService] for exactly what changes.
//
// ⚠️ READ THIS BEFORE TRUSTING A STATUS
// -------------------------------------
// "Online" here means **the app has no evidence it is offline**, not "a packet
// will definitely get through". No client-side check can promise the latter —
// even `connectivity_plus` only reports whether a network INTERFACE is up, so a
// phone attached to a captive-portal Wi-Fi reports "connected" while nothing
// resolves. The statuses below are deliberately named so nothing in the UI can
// mistake a hint for a guarantee.
//
// Contract notes:
// * Nothing here throws. Connectivity is advisory; a failed probe is itself a
//   signal, not an error to surface.
// * [status] is synchronous and cheap — it is read during `build()`.
// * [onStatusChange] emits ONLY on an actual transition, never a repeat of the
//   current value, so a listening widget cannot be rebuilt in a loop.

/// What the app currently believes about its internet connection.
enum ConnectivityStatus {
  /// No evidence of a problem. This is the startup default and the state after
  /// a successful request or probe.
  ///
  /// ⚠️ NOT a guarantee that the next request will succeed — see the file
  /// header. It means "nothing has failed recently".
  online,

  /// Something the app tried actually failed in a way consistent with having no
  /// connection, and a confirmation probe agreed.
  ///
  /// This is the only status the UI treats as "tell the user they are offline",
  /// because it is the only one backed by a real observed failure.
  offline,

  /// A request failed but the cause is not yet confirmed. Held briefly while a
  /// probe runs.
  ///
  /// The UI deliberately shows NOTHING in this state: a single failed request
  /// is far more often a server hiccup or a bad URL than a dead connection, and
  /// flashing an "offline" banner at someone whose network is fine is worse
  /// than saying nothing at all.
  unknown,
}

/// Transport-level contract for observing internet connectivity.
abstract interface class ConnectivityService {
  /// The current belief about connectivity. Synchronous and side-effect free —
  /// safe to read inside `build()`.
  ConnectivityStatus get status;

  /// Emits on every genuine change of [status] (never a duplicate value).
  ///
  /// Broadcast: multiple listeners are fine, and a late subscriber simply waits
  /// for the next transition rather than receiving the current value.
  Stream<ConnectivityStatus> get onStatusChange;

  /// Tells the service that a network request the app made just FAILED in a way
  /// that looks like a transport problem (socket/DNS/timeout).
  ///
  /// This is the primary signal. The app already discovers connectivity for
  /// free every time it calls TheMealDB or Gemini, so this costs nothing,
  /// whereas polling a probe costs a round trip and battery on a schedule that
  /// is wrong either way.
  void reportFailure();

  /// Tells the service that a network request just SUCCEEDED.
  ///
  /// Unambiguous proof of a working route — stronger evidence than any probe —
  /// so it clears an offline state immediately.
  void reportSuccess();

  /// Actively checks connectivity now and updates [status].
  ///
  /// Costs a real network round trip, so call it on a user-visible moment (a
  /// Retry tap, an app resume) rather than on a timer. Never throws; returns
  /// the status it settled on.
  Future<ConnectivityStatus> check();

  /// Releases any resources (stream controller, pending timers).
  void dispose();
}
