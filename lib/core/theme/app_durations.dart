/// Animation and timing constants for CookMate AI.
///
/// Centralizing durations keeps motion consistent (button presses, page
/// transitions, loading, typing) and makes global tuning trivial.
///
/// Motion philosophy: fast and subtle. Nothing the user has to wait for should
/// exceed [medium]; anything longer is decoration and gets cut.
class AppDurations {
  AppDurations._();

  /// Splash screen display time before navigating away.
  static const Duration splash = Duration(seconds: 2);

  /// Near-instant feedback (press states, ripples, tint changes).
  static const Duration fast = Duration(milliseconds: 120);

  /// Fast micro-interactions (icon swaps, small scale/fade).
  static const Duration short = Duration(milliseconds: 200);

  /// Standard transitions (fade, slide, card taps, tab indicator).
  static const Duration medium = Duration(milliseconds: 300);

  /// Longer emphasis animations (screen entrance, hero).
  static const Duration long = Duration(milliseconds: 450);

  /// Per-item delay when staggering a list/grid entrance.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Maximum cumulative stagger delay, so long lists don't crawl in.
  static const Duration staggerCap = Duration(milliseconds: 300);
}
