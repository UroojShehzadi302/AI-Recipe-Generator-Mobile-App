// Offline handling (M12): the connectivity seam, the provider, the banner, and
// offline-aware AI error wording.
//
// Everything here injects a FAKE ConnectivityService. Nothing touches Firebase
// and nothing touches the real network — the one implementation that would
// (ProbeConnectivityService's DNS lookup) is tested through its injectable
// `probe` parameter, so the suite stays hermetic and fast.
//
// The behaviour worth pinning is the RESTRAINT: a single failed request must
// NOT declare the user offline. That is the difference between a banner people
// trust and one they learn to ignore.

import 'dart:async';
import 'dart:io';

import 'package:ai_recipe_generator/core/constants/app_strings.dart';
import 'package:ai_recipe_generator/core/error/failure.dart';
import 'package:ai_recipe_generator/core/widgets/offline_banner.dart';
import 'package:ai_recipe_generator/providers/chat_provider.dart';
import 'package:ai_recipe_generator/providers/connectivity_provider.dart';
import 'package:ai_recipe_generator/providers/recipe_provider.dart';
import 'package:ai_recipe_generator/repositories/chat_repository.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/ai_service.dart';
import 'package:ai_recipe_generator/services/connectivity_service.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:ai_recipe_generator/services/probe_connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

/// A [ConnectivityService] whose status is driven directly by the test.
///
/// Records what it was told so the "providers report outcomes" assertions can
/// check the signal reached the seam, not just that nothing threw.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService([this._status = ConnectivityStatus.online]);

  ConnectivityStatus _status;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  int failureReports = 0;
  int successReports = 0;
  int checks = 0;
  bool disposed = false;

  /// What `check()` will resolve to.
  ConnectivityStatus checkResult = ConnectivityStatus.online;

  @override
  ConnectivityStatus get status => _status;

  @override
  Stream<ConnectivityStatus> get onStatusChange => _controller.stream;

  @override
  void reportFailure() => failureReports++;

  @override
  void reportSuccess() => successReports++;

  @override
  Future<ConnectivityStatus> check() async {
    checks++;
    emit(checkResult);
    return _status;
  }

  /// Pushes a new status as though the real service had detected it.
  void emit(ConnectivityStatus next) {
    if (next == _status) return;
    _status = next;
    _controller.add(next);
  }

  /// Pushes an error down the stream — the provider must survive it.
  void emitError(Object error) => _controller.addError(error);

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}

/// An [AiService] that always fails with the supplied [Failure].
class FailingAiService implements AiService {
  FailingAiService(this.failure);

  final Failure failure;

  @override
  Future<String> generateRecipe(String prompt) async => throw failure;

  @override
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async =>
      throw failure;

  @override
  Future<String> generateTitle(String message, String reply) async =>
      throw failure;
}

/// An [AiService] that always succeeds, for the recovery path.
class WorkingAiService implements AiService {
  @override
  Future<String> generateRecipe(String prompt) async =>
      '{"title":"Test","ingredients":[],"instructions":[]}';

  @override
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async =>
      'Here is a reply.';

  @override
  Future<String> generateTitle(String message, String reply) async => 'Title';
}

/// Wraps [child] in the providers the banner needs.
Widget _hostBanner(ConnectivityProvider provider) {
  return ChangeNotifierProvider<ConnectivityProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(body: OfflineBanner()),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // ProbeConnectivityService — status transitions
  // ---------------------------------------------------------------------------
  group('ProbeConnectivityService', () {
    test('starts online, because nothing has failed yet', () {
      final service = ProbeConnectivityService(probe: () async => true);
      addTearDown(service.dispose);

      // Optimistic by design: showing an offline banner at launch, before a
      // single request has been made, would be a guess.
      expect(service.status, ConnectivityStatus.online);
    });

    test('a failed request goes to unknown first, not straight to offline',
        () async {
      // THE central restraint. One failure is far more often a 500 or a bad URL
      // than a dead connection.
      final service = ProbeConnectivityService(
        probe: () async => true,
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      service.reportFailure();
      expect(
        service.status,
        ConnectivityStatus.unknown,
        reason: 'must not declare offline before the probe has confirmed',
      );
    });

    test('confirms offline only when the probe also fails', () async {
      final service = ProbeConnectivityService(
        probe: () async => false,
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      service.reportFailure();
      await service.check();

      expect(service.status, ConnectivityStatus.offline);
    });

    test('a failed request whose probe SUCCEEDS settles back to online',
        () async {
      // The server was broken, not the network. The banner must never appear.
      final service = ProbeConnectivityService(
        probe: () async => true,
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      service.reportFailure();
      await service.check();

      expect(service.status, ConnectivityStatus.online);
    });

    test('a throwing probe is treated as offline, not as an error', () async {
      final service = ProbeConnectivityService(
        probe: () async => throw const SocketException('no route'),
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      // Must not throw out of check().
      final ConnectivityStatus status = await service.check();
      expect(status, ConnectivityStatus.offline);
    });

    test('a hanging probe times out and reports offline', () async {
      final service = ProbeConnectivityService(
        // Never completes — a dead network's resolver.
        probe: () => Completer<bool>().future,
        probeTimeout: const Duration(milliseconds: 20),
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      expect(await service.check(), ConnectivityStatus.offline);
    });

    test('reportSuccess clears an offline state with no probe', () async {
      int probeCalls = 0;
      final service = ProbeConnectivityService(
        probe: () async {
          probeCalls++;
          return false;
        },
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      await service.check();
      expect(service.status, ConnectivityStatus.offline);

      final int before = probeCalls;
      service.reportSuccess();

      expect(service.status, ConnectivityStatus.online);
      expect(
        probeCalls,
        before,
        reason: 'a completed request is proof enough; no round trip needed',
      );
    });

    test('emits only on genuine transitions, never a repeated value', () async {
      final service = ProbeConnectivityService(
        probe: () async => false,
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      final List<ConnectivityStatus> seen = <ConnectivityStatus>[];
      service.onStatusChange.listen(seen.add);

      service.reportSuccess(); // already online — no event
      await service.check(); // online -> offline
      await service.check(); // offline -> offline, no event
      service.reportSuccess(); // offline -> online

      await Future<void>.delayed(Duration.zero);

      expect(seen, <ConnectivityStatus>[
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
    });

    test('rate-limits probes so repeated checks do not hammer the network',
        () async {
      int probeCalls = 0;
      final service = ProbeConnectivityService(
        probe: () async {
          probeCalls++;
          return true;
        },
        minProbeInterval: const Duration(minutes: 5),
      );
      addTearDown(service.dispose);

      await service.check();
      await service.check();
      await service.check();

      expect(
        probeCalls,
        1,
        reason: 'a probe costs a real round trip; only the first should run',
      );
    });

    test('while offline, further failures do not re-probe', () async {
      int probeCalls = 0;
      final service = ProbeConnectivityService(
        probe: () async {
          probeCalls++;
          return false;
        },
        minProbeInterval: Duration.zero,
      );
      addTearDown(service.dispose);

      await service.check();
      expect(service.status, ConnectivityStatus.offline);

      final int before = probeCalls;
      service.reportFailure();
      service.reportFailure();
      await Future<void>.delayed(Duration.zero);

      expect(probeCalls, before, reason: 'nothing new to learn while offline');
    });

    test('does not emit after dispose', () async {
      final service = ProbeConnectivityService(
        probe: () async => false,
        minProbeInterval: Duration.zero,
      );

      service.dispose();
      // Must not throw on a closed controller.
      expect(() => service.reportFailure(), returnsNormally);
      expect(await service.check(), ConnectivityStatus.online);
    });
  });

  // ---------------------------------------------------------------------------
  // ConnectivityProvider
  // ---------------------------------------------------------------------------
  group('ConnectivityProvider', () {
    test('is constructible with no Firebase and no WidgetsBinding', () {
      // The codebase rule that a ThemeProvider bug was traced to. No
      // TestWidgetsFlutterBinding.ensureInitialized() has run in this group.
      final service = FakeConnectivityService();
      expect(() => ConnectivityProvider(service), returnsNormally);
    });

    test('mirrors the service status it was constructed with', () {
      final service = FakeConnectivityService(ConnectivityStatus.offline);
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      expect(provider.status, ConnectivityStatus.offline);
      expect(provider.isOffline, isTrue);
    });

    test('notifies listeners when the service transitions', () async {
      final service = FakeConnectivityService();
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      int notifications = 0;
      provider.addListener(() => notifications++);

      service.emit(ConnectivityStatus.offline);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isOffline, isTrue);
      expect(notifications, 1);
    });

    test('unknown does NOT read as offline', () async {
      // A suspected-but-unconfirmed outage must render nothing.
      final service = FakeConnectivityService();
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      service.emit(ConnectivityStatus.unknown);
      await Future<void>.delayed(Duration.zero);

      expect(provider.status, ConnectivityStatus.unknown);
      expect(
        provider.isOffline,
        isFalse,
        reason: 'only a confirmed outage may be shown to the user',
      );
    });

    test('never throws when the status stream errors', () async {
      final service = FakeConnectivityService(ConnectivityStatus.offline);
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      service.emitError(StateError('stream blew up'));
      await Future<void>.delayed(Duration.zero);

      // Degrades to "no known problem" rather than crashing or asserting a
      // false outage.
      expect(provider.isOffline, isFalse);
    });

    test('refresh() never throws even if the service does', () async {
      final provider = ConnectivityProvider(_ThrowingCheckService());
      addTearDown(provider.dispose);

      await expectLater(provider.refresh(), completes);
    });

    test('forwards success/failure reports to the service', () {
      final service = FakeConnectivityService();
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      provider.reportFailure();
      provider.reportSuccess();

      expect(service.failureReports, 1);
      expect(service.successReports, 1);
    });

    test('dispose releases the underlying service', () {
      final service = FakeConnectivityService();
      ConnectivityProvider(service).dispose();
      expect(service.disposed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Offline-aware AI errors
  // ---------------------------------------------------------------------------
  group('Offline-aware AI errors', () {
    test('RecipeProvider: NetworkFailure while offline says so', () async {
      final connectivity = ConnectivityProvider(
        FakeConnectivityService(ConnectivityStatus.offline),
      );
      addTearDown(connectivity.dispose);

      final provider = RecipeProvider(
        RecipeRepository(FirestoreService(), FailingAiService(const NetworkFailure()), MealDbService()),
        connectivity: connectivity,
      );

      await provider.generate('pasta');

      expect(provider.genError, AppStrings.offlineAiError);
    });

    test('RecipeProvider: an AI-side failure keeps its own message', () async {
      // Quota/blocked/bad-response reached Gemini and came back — the network
      // is fine and the message must NOT be replaced with "no internet".
      final connectivity = ConnectivityProvider(
        FakeConnectivityService(ConnectivityStatus.offline),
      );
      addTearDown(connectivity.dispose);

      const AiFailure quota = AiFailure('Daily limit reached.');
      final provider = RecipeProvider(
        RecipeRepository(FirestoreService(), FailingAiService(quota), MealDbService()),
        connectivity: connectivity,
      );

      await provider.generate('pasta');

      expect(provider.genError, quota.message);
    });

    test('RecipeProvider: NetworkFailure while NOT confirmed offline keeps '
        'the original message', () async {
      // The restraint again, at the message layer: unconfirmed means we do not
      // get to claim the user has no internet.
      final connectivity = ConnectivityProvider(
        FakeConnectivityService(ConnectivityStatus.unknown),
      );
      addTearDown(connectivity.dispose);

      const NetworkFailure network = NetworkFailure();
      final provider = RecipeProvider(
        RecipeRepository(FirestoreService(), FailingAiService(network), MealDbService()),
        connectivity: connectivity,
      );

      await provider.generate('pasta');

      expect(provider.genError, network.message);
      expect(provider.genError, isNot(AppStrings.offlineAiError));
    });

    test('RecipeProvider: a network failure is reported to connectivity',
        () async {
      final service = FakeConnectivityService();
      final connectivity = ConnectivityProvider(service);
      addTearDown(connectivity.dispose);

      final provider = RecipeProvider(
        RecipeRepository(FirestoreService(), FailingAiService(const NetworkFailure()), MealDbService()),
        connectivity: connectivity,
      );

      await provider.generate('pasta');

      expect(service.failureReports, 1);
    });

    test('RecipeProvider: an AI failure is NOT reported as a network problem',
        () async {
      final service = FakeConnectivityService();
      final connectivity = ConnectivityProvider(service);
      addTearDown(connectivity.dispose);

      final provider = RecipeProvider(
        RecipeRepository(
          FirestoreService(),
          FailingAiService(const AiFailure('blocked')),
          MealDbService(),
        ),
        connectivity: connectivity,
      );

      await provider.generate('pasta');

      expect(
        service.failureReports,
        0,
        reason: 'the request reached the model, so the connection works',
      );
    });

    test('RecipeProvider works with no connectivity provider at all', () async {
      // Construction and behaviour must not depend on the optional wiring.
      final provider = RecipeProvider(
        RecipeRepository(
          FirestoreService(),
          FailingAiService(const NetworkFailure()),
          MealDbService(),
        ),
      );

      await expectLater(provider.generate('pasta'), completes);
      expect(provider.genError, isNotNull);
    });

    test('ChatProvider: NetworkFailure while offline says so', () async {
      final connectivity = ConnectivityProvider(
        FakeConnectivityService(ConnectivityStatus.offline),
      );
      addTearDown(connectivity.dispose);

      final provider = ChatProvider(
        ChatRepository(ai: FailingAiService(const NetworkFailure())),
        connectivity: connectivity,
      );

      await provider.sendMessage('hello');

      expect(provider.errorMessage, AppStrings.offlineAiError);
      // The message is also shown inline in the conversation.
      expect(provider.messages.last.text, AppStrings.offlineAiError);
    });

    test('ChatProvider: an AI-side failure keeps its own message', () async {
      final connectivity = ConnectivityProvider(
        FakeConnectivityService(ConnectivityStatus.offline),
      );
      addTearDown(connectivity.dispose);

      const AiFailure blocked = AiFailure('Your request was blocked.');
      final provider = ChatProvider(
        ChatRepository(ai: FailingAiService(blocked)),
        connectivity: connectivity,
      );

      await provider.sendMessage('hello');

      expect(provider.errorMessage, blocked.message);
    });

    test('ChatProvider: a successful send reports connectivity success',
        () async {
      final service = FakeConnectivityService(ConnectivityStatus.offline);
      final connectivity = ConnectivityProvider(service);
      addTearDown(connectivity.dispose);

      final provider = ChatProvider(
        ChatRepository(ai: WorkingAiService()),
        connectivity: connectivity,
      );

      await provider.sendMessage('hello');

      expect(service.successReports, greaterThan(0));
      expect(provider.errorMessage, isNull);
    });

    test('ChatProvider works with no connectivity provider at all', () async {
      final provider = ChatProvider(
        ChatRepository(ai: FailingAiService(const NetworkFailure())),
      );

      await expectLater(provider.sendMessage('hello'), completes);
      expect(provider.errorMessage, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // OfflineBanner
  // ---------------------------------------------------------------------------
  group('OfflineBanner', () {
    testWidgets('is invisible while online', (tester) async {
      final provider = ConnectivityProvider(FakeConnectivityService());
      addTearDown(provider.dispose);

      await tester.pumpWidget(_hostBanner(provider));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineBanner), findsNothing);
    });

    testWidgets('is invisible while merely unknown', (tester) async {
      // The restraint, at the widget layer.
      final service = FakeConnectivityService();
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(_hostBanner(provider));
      service.emit(ConnectivityStatus.unknown);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineBanner), findsNothing);
    });

    testWidgets('appears when the status becomes offline', (tester) async {
      final service = FakeConnectivityService();
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(_hostBanner(provider));
      expect(find.text(AppStrings.offlineBanner), findsNothing);

      service.emit(ConnectivityStatus.offline);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineBanner), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('hides again when connectivity returns', (tester) async {
      final service = FakeConnectivityService(ConnectivityStatus.offline);
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(_hostBanner(provider));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.offlineBanner), findsOneWidget);

      service.emit(ConnectivityStatus.online);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineBanner), findsNothing);
    });

    testWidgets('takes no vertical space while online', (tester) async {
      // It sits in a Column above the tabs, so an online banner that still
      // reserved height would push every screen down for no reason.
      final provider = ConnectivityProvider(FakeConnectivityService());
      addTearDown(provider.dispose);

      await tester.pumpWidget(_hostBanner(provider));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });

    testWidgets('reserves nothing for the status bar while online',
        (tester) async {
      // Regression: the banner was originally wrapped in a SafeArea inside
      // MainShell, which padded the status-bar height unconditionally — even
      // with the banner collapsed to zero. That left an empty white strip
      // across the top of EVERY screen, which is what shipped and was caught on
      // a device. The inset now lives on the visible strip, so online pays
      // nothing.
      //
      // The plain-host test above cannot catch this: with no inset there is
      // nothing for a stray SafeArea to add. This one supplies a real one.
      final provider = ConnectivityProvider(FakeConnectivityService());
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 48),
          ),
          child: _hostBanner(provider),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });

    testWidgets('clears the status bar when it is actually showing',
        (tester) async {
      // The flip side: the inset must still be paid while visible, or the
      // message sits under the clock and the notch.
      final provider =
          ConnectivityProvider(FakeConnectivityService(ConnectivityStatus.offline));
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 48),
          ),
          child: _hostBanner(provider),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(OfflineBanner)).height,
        OfflineBanner.height + 48,
      );
    });

    testWidgets('renders in dark mode without hardcoded colors',
        (tester) async {
      // Tokens resolve through the runtime palette, so the banner must build
      // under a dark theme exactly as it does under light.
      final service = FakeConnectivityService(ConnectivityStatus.offline);
      final provider = ConnectivityProvider(service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectivityProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: OfflineBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A service whose `check()` throws, to prove the provider swallows it.
class _ThrowingCheckService implements ConnectivityService {
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  @override
  ConnectivityStatus get status => ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> get onStatusChange => _controller.stream;

  @override
  Future<ConnectivityStatus> check() async => throw StateError('boom');

  @override
  void reportFailure() {}

  @override
  void reportSuccess() {}

  @override
  void dispose() => _controller.close();
}
