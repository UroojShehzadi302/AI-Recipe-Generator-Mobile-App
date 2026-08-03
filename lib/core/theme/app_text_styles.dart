import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for CookMate AI.
///
/// **Two families, split by job.** Headings and brand moments are set in
/// **Fraunces** — a warm old-style serif that gives the app a cookbook /
/// food-magazine voice — while everything the user actually reads (body copy,
/// recipe steps, metadata, buttons, form labels) is set in **Inter**, which is
/// engineered for small sizes on screen.
///
/// That split is the whole point: a display serif carries personality at 18px+
/// and becomes hard work at 11px, so it is never used below [cardTitle].
///
/// The scale is deliberately compact — the original was oversized:
///
/// | Token          | Size | Family   | Use                              |
/// |----------------|------|----------|----------------------------------|
/// | [display]      | 28   | Fraunces | Splash / hero brand moments      |
/// | [screenTitle]  | 22   | Fraunces | The one big title on a page      |
/// | [sectionTitle] | 18   | Fraunces | Rail / group headers             |
/// | [cardTitle]    | 16   | Inter    | Card + list-row titles           |
/// | [body]         | 14   | Inter    | Default running text             |
/// | [caption]      | 12   | Inter    | Supporting/secondary text        |
/// | [label]        | 11   | Inter    | Chips, nav labels, badges        |
///
/// Screens must use these instead of hardcoding `fontSize:` or a family name.
/// Need a variation? Use `.copyWith(...)` on the nearest token so the family
/// and color stay consistent.
///
/// NOTE: both families are bundled under `assets/fonts/` (declared in
/// `pubspec.yaml`) — no `google_fonts` runtime network fetch, so typography is
/// correct offline and at first paint. Fraunces is a variable font, so Flutter
/// maps `fontWeight` onto its `wght` axis rather than swapping files.
class AppTextStyles {
  AppTextStyles._();

  /// Display/heading family — the serif that carries the brand's character.
  static const String displayFamily = 'Fraunces';

  /// UI/body family — used for everything meant to be read, not admired.
  static const String fontFamily = 'Inter';

  // ---- Display scale (Fraunces) ----

  /// 28 · Hero brand text (splash, the single largest thing on a screen).
  static const TextStyle display = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  /// 22 · The primary title of a screen ("Profile", "Saved Recipes").
  static const TextStyle screenTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// 18 · Section / rail headers within a screen.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  // ---- UI scale (Inter) ----

  /// 16 · Card titles and list-row labels.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  /// 14 · Default running text.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// 14 · Body weight-up, for emphasis inside paragraphs.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// 12 · Supporting / secondary text.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// 11 · Chips, nav labels, badges, metadata.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// 14 · Button label. Sits on a filled brand surface, so it defaults white.
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  // ---- Semantic aliases ----
  //
  // Kept so the many existing call sites (and their intent) stay readable.
  // `subtitle` is the muted variant of body, `title` maps to the section
  // header, and `heading` to the screen title.

  /// Muted supporting text under a heading (14, secondary color).
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Alias of [sectionTitle] — kept for existing call sites.
  static const TextStyle title = sectionTitle;

  /// Alias of [screenTitle] — kept for existing call sites.
  static const TextStyle heading = screenTitle;
}
