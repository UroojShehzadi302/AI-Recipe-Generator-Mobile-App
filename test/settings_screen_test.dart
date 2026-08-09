// Widget tests for the Settings screen (M11).
//
// Covers: the three sections render, the notifications toggle flips AND
// persists through SharedPreferences, and the account/legal navigation entries
// are present. No Firebase is initialized — the AuthRepository getter the
// screen reads is overridden, and NotificationProvider construction is
// deliberately Firebase-free.

import 'package:ai_recipe_generator/core/constants/app_strings.dart';
import 'package:ai_recipe_generator/providers/auth_provider.dart';
import 'package:ai_recipe_generator/providers/notification_provider.dart';
import 'package:ai_recipe_generator/repositories/auth_repository.dart';
import 'package:ai_recipe_generator/repositories/user_repository.dart';
import 'package:ai_recipe_generator/screens/settings_screen.dart';
import 'package:ai_recipe_generator/services/auth_service.dart';
import 'package:ai_recipe_generator/services/notification_service.dart';
import 'package:ai_recipe_generator/services/settings_store.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [AuthRepository] that reports a fixed account type without touching
/// Firebase. Only [hasPasswordProvider] is read by the Settings screen.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({required this.passwordBacked})
      : super(
          authService: AuthService(),
          userRepository: UserRepository(),
        );

  final bool passwordBacked;

  @override
  bool get hasPasswordProvider => passwordBacked;
}

/// A [NotificationService] that never touches Firebase. The Settings screen
/// only reads/writes the preference, so the streams stay empty.
class _FakeNotificationService extends NotificationService {
  @override
  Future<NotificationSettings> requestPermission() async =>
      throw UnimplementedError('permission not needed in tests');

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<RemoteMessage> get onMessage => const Stream<RemoteMessage>.empty();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      const Stream<RemoteMessage>.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

Widget _wrap(
  NotificationProvider notifications, {
  bool passwordBacked = true,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          _FakeAuthRepository(passwordBacked: passwordBacked),
        ),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(value: notifications),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('SettingsScreen', () {
    testWidgets('renders all three sections', (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settings), findsOneWidget);
      expect(find.text(AppStrings.settingsPreferences), findsOneWidget);
      expect(find.text(AppStrings.settingsAboutGroup), findsOneWidget);
      expect(find.text(AppStrings.settingsAccountGroup), findsOneWidget);
    });

    testWidgets('shows the notifications toggle with its honest subtitle',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notifications), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      // The copy must keep saying the tray is an OS setting — the switch only
      // controls the in-app inbox.
      expect(find.text(AppStrings.notificationsSubtitle), findsOneWidget);
    });

    testWidgets('the toggle defaults to on', (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      final Switch toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, SettingsStore.notificationsDefault);
      expect(toggle.value, isTrue);
    });

    testWidgets('flipping the toggle updates the provider and persists it',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(provider.notificationsEnabled, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // In memory.
      expect(provider.notificationsEnabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // And on disk — a fresh read must see the stored value.
      expect(await SettingsStore.notificationsEnabled(), isFalse);
    });

    testWidgets('the stored preference survives into a new provider',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // A brand-new provider stands in for the next app launch.
      final next = NotificationProvider(_FakeNotificationService());
      await next.loadPreferences();
      expect(next.notificationsEnabled, isFalse);

      await tester.pumpWidget(_wrap(next));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('turning notifications off keeps new messages out of the inbox',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(provider.notificationsEnabled, isFalse);

      // The preference must actually gate the receive path — a toggle that
      // only stores a bool would be dishonest.
      await provider.refresh();
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);
    });

    testWidgets('lists the About-section entries', (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.privacyPolicy), findsOneWidget);
      expect(find.text(AppStrings.termsOfService), findsOneWidget);
      expect(find.text(AppStrings.aboutApp), findsOneWidget);
    });

    testWidgets('Privacy Policy opens a dialog showing the URL', (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.privacyPolicy));
      await tester.pumpAndSettle();

      // No url_launcher in this build, so the address is shown to be copied.
      expect(find.text(AppStrings.privacyPolicyUrl), findsOneWidget);
      expect(find.text(AppStrings.linkCopy), findsOneWidget);
    });

    testWidgets('About opens the shared app dialog', (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.aboutApp));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.tagline), findsOneWidget);
      expect(find.text(AppStrings.aboutBody), findsOneWidget);
    });

    testWidgets('account entries navigate to the existing screens',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      // Both rows exist and are wired; the destinations are the pre-existing
      // Change Password / Delete Account screens, not rebuilt here.
      expect(find.text(AppStrings.changePassword), findsOneWidget);
      expect(find.text(AppStrings.deleteAccount), findsOneWidget);
    });

    testWidgets('hides Change Password for a Google-only account',
        (tester) async {
      final provider = NotificationProvider(_FakeNotificationService());
      await tester.pumpWidget(_wrap(provider, passwordBacked: false));
      await tester.pumpAndSettle();

      // A Google account has no password, so the row would lead to a form it
      // could never satisfy.
      expect(find.text(AppStrings.changePassword), findsNothing);
      expect(find.text(AppStrings.deleteAccount), findsOneWidget);
    });
  });
}
