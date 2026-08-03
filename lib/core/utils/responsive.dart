import 'package:flutter/material.dart';

/// Screen-size breakpoints for responsive layout decisions.
///
/// Width-based (the app is portrait-first): below [tablet] is a phone, and
/// [tablet]/[desktop] progressively widen grids and spacing so the UI scales
/// gracefully on large phones, foldables, and tablets instead of stretching a
/// fixed 2-column phone layout.
class AppBreakpoints {
  AppBreakpoints._();

  /// At/above this logical width the layout is treated as a tablet.
  static const double tablet = 600;

  /// At/above this logical width the layout is treated as a large tablet/desktop.
  static const double desktop = 1024;
}

/// Responsive convenience helpers on [BuildContext].
///
/// Centralizes every size-class decision so screens read like
/// `context.recipeGridColumns` instead of scattering `MediaQuery`/magic numbers.
/// All values still flow from the design rhythm (multiples of the spacing scale).
extension ResponsiveContext on BuildContext {
  /// Current screen width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Current screen height in logical pixels.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True at/above the tablet breakpoint.
  bool get isTablet => screenWidth >= AppBreakpoints.tablet;

  /// True at/above the desktop breakpoint.
  bool get isDesktop => screenWidth >= AppBreakpoints.desktop;

  /// Picks a value for the current size class. [tablet]/[desktop] fall back to
  /// the next-smaller provided value, so only [mobile] is required.
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Column count for recipe grids (Favorites, Saved, Search, Categories).
  int get recipeGridColumns => responsive(mobile: 2, tablet: 3, desktop: 4);

  /// Horizontal page padding that grows a little on wider screens.
  double get pagePadding => responsive<double>(mobile: 20, tablet: 32, desktop: 48);

  /// Width of a single card in a horizontal rail.
  double get railCardWidth =>
      responsive<double>(mobile: 172, tablet: 200, desktop: 220);

  /// Height of a horizontal recipe rail (tracks the card width + text block).
  double get railHeight =>
      responsive<double>(mobile: 212, tablet: 240, desktop: 252);
}
