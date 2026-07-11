/// Animation and timing constants for the AI Recipe Generator.
///
/// Centralizing durations keeps motion consistent (button presses, page
/// transitions, loading, typing) and makes global tuning trivial.
class AppDurations {
  AppDurations._();

  /// Splash screen display time before navigating away.
  static const Duration splash = Duration(seconds: 2);

  /// Fast micro-interactions (button press, ripple).
  static const Duration short = Duration(milliseconds: 200);

  /// Standard transitions (fade, slide, card taps).
  static const Duration medium = Duration(milliseconds: 350);

  /// Longer emphasis animations.
  static const Duration long = Duration(milliseconds: 600);
}
