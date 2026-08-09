// Text size (accessibility): the scaling policy, persistence, and the clamp.
//
// The mechanism here is deliberately the opposite shape to dark mode's. Colours
// had to become getters over a global because ~390 call sites reference them
// without a BuildContext; text size needs no such trick, because Flutter
// already routes every Text through `MediaQuery.textScaler`. These tests pin
// the two decisions that are easy to get wrong and impossible to see in a
// screenshot: that the app's factor MULTIPLIES the OS setting rather than
// replacing it, and that the product is clamped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_recipe_generator/providers/text_scale_provider.dart';
import 'package:ai_recipe_generator/services/settings_store.dart';

void main() {
  group('AppTextScale', () {
    test('medium is exactly 1.0 — the size the app already shipped', () {
      // If this drifts, every existing user's app silently resizes itself on
      // upgrade without them touching a setting.
      expect(AppTextScale.medium.factor, 1.0);
    });

    test('the steps are ordered and distinct', () {
      expect(AppTextScale.small.factor, lessThan(AppTextScale.medium.factor));
      expect(AppTextScale.medium.factor, lessThan(AppTextScale.large.factor));
    });

    test('small keeps the smallest token above the legibility floor', () {
      // AppTextStyles.label is 11px and is the smallest thing the app renders.
      // Anything under ~10px stops being comfortably readable on a phone.
      expect(11 * AppTextScale.small.factor, greaterThanOrEqualTo(9.9));
    });

    test('storage names are stable and explicit, not the enum index', () {
      // Spelled out rather than derived from Enum.name so renaming a Dart
      // identifier cannot orphan every stored preference.
      expect(AppTextScale.small.storageName, 'small');
      expect(AppTextScale.medium.storageName, 'medium');
      expect(AppTextScale.large.storageName, 'large');
    });

    test('fromName round-trips every value', () {
      for (final AppTextScale scale in AppTextScale.values) {
        expect(AppTextScale.fromName(scale.storageName), scale);
      }
    });

    test('null and unrecognised names fall back to medium', () {
      expect(AppTextScale.fromName(null), AppTextScale.medium);
      expect(AppTextScale.fromName('enormous'), AppTextScale.medium);
      expect(AppTextScale.fromName(''), AppTextScale.medium);
    });
  });

  group('TextScaleProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('defaults to medium', () {
      expect(TextScaleProvider().scale, AppTextScale.medium);
    });

    test('is constructible without a Flutter binding', () {
      // Every provider in this codebase must be buildable in a plain unit test.
      // ThemeProvider was recently broken by reading WidgetsBinding.instance
      // internally, which threw "Binding has not yet been initialized". This
      // provider takes the OS scale as an argument for exactly that reason —
      // it never reaches for the binding itself.
      expect(() => TextScaleProvider(), returnsNormally);
      expect(
        () => TextScaleProvider(initialScale: AppTextScale.large)
            .effectiveScaleFor(1.0),
        returnsNormally,
      );
    });

    test('setScale notifies listeners', () async {
      final TextScaleProvider provider = TextScaleProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setScale(AppTextScale.large);

      expect(notifications, 1);
      expect(provider.scale, AppTextScale.large);
    });

    test('setting the same scale does not notify', () async {
      final TextScaleProvider provider = TextScaleProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setScale(AppTextScale.medium);

      expect(notifications, 0);
    });

    test('persists across a reload', () async {
      final TextScaleProvider provider = TextScaleProvider();
      await provider.setScale(AppTextScale.large);

      expect(await SettingsStore.loadTextScale(), AppTextScale.large);

      final TextScaleProvider reloaded = await TextScaleProvider.load();
      expect(reloaded.scale, AppTextScale.large);
    });
  });

  group('Multiply, not replace', () {
    // The core accessibility decision. Replacing the OS scale would discard a
    // device-wide accommodation the moment this app launched — and "Medium"
    // would actively shrink text for a user who had enlarged it system-wide.

    test('medium is a no-op at any OS scale', () {
      final TextScaleProvider provider = TextScaleProvider();
      expect(provider.effectiveScaleFor(1.0), 1.0);
      expect(provider.effectiveScaleFor(1.3), closeTo(1.3, 0.0001));
      expect(provider.effectiveScaleFor(0.85), closeTo(0.85, 0.0001));
    });

    test('the OS setting is preserved, not discarded', () {
      // A user at OS 1.3 who picks "Medium" must still be at 1.3. If this ever
      // returns 1.0, the setting has started overriding an accessibility
      // accommodation rather than adjusting it.
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.medium);
      expect(provider.effectiveScaleFor(1.3), greaterThan(1.0));
    });

    test('large multiplies on top of the OS setting', () {
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.large);
      expect(provider.effectiveScaleFor(1.0), closeTo(1.3, 0.0001));
      // 1.15 OS x 1.3 app = 1.495, under the clamp.
      expect(provider.effectiveScaleFor(1.15), closeTo(1.495, 0.0001));
    });

    test('small still shrinks relative to whatever the OS is doing', () {
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.small);
      expect(provider.effectiveScaleFor(1.2), closeTo(1.08, 0.0001));
    });
  });

  group('Clamping', () {
    test('the compounded maximum is capped', () {
      // Android allows 2.0, and some OEM skins go further. 2.0 x 1.3 = 2.6,
      // which this app's fixed-height nav bar and buttons cannot render.
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.large);
      expect(
        provider.effectiveScaleFor(2.0),
        TextScaleProvider.maxEffectiveScale,
      );
      expect(provider.effectiveScaleFor(3.0),
          TextScaleProvider.maxEffectiveScale);
    });

    test('a user already at the OS maximum sees little change — by design', () {
      // Not a bug: their text is already as large as this layout can hold, so
      // "Large" is nearly a no-op rather than an overflowing screen.
      final TextScaleProvider large =
          TextScaleProvider(initialScale: AppTextScale.large);
      final TextScaleProvider medium = TextScaleProvider();

      expect(large.effectiveScaleFor(2.0), medium.effectiveScaleFor(2.0));
    });

    test('the compounded minimum is capped', () {
      // Android's "Small" is ~0.85; 0.85 x 0.9 = 0.765 would put the 11px label
      // token under 8.5px.
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.small);
      expect(
        provider.effectiveScaleFor(0.5),
        TextScaleProvider.minEffectiveScale,
      );
    });

    test('the clamp bounds bracket the untouched default', () {
      // A plain 1.0 device on Medium must never be clamped — otherwise the
      // setting changes the app for users who never opened it.
      expect(TextScaleProvider.minEffectiveScale, lessThan(1.0));
      expect(TextScaleProvider.maxEffectiveScale, greaterThan(1.0));
      expect(TextScaleProvider().effectiveScaleFor(1.0), 1.0);
    });

    test('scalerFor produces a TextScaler carrying the effective scale', () {
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.large);

      final TextScaler scaler = provider.scalerFor(TextScaler.noScaling);
      expect(scaler.scale(10), closeTo(13.0, 0.0001));

      // Reads the OS scaler rather than assuming it, so a non-linear platform
      // curve is sampled instead of guessed.
      final TextScaler onTopOfOs =
          provider.scalerFor(const TextScaler.linear(1.2));
      expect(onTopOfOs.scale(10), closeTo(15.6, 0.0001));
    });
  });

  group('SettingsStore text size persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('defaults to medium when nothing is stored', () async {
      expect(await SettingsStore.loadTextScale(), AppTextScale.medium);
    });

    test('round-trips every scale', () async {
      for (final AppTextScale scale in AppTextScale.values) {
        await SettingsStore.saveTextScale(scale);
        expect(await SettingsStore.loadTextScale(), scale);
      }
    });

    test('stores a stable name, not the enum index', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsStore.textScaleKey: 'large',
      });
      expect(await SettingsStore.loadTextScale(), AppTextScale.large);
    });

    test('an unrecognised stored value falls back to medium', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsStore.textScaleKey: 'gigantic',
      });
      expect(await SettingsStore.loadTextScale(), AppTextScale.medium);
    });
  });

  group('The scale actually reaches MediaQuery', () {
    // The unit tests above prove the arithmetic. This proves the wiring: that
    // the number a Text actually lays out with is the one the provider chose.

    /// Builds the same MediaQuery-override shape `app.dart` installs via
    /// `MaterialApp.builder`, and reports the scaler a descendant Text sees.
    Future<TextScaler> scalerSeenByChild(
      WidgetTester tester, {
      required TextScaleProvider provider,
      required double osScale,
    }) async {
      late TextScaler seen;

      await tester.pumpWidget(
        ChangeNotifierProvider<TextScaleProvider>.value(
          value: provider,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(osScale)),
            child: Builder(
              builder: (BuildContext context) {
                final TextScaleProvider p = context.watch<TextScaleProvider>();
                final MediaQueryData media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: p.scalerFor(media.textScaler),
                  ),
                  child: Builder(
                    builder: (BuildContext inner) {
                      seen = MediaQuery.textScalerOf(inner);
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      return seen;
    }

    testWidgets('the chosen size lands in the subtree', (tester) async {
      final TextScaleProvider provider =
          TextScaleProvider(initialScale: AppTextScale.large);

      final TextScaler seen = await scalerSeenByChild(
        tester,
        provider: provider,
        osScale: 1.0,
      );

      expect(seen.scale(10), closeTo(13.0, 0.0001));
    });

    testWidgets('the OS scale is still honoured under the app setting',
        (tester) async {
      final TextScaler seen = await scalerSeenByChild(
        tester,
        provider: TextScaleProvider(),
        osScale: 1.4,
      );

      // Medium means "leave the device setting alone", not "reset to 1.0".
      expect(seen.scale(10), closeTo(14.0, 0.0001));
    });

    testWidgets('changing the setting reflows the subtree', (tester) async {
      final TextScaleProvider provider = TextScaleProvider();

      late TextScaler after;
      await tester.pumpWidget(
        ChangeNotifierProvider<TextScaleProvider>.value(
          value: provider,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (BuildContext context) {
                final TextScaleProvider p = context.watch<TextScaleProvider>();
                final MediaQueryData media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: p.scalerFor(media.textScaler),
                  ),
                  child: Builder(
                    builder: (BuildContext inner) {
                      after = MediaQuery.textScalerOf(inner);
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(after.scale(10), closeTo(10.0, 0.0001));

      await provider.setScale(AppTextScale.large);
      await tester.pump();

      expect(after.scale(10), closeTo(13.0, 0.0001));
    });

    testWidgets('a real Text lays out larger at the large setting',
        (tester) async {
      Future<double> heightAt(AppTextScale scale) async {
        final TextScaleProvider provider =
            TextScaleProvider(initialScale: scale);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (BuildContext context) {
                  final MediaQueryData media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: provider.scalerFor(media.textScaler),
                    ),
                    child: const Center(
                      child: Text('Recipe', style: TextStyle(fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        return tester.getSize(find.text('Recipe')).height;
      }

      final double medium = await heightAt(AppTextScale.medium);
      final double large = await heightAt(AppTextScale.large);
      final double small = await heightAt(AppTextScale.small);

      expect(large, greaterThan(medium));
      expect(small, lessThan(medium));
    });
  });
}
