import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Central color palette for CookMate AI.
///
/// Single source of truth for every color in the app. Screens and widgets must
/// reference these tokens instead of hardcoding `Color(0x...)` literals so the
/// warm brown branding stays consistent across the whole application.
///
/// ## These are getters, not constants (changed for dark mode)
///
/// Each member resolves against [AppPalette.current], so the same
/// `AppColors.primary` call site returns the cream-palette brown in light mode
/// and the lightened brown in dark mode. Every existing call site kept working
/// unchanged through that switch — which is the entire reason it was done this
/// way rather than by threading `BuildContext` through ~390 references.
///
/// Two consequences:
///
/// - **They can no longer be used inside `const` expressions.** A handful of
///   `const Icon(... color: AppColors.x)` / `const BorderSide(...)` sites had
///   to drop their `const`. If you write a new one the analyzer will tell you
///   immediately; just remove the keyword.
/// - **Do not cache a colour in a field, a `late final`, or a top-level
///   constant.** It will hold the palette that was active when it was first
///   read and will not follow a theme switch. Read colours in `build()`.
///
/// The actual values live in [AppPalette.light] / [AppPalette.dark].
class AppColors {
  AppColors._();

  static AppPalette get _p => AppPalette.current;

  /// Whether the active palette is the dark one.
  ///
  /// For the rare case where a widget needs a genuinely different treatment per
  /// theme rather than a different colour — e.g. an overlay that must lighten
  /// on dark instead of darken. Prefer a token over branching on this.
  static bool get isDark => _p.isDark;

  // ---- Brand ----

  /// Brand primary — warm brown. Used for buttons, accents, active states.
  /// Lightened in dark mode so it stays legible on a dark surface.
  static Color get primary => _p.primary;

  /// Darker brown, used as the end stop of warm brand gradients.
  static Color get primaryDark => _p.primaryDark;

  /// Soft brown tint for subtle backgrounds (chips, section fills).
  static Color get primarySoft => _p.primarySoft;

  /// The faintest brand wash — hover/selected rows, icon tiles on white.
  static Color get primaryFaint => _p.primaryFaint;

  /// Softer brown/tan accent for secondary emphasis.
  static Color get secondary => _p.secondary;

  // ---- Surfaces ----

  /// App background — brand cream in light, warm near-black in dark.
  static Color get background => _p.background;

  /// Card / elevated surface color.
  static Color get surface => _p.surface;

  /// A recessed surface for wells, skeletons, and inset fields.
  ///
  /// Note this is *recessed* in light mode but sits **above** [surface] in
  /// dark, following the Material convention that closer surfaces are lighter.
  static Color get surfaceAlt => _p.surfaceAlt;

  /// Scrim behind modals and over images. Heavier in dark mode, where a light
  /// scrim would do almost nothing.
  static Color get scrim => _p.scrim;

  // ---- Text ----

  /// Primary text color.
  static Color get textPrimary => _p.textPrimary;

  /// Secondary / supporting text color.
  static Color get textSecondary => _p.textSecondary;

  /// Tertiary text — hints and placeholders. Lightest readable step.
  static Color get textTertiary => _p.textTertiary;

  /// Text on a disabled control.
  static Color get textDisabled => _p.textDisabled;

  /// Text/icons placed on top of the brand primary.
  ///
  /// White in light mode, near-black in dark — the lightened dark primary needs
  /// dark text on it to stay readable.
  static Color get onPrimary => _p.onPrimary;

  // ---- Lines & states ----

  /// Neutral border color for inputs and dividers.
  static Color get border => _p.border;

  /// A lighter hairline for dividers inside cards.
  static Color get borderSoft => _p.borderSoft;

  /// Fill of a disabled control.
  static Color get disabled => _p.disabled;

  /// Success state (soft green).
  static Color get success => _p.success;

  /// Error state (soft red).
  static Color get error => _p.error;

  /// Warning / attention state (warm amber, brand-adjacent).
  static Color get warning => _p.warning;

  /// Informational state (muted blue, used sparingly).
  static Color get info => _p.info;

  // ---- Gradients ----

  /// The signature warm brand gradient (buttons, AI accents, splash).
  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primary, primaryDark],
      );

  /// Warm tan→brown gradient used for image placeholders.
  static LinearGradient get placeholderGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[secondary, primary],
      );

  /// Very subtle top-down warmth for screen backgrounds.
  ///
  /// A flat fill over a whole screen reads as inert; this keeps the brand but
  /// gives the page a faint light source at the top. The stops are close
  /// enough together that it never looks like a "gradient background".
  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_p.backgroundGradientTop, background],
        stops: const <double>[0, 0.35],
      );

  /// Bottom-anchored scrim so text stays legible over a photo.
  ///
  /// Deliberately identical in both themes: it exists to darken a photograph,
  /// and photographs do not change with the app theme.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0x99000000)],
    stops: <double>[0.45, 1],
  );
}
