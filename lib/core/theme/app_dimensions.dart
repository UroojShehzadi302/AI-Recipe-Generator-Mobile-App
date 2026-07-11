import 'package:flutter/material.dart';

/// Spacing, sizing, and radius scale for the AI Recipe Generator.
///
/// Every gap, padding, and corner radius should come from here so the layout
/// rhythm stays consistent. This replaces the ad-hoc magic numbers (7 different
/// border radii were in use before this system existed).
class AppDimensions {
  AppDimensions._();

  // ---- Spacing scale ----
  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXl = 22;
  static const double spaceXxl = 30;

  // ---- Corner radii ----
  static const double radiusSm = 12;
  static const double radiusMd = 16; // default for buttons & fields
  static const double radiusLg = 20;
  static const double radiusXl = 25; // large cards (e.g. login card)

  // ---- Component sizing ----
  static const double buttonHeight = 55;
  static const double socialButtonHeight = 52;
  static const double fieldContentPadding = 18;
  static const double logoHeight = 80;

  // ---- Convenience getters ----
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);
  static BorderRadius get brXl => BorderRadius.circular(radiusXl);

  /// Max content width so forms/cards don't stretch full-width on tablets.
  static const double maxContentWidth = 600;
}
