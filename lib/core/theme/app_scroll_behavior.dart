import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// App-wide scroll behavior for CookMate AI.
///
/// Applied once on the [MaterialApp] so **every** scrollable in the app gets
/// the same premium feel, instead of 20-plus widgets each setting `physics:`
/// (and inevitably disagreeing). Two deliberate choices:
///
/// * [BouncingScrollPhysics] everywhere — the iOS-style rubber-band overscroll
///   reads as smooth and high-quality, and it removes Android's hard stop and
///   its glow. `parent: AlwaysScrollableScrollPhysics()` keeps short lists
///   draggable, which is what pull-to-refresh needs to fire.
/// * A stretch overscroll indicator instead of the default glow, matching the
///   bounce rather than fighting it.
///
/// Individual widgets can still override `physics:` — nested scrollables that
/// need [NeverScrollableScrollPhysics] must keep setting it explicitly.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  /// Also allow dragging with a mouse/trackpad, which makes the app feel
  /// correct when run on a tablet with a pointer or on desktop.
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
