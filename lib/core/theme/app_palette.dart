import 'package:flutter/material.dart';

/// The two concrete colour palettes CookMate AI ships, and the switch that
/// decides which one [AppColors] is currently reading.
///
/// ## Why this exists
///
/// Every colour in the app is referenced as `AppColors.primary` — a bare static
/// with no `BuildContext` in sight, at ~390 call sites across ~40 files. Dark
/// mode has to change what those references resolve to *at runtime*, and a
/// `static const` cannot change at runtime.
///
/// Threading a `BuildContext` through all ~390 sites would mean rewriting every
/// widget that draws anything. Instead `AppColors` keeps its exact call shape
/// and becomes a set of getters that read [AppPalette.current]. Call sites do
/// not change at all; only the `const` keyword has to come off the handful of
/// expressions that demanded a compile-time constant.
///
/// ## The tradeoff, stated plainly
///
/// This is deliberately *not* Flutter's idiomatic `Theme.of(context)` lookup.
/// The palette is global mutable state, so nothing rebuilds automatically when
/// it changes — [ThemeController] owns the swap and forces one rebuild of the
/// whole app after setting it. That is the price of not rewriting 390 call
/// sites, and it is paid in exactly one place.
///
/// The consequence to remember: **a widget that caches a colour in a field or a
/// `late final` will keep the old palette across a theme switch.** Read colours
/// in `build()`, which is what every screen here already does.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryFaint,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.onPrimary,
    required this.border,
    required this.borderSoft,
    required this.disabled,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.backgroundGradientTop,
  });

  final Brightness brightness;

  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color primaryFaint;
  final Color secondary;

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color scrim;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color onPrimary;

  final Color border;
  final Color borderSoft;
  final Color disabled;

  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  /// Top stop of the subtle screen background wash. The bottom stop is
  /// [background]; keeping only the top here is what makes the gradient a
  /// palette value rather than two.
  final Color backgroundGradientTop;

  bool get isDark => brightness == Brightness.dark;

  // ---- Light: the original brand palette, unchanged ----

  /// The warm cream/brown palette the app shipped with. These values are the
  /// brand (golden rule 3) and must not drift.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF8B5E3C),
    primaryDark: Color(0xFF5E3D26),
    primarySoft: Color(0xFFEDE3DA),
    primaryFaint: Color(0xFFF7F1EC),
    secondary: Color(0xFFD6A46D),
    background: Color(0xFFF6F2EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3EEE9),
    scrim: Color(0x66000000),
    textPrimary: Color(0xFF2E2E2E),
    textSecondary: Color(0xFF7A7A7A),
    textTertiary: Color(0xFFA6A6A6),
    textDisabled: Color(0xFFB5AFA9),
    onPrimary: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    borderSoft: Color(0xFFEFEAE5),
    disabled: Color(0xFFE6E1DC),
    success: Color(0xFF66BB6A),
    error: Color(0xFFE57373),
    warning: Color(0xFFE0A44A),
    info: Color(0xFF6B93C0),
    backgroundGradientTop: Color(0xFFFBF8F5),
  );

  // ---- Dark: the same brand, re-lit ----

  /// The dark palette.
  ///
  /// This is not an inversion. Inverting cream gives a cold blue-grey that
  /// reads as a different product, so the neutrals here are warm — brown-tinted
  /// charcoals that keep CookMate's identity with the lights off.
  ///
  /// Decisions worth knowing before editing:
  ///
  /// - **Primary is lightened** from `#8B5E3C` to `#C89468`. The brand brown is
  ///   too dark to sit on a dark surface: as a button fill it disappears, and
  ///   as text it fails contrast outright. This is the same hue with the
  ///   lightness raised, so it still reads as the brand.
  /// - **`onPrimary` flips to near-black.** White text on the lightened primary
  ///   is barely legible; dark text on it clears AA comfortably.
  /// - **Surfaces get lighter as they get closer to the user**, the Material
  ///   dark convention: background `#17120F` → surface `#211A16` → surfaceAlt
  ///   `#2B221C`. In light mode the relationship is inverted (white cards on
  ///   cream). Elevation is carried by colour here, not by shadow — shadows are
  ///   nearly invisible on dark.
  /// - **Text tops out at `#F2EBE4`, not pure white.** Full white on near-black
  ///   vibrates and is fatiguing to read.
  /// - **The status colours are lightened** for the same contrast reason as the
  ///   primary; the light-mode reds and greens are too dark to read here.
  /// - **The scrim is heavier** (`0x99` vs `0x66`) because a light scrim over a
  ///   photo does almost nothing against a dark page.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFC89468),
    primaryDark: Color(0xFFA5764B),
    primarySoft: Color(0xFF3A2E25),
    primaryFaint: Color(0xFF2A211B),
    secondary: Color(0xFFE0B584),
    background: Color(0xFF17120F),
    surface: Color(0xFF211A16),
    surfaceAlt: Color(0xFF2B221C),
    scrim: Color(0x99000000),
    textPrimary: Color(0xFFF2EBE4),
    textSecondary: Color(0xFFB3A79C),
    textTertiary: Color(0xFF8A7E74),
    textDisabled: Color(0xFF6B615A),
    onPrimary: Color(0xFF241A12),
    border: Color(0xFF3C322B),
    borderSoft: Color(0xFF2F2620),
    disabled: Color(0xFF352C26),
    success: Color(0xFF7FD183),
    error: Color(0xFFF08A8A),
    warning: Color(0xFFEDB55F),
    info: Color(0xFF8AAFD6),
    backgroundGradientTop: Color(0xFF1E1712),
  );

  /// The palette [AppColors] currently resolves against.
  ///
  /// Defaults to [light] so anything constructed before a theme is chosen —
  /// unit tests, the first frame — behaves exactly as it did before dark mode
  /// existed.
  static AppPalette current = light;

  /// Points the app at [palette]. Callers are responsible for triggering a
  /// rebuild; [ThemeController] does this.
  static void apply(AppPalette palette) => current = palette;

  /// Restores the default light palette. Tests that switch to dark **must**
  /// call this in `tearDown`, or the global leaks into every test that follows.
  static void reset() => current = light;
}
