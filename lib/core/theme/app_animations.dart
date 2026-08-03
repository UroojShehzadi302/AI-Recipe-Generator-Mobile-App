import 'package:flutter/material.dart';

import 'app_durations.dart';

/// Motion curves and reusable animation helpers for CookMate AI.
///
/// Pairs with [AppDurations] (the "how long") to define the "how it moves".
/// Keeping curves here stops screens from each picking a different easing,
/// which is what makes an app feel inconsistent even when nothing is visibly
/// wrong.
class AppAnimations {
  AppAnimations._();

  /// Default easing for entrances — decelerates into place.
  static const Curve enter = Curves.easeOutCubic;

  /// Default easing for exits — accelerates away.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric easing for state changes that are neither entering nor exiting.
  static const Curve standard = Curves.easeInOut;

  /// Springy overshoot for playful emphasis (selected nav indicator, badges).
  static const Curve emphasized = Curves.easeOutBack;

  /// Distance a card/section travels while fading in.
  static const double slideOffset = 16;

  /// Computes a staggered start delay for item [index], capped so long lists
  /// don't take forever to fully appear.
  static Duration staggerFor(int index) {
    final int ms = AppDurations.stagger.inMilliseconds * index;
    final int capped = ms.clamp(0, AppDurations.staggerCap.inMilliseconds);
    return Duration(milliseconds: capped);
  }
}

/// Fades and slides its [child] up into place once, on first build.
///
/// Used for screen sections and list/grid items so content arrives with a
/// gentle sense of motion instead of snapping in. [delay] staggers siblings —
/// pass [AppAnimations.staggerFor] with the item index.
///
/// Deliberately cheap: a single [AnimationController] driving one
/// [FadeTransition] + one [SlideTransition], and it does not rebuild after
/// completing. Safe to use inside `ListView.builder`.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.long,
    this.offset = AppAnimations.slideOffset,
    this.enabled = true,
  });

  final Widget child;

  /// Wait this long before starting (use for staggered lists).
  final Duration delay;

  final Duration duration;

  /// Vertical distance travelled, in logical pixels.
  final double offset;

  /// When false the child is rendered directly with no animation — lets
  /// callers disable motion (e.g. for tests or reduced-motion) at one place.
  final bool enabled;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppAnimations.enter,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // Guarded by `mounted` because the delay can outlive the widget when the
      // user scrolls a staggered item out of the tree before it starts.
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _fade.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Wraps [child] so it scales down slightly while pressed.
///
/// Gives every tappable surface (cards, tiles, icon buttons) the same tactile
/// response. Use for custom surfaces; real [ElevatedButton]s already have
/// Material's ripple, and [PressableScale] composes with it rather than
/// replacing it.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.94,
    this.enabled = true,
    this.confirmBeforeTap = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale factor at full press.
  final double scale;

  final bool enabled;

  /// Hold the press briefly and let the rebound play BEFORE firing [onTap].
  ///
  /// Turn this on for surfaces whose tap navigates away (recipe cards): the
  /// route push otherwise starts on the same frame and the press animation is
  /// never actually seen. Leave it off for in-place toggles like chips, where
  /// the extra ~240ms just reads as lag.
  final bool confirmBeforeTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  /// Guards against a second tap while the confirm cycle is playing.
  bool _busy = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool value) {
    if (!_active || _pressed == value) return;
    setState(() => _pressed = value);
  }

  /// Plays a visible press-in → pop-back, THEN fires [PressableScale.onTap].
  ///
  /// Releasing on `onTapUp` and navigating immediately (the obvious approach)
  /// makes the animation invisible: the route push starts on the same frame,
  /// so the scale never gets to play. Holding the pressed state for a beat and
  /// running the callback after the rebound is what makes a tap actually feel
  /// like a tap.
  Future<void> _handleTap() async {
    if (!_active || _busy) return;

    if (!widget.confirmBeforeTap) {
      _set(false);
      widget.onTap?.call();
      return;
    }

    _busy = true;

    // Ensure the press-in is on screen even for a very fast tap.
    if (!_pressed) _set(true);
    await Future<void>.delayed(AppDurations.fast);
    if (!mounted) return;

    // Rebound, then hand off.
    _set(false);
    await Future<void>.delayed(AppDurations.fast);
    if (!mounted) return;

    _busy = false;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppDurations.fast,
        // easeOutBack overshoots slightly on release, so the surface "pops"
        // back rather than merely returning to rest.
        curve: _pressed ? AppAnimations.standard : AppAnimations.emphasized,
        child: widget.child,
      ),
    );
  }
}
