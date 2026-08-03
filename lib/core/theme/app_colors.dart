import 'package:flutter/material.dart';

/// Central color palette for CookMate AI.
///
/// Single source of truth for every color in the app. Screens and widgets must
/// reference these tokens instead of hardcoding `Color(0x...)` literals so the
/// warm brown branding stays consistent across the whole application.
class AppColors {
  AppColors._();

  // ---- Brand ----

  /// Brand primary — warm brown. Used for buttons, accents, active states.
  static const Color primary = Color(0xFF8B5E3C);

  /// Darker brown, used as the end stop of warm brand gradients.
  static const Color primaryDark = Color(0xFF5E3D26);

  /// Soft brown tint for subtle backgrounds (chips, section fills).
  static const Color primarySoft = Color(0xFFEDE3DA);

  /// The faintest brand wash — hover/selected rows, icon tiles on white.
  static const Color primaryFaint = Color(0xFFF7F1EC);

  /// Softer brown/tan accent for secondary emphasis.
  static const Color secondary = Color(0xFFD6A46D);

  // ---- Surfaces ----

  /// App background — brand cream. Standardized across every screen.
  static const Color background = Color(0xFFF6F2EE);

  /// Card / elevated surface color.
  static const Color surface = Color(0xFFFFFFFF);

  /// A recessed surface for wells, skeletons, and inset fields on white.
  static const Color surfaceAlt = Color(0xFFF3EEE9);

  /// Scrim behind modals and over images.
  static const Color scrim = Color(0x66000000);

  // ---- Text ----

  /// Primary text color.
  static const Color textPrimary = Color(0xFF2E2E2E);

  /// Secondary / supporting text color.
  static const Color textSecondary = Color(0xFF7A7A7A);

  /// Tertiary text — hints and placeholders. Lightest readable step.
  static const Color textTertiary = Color(0xFFA6A6A6);

  /// Text on a disabled control.
  static const Color textDisabled = Color(0xFFB5AFA9);

  /// Text/icons placed on top of the brand primary.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ---- Lines & states ----

  /// Neutral border color for inputs and dividers.
  static const Color border = Color(0xFFE0E0E0);

  /// A lighter hairline for dividers inside cards.
  static const Color borderSoft = Color(0xFFEFEAE5);

  /// Fill of a disabled control.
  static const Color disabled = Color(0xFFE6E1DC);

  /// Success state (soft green).
  static const Color success = Color(0xFF66BB6A);

  /// Error state (soft red).
  static const Color error = Color(0xFFE57373);

  /// Warning / attention state (warm amber, brand-adjacent).
  static const Color warning = Color(0xFFE0A44A);

  /// Informational state (muted blue, used sparingly).
  static const Color info = Color(0xFF6B93C0);

  // ---- Gradients ----

  /// The signature warm brand gradient (buttons, AI accents, splash).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, primaryDark],
  );

  /// Warm tan→brown gradient used for image placeholders.
  static const LinearGradient placeholderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[secondary, primary],
  );

  /// Very subtle top-down warmth for screen backgrounds.
  ///
  /// A flat fill over a whole screen reads as inert; this keeps the cream brand
  /// but gives the page a faint light source at the top. The stops are close
  /// enough together that it never looks like a "gradient background".
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFBF8F5), background],
    stops: <double>[0, 0.35],
  );

  /// Bottom-anchored scrim so text stays legible over a photo.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0x99000000)],
    stops: <double>[0.45, 1],
  );
}
