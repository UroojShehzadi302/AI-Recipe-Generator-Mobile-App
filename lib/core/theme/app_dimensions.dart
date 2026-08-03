import 'package:flutter/material.dart';

/// Spacing, sizing, and radius scale for CookMate AI.
///
/// Every gap, padding, and corner radius should come from here so the layout
/// rhythm stays consistent. This replaces the ad-hoc magic numbers (7 different
/// border radii were in use before this system existed).
///
/// The spacing scale is a strict 4pt grid — pick the nearest token rather than
/// inventing a value.
class AppDimensions {
  AppDimensions._();

  // ---- Spacing scale (4pt grid) ----
  static const double space2 = 2;
  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 28;
  static const double spaceHuge = 40;

  // ---- Corner radii ----
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16; // default for buttons & fields
  static const double radiusLg = 20;
  static const double radiusXl = 24; // large cards & sheets
  static const double radiusPill = 999;

  // ---- Component sizing ----
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 42;
  static const double socialButtonHeight = 50;
  static const double fieldContentPadding = 16;
  static const double logoHeight = 80;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  /// Height of the floating bottom navigation bar (excluding its outer margin).
  static const double navBarHeight = 64;

  /// Outer margin around the floating navigation bar.
  static const double navBarMargin = 12;

  /// Bottom padding scrollable content needs so the last item clears the
  /// floating nav bar entirely.
  ///
  /// Use this for SCROLLABLES (lists, grids, scroll views) inside a tab.
  static const double navBarClearance =
      navBarHeight + navBarMargin * 2 + spaceS;

  /// Space a bottom-pinned surface (e.g. the chat composer) must leave under
  /// its content so the floating nav bar can sit on top of it.
  ///
  /// Smaller than [navBarClearance] on purpose: such a surface paints all the
  /// way to the screen bottom — so it only has to clear the bar's own height
  /// and margin, not add a further gap beneath it. Using the full clearance
  /// here pushes the content visibly too high.
  static const double navBarOverlap = navBarHeight + navBarMargin;

  // ---- Convenience getters ----
  static BorderRadius get brXs => BorderRadius.circular(radiusXs);
  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);
  static BorderRadius get brXl => BorderRadius.circular(radiusXl);
  static BorderRadius get brPill => BorderRadius.circular(radiusPill);

  // ---- Common paddings ----

  /// Standard leading padding for a screen header row.
  static const EdgeInsets screenHeader =
      EdgeInsets.fromLTRB(spaceXl, spaceL, spaceXl, 0);

  /// Bottom padding for a scrollable list inside a tab (clears the nav bar).
  static const EdgeInsets listBottom =
      EdgeInsets.only(bottom: navBarClearance);

  /// Max content width so forms/cards don't stretch full-width on tablets.
  static const double maxContentWidth = 600;
}
