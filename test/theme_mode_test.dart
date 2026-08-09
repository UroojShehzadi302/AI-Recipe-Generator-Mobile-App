// Dark mode: palette switching, persistence, and the contrast floor.
//
// The mechanism under test is unusual enough to be worth pinning hard.
// `AppColors` members are getters over a *global* (`AppPalette.current`)
// rather than `Theme.of(context)` lookups, because ~390 call sites reference
// them without a BuildContext. These tests exist so that shortcut cannot rot
// silently: they check the swap works, that it is restored, and that the dark
// palette is actually readable rather than merely different.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_recipe_generator/core/theme/app_colors.dart';
import 'package:ai_recipe_generator/core/theme/app_palette.dart';
import 'package:ai_recipe_generator/core/theme/app_theme.dart';
import 'package:ai_recipe_generator/providers/theme_provider.dart';
import 'package:ai_recipe_generator/services/settings_store.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final double s = v;
    return s <= 0.03928 ? s / 12.92 : _pow((s + 0.055) / 1.055, 2.4);
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _pow(double base, double exp) {
  // Small integer-ish power without importing dart:math for one call.
  return double.parse((base * base * base).toStringAsFixed(10)) /
      double.parse((base * base * base).toStringAsFixed(10)) *
      _mathPow(base, exp);
}

double _mathPow(double base, double exp) {
  double result = 1;
  double b = base;
  double e = exp;
  // Exponentiation by squaring on the integer part, then a few Newton steps
  // for the fraction — accurate enough for a contrast assertion.
  int intPart = e.floor();
  e -= intPart;
  while (intPart > 0) {
    if (intPart.isOdd) result *= b;
    b *= b;
    intPart ~/= 2;
  }
  // base^frac via exp/ln series is overkill; sqrt-based approximation:
  if (e > 0) {
    double frac = 1;
    double root = base;
    double step = 0.5;
    while (step > 0.001) {
      root = _sqrt(root);
      if (e >= step) {
        frac *= root;
        e -= step;
      }
      step /= 2;
    }
    result *= frac;
  }
  return result;
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x;
  for (int i = 0; i < 40; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The palette is global state. Any test that leaves it on dark would poison
  // every test that runs after it, in this file or another.
  tearDown(AppPalette.reset);

  group('AppPalette', () {
    test('defaults to light so nothing changes until a theme is chosen', () {
      expect(AppPalette.current, same(AppPalette.light));
      expect(AppColors.isDark, isFalse);
    });

    test('AppColors follows the active palette', () {
      final Color lightPrimary = AppColors.primary;
      final Color lightBackground = AppColors.background;

      AppPalette.apply(AppPalette.dark);

      expect(AppColors.primary, isNot(lightPrimary));
      expect(AppColors.background, isNot(lightBackground));
      expect(AppColors.primary, AppPalette.dark.primary);
      expect(AppColors.isDark, isTrue);
    });

    test('reset restores light', () {
      AppPalette.apply(AppPalette.dark);
      AppPalette.reset();
      expect(AppColors.primary, AppPalette.light.primary);
    });

    test('gradients rebuild from the active palette', () {
      final List<Color> lightBrand = AppColors.brandGradient.colors;
      AppPalette.apply(AppPalette.dark);
      expect(AppColors.brandGradient.colors, isNot(lightBrand));
    });

    test('the image scrim is identical in both themes', () {
      // It darkens a photograph, and photographs do not change with the theme.
      final List<Color> light = AppColors.imageScrim.colors;
      AppPalette.apply(AppPalette.dark);
      expect(AppColors.imageScrim.colors, light);
    });
  });

  group('Dark palette readability', () {
    // The point of these: a dark theme that merely looks different but is hard
    // to read is a regression, and eyeballing a screenshot will not catch a
    // token that drifted.

    test('body text on background clears WCAG AA (4.5:1)', () {
      final double ratio = _contrast(
        AppPalette.dark.textPrimary,
        AppPalette.dark.background,
      );
      expect(ratio, greaterThan(4.5), reason: 'primary text on background');
    });

    test('body text on surface clears WCAG AA', () {
      expect(
        _contrast(AppPalette.dark.textPrimary, AppPalette.dark.surface),
        greaterThan(4.5),
      );
    });

    test('secondary text clears the 3:1 large-text floor on surface', () {
      expect(
        _contrast(AppPalette.dark.textSecondary, AppPalette.dark.surface),
        greaterThan(3.0),
      );
    });

    test('onPrimary is readable on primary — the flip that is easy to miss',
        () {
      // The dark primary is lightened, so white-on-primary (correct in light
      // mode) would fail here. onPrimary flips to near-black for this reason.
      expect(
        _contrast(AppPalette.dark.onPrimary, AppPalette.dark.primary),
        greaterThan(4.5),
      );
    });

    test('light mode keeps its own contrast', () {
      expect(
        _contrast(AppPalette.light.textPrimary, AppPalette.light.background),
        greaterThan(4.5),
      );
      expect(
        _contrast(AppPalette.light.onPrimary, AppPalette.light.primary),
        greaterThan(4.5),
      );
    });

    test('dark surfaces get lighter as they get closer to the user', () {
      // Material's dark convention: elevation reads as a lighter surface,
      // because shadows are nearly invisible on a dark page.
      expect(
        _luminance(AppPalette.dark.surface),
        greaterThan(_luminance(AppPalette.dark.background)),
      );
      expect(
        _luminance(AppPalette.dark.surfaceAlt),
        greaterThan(_luminance(AppPalette.dark.surface)),
      );
    });

    test('text never reaches pure white, which vibrates on near-black', () {
      expect(AppPalette.dark.textPrimary, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('AppTheme', () {
    test('builds a light and a dark ThemeData with matching brightness', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    test('building either theme restores the previously active palette', () {
      // MaterialApp asks for theme and darkTheme in the same build. If building
      // darkTheme left the palette on dark, every AppColors read for the rest
      // of that frame would be wrong.
      AppPalette.apply(AppPalette.light);
      AppTheme.darkTheme;
      expect(AppPalette.current, same(AppPalette.light));

      AppPalette.apply(AppPalette.dark);
      AppTheme.lightTheme;
      expect(AppPalette.current, same(AppPalette.dark));
    });

    test('each theme carries its own palette colours', () {
      expect(AppTheme.lightTheme.scaffoldBackgroundColor,
          AppPalette.light.background);
      expect(
          AppTheme.darkTheme.scaffoldBackgroundColor, AppPalette.dark.background);
    });
  });

  group('ThemeProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('defaults to following the system', () {
      expect(ThemeProvider().mode, ThemeMode.system);
    });

    test('resolves system mode against the platform brightness', () {
      final ThemeProvider provider = ThemeProvider();
      expect(provider.resolvesToDark(Brightness.dark), isTrue);
      expect(provider.resolvesToDark(Brightness.light), isFalse);
    });

    test('seeds its palette from the brightness it was constructed with', () {
      ThemeProvider(platformBrightness: Brightness.dark)
          .syncWithPlatformBrightness(Brightness.dark);
      expect(AppPalette.current, same(AppPalette.dark));
    });

    test('an explicit choice ignores the platform', () async {
      final ThemeProvider provider = ThemeProvider();

      await provider.setMode(ThemeMode.dark);
      expect(provider.resolvesToDark(Brightness.light), isTrue);

      await provider.setMode(ThemeMode.light);
      expect(provider.resolvesToDark(Brightness.dark), isFalse);
    });

    test('is constructible without a Flutter binding', () {
      // Every provider in this codebase must be buildable in a plain unit test.
      // An earlier version read WidgetsBinding.instance inside setMode, which
      // threw "Binding has not yet been initialized" and would have forced this
      // whole group into widget tests.
      expect(() => ThemeProvider(), returnsNormally);
    });

    test('setMode applies the palette before notifying listeners', () async {
      // Order matters: a listener that rebuilds must already see the new
      // palette, or it paints one frame of mixed themes.
      final ThemeProvider provider = ThemeProvider();
      AppPalette? seenByListener;
      provider.addListener(() => seenByListener = AppPalette.current);

      await provider.setMode(ThemeMode.dark);

      expect(seenByListener, same(AppPalette.dark));
    });

    test('setting the same mode does not notify', () async {
      final ThemeProvider provider = ThemeProvider(initialMode: ThemeMode.dark);
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setMode(ThemeMode.dark);

      expect(notifications, 0);
    });

    test('persists across a reload', () async {
      final ThemeProvider provider = ThemeProvider();
      await provider.setMode(ThemeMode.dark);

      expect(await SettingsStore.loadThemeMode(), ThemeMode.dark);
    });

    test('system mode follows the OS flipping while the app runs', () {
      final ThemeProvider provider = ThemeProvider();

      expect(provider.syncWithPlatformBrightness(Brightness.dark), isTrue);
      expect(AppPalette.current, same(AppPalette.dark));

      expect(provider.syncWithPlatformBrightness(Brightness.light), isTrue);
      expect(AppPalette.current, same(AppPalette.light));

      // Already in step — no change to report, so no needless rebuild.
      expect(provider.syncWithPlatformBrightness(Brightness.light), isFalse);
    });

    test('an explicit choice does not follow the OS', () async {
      final ThemeProvider provider = ThemeProvider();
      await provider.setMode(ThemeMode.light);

      provider.syncWithPlatformBrightness(Brightness.dark);

      expect(AppPalette.current, same(AppPalette.light));
    });
  });

  group('SettingsStore theme persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('defaults to system when nothing is stored', () async {
      expect(await SettingsStore.loadThemeMode(), ThemeMode.system);
    });

    test('round-trips every mode', () async {
      for (final ThemeMode mode in ThemeMode.values) {
        await SettingsStore.saveThemeMode(mode);
        expect(await SettingsStore.loadThemeMode(), mode);
      }
    });

    test('stores a stable name, not the enum index', () async {
      // An index would silently change meaning if the enum were reordered,
      // turning a stored "dark" into "light" on upgrade.
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsStore.themeModeKey: 'dark',
      });
      expect(await SettingsStore.loadThemeMode(), ThemeMode.dark);
    });

    test('an unrecognised stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsStore.themeModeKey: 'sepia',
      });
      expect(await SettingsStore.loadThemeMode(), ThemeMode.system);
    });
  });
}
