import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../constants/app_strings.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_text_styles.dart';

/// A slim strip telling the user the app has lost its connection.
///
/// ## Deliberately non-intrusive
///
/// It is a single line of text, it blocks nothing, and it dismisses itself the
/// moment a request succeeds. Being offline in this app is a *degradation*, not
/// a dead end — the desi Home rail, favorites and saved recipes are all local
/// or cached, so a modal or a full-screen error would take away more than the
/// outage does.
///
/// ## It only appears on CONFIRMED evidence
///
/// It watches [ConnectivityProvider.isOffline], which is true only for
/// [ConnectivityStatus.offline] — a real failed request that a probe then
/// agreed with. A single unexplained failure leaves the provider in `unknown`
/// and this renders nothing. Showing an offline banner to somebody whose
/// network is fine is a worse bug than showing none at all.
///
/// ## Theming
///
/// Warning-toned rather than error-toned: no connection is a temporary
/// condition, not a failure the user caused. All colours resolve through
/// [AppColors], so it follows a light/dark switch with no per-theme branching.
class OfflineBanner extends StatelessWidget {
  /// Creates an offline banner.
  const OfflineBanner({super.key});

  /// Height reserved when the banner is showing. Exposed so a caller that pins
  /// content beneath it can reserve the same space.
  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    // `select` rather than `watch`: this rebuilds on the offline flag flipping
    // and on nothing else, so a connectivity provider that gains more state
    // later cannot start rebuilding the banner for unrelated reasons.
    final bool isOffline =
        context.select<ConnectivityProvider, bool>((p) => p.isOffline);

    // AnimatedSize + AnimatedSwitcher rather than a raw `if`: the strip grows
    // and fades instead of snapping in, which stops it from reading as a layout
    // glitch when it appears mid-scroll.
    return AnimatedSize(
      duration: AppDurations.short,
      curve: AppAnimations.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDurations.short,
        switchInCurve: AppAnimations.enter,
        switchOutCurve: AppAnimations.exit,
        child: isOffline
            ? const _OfflineStrip()
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// The visible strip itself, split out so [AnimatedSwitcher] has a stable
/// child identity to cross-fade between.
class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    // The status-bar inset is applied HERE, on the visible strip, rather than
    // by a SafeArea around the whole banner. Wrapping the banner meant the
    // padding was added even when it had collapsed to zero height, leaving an
    // empty strip across the top of every screen while online. Paying the inset
    // only while the strip is showing keeps the online case free.
    final double topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      height: OfflineBanner.height + topInset,
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        top: topInset,
        left: AppDimensions.spaceL,
        right: AppDimensions.spaceL,
      ),
      // A tinted wash rather than a solid warning fill: solid amber across the
      // full width would out-shout the content it sits above.
      color: AppColors.warning.withValues(alpha: 0.16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: AppDimensions.iconSm,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppDimensions.spaceS),
          Flexible(
            child: Text(
              AppStrings.offlineBanner,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                // Body text colour, not the warning colour: the icon carries
                // the status and amber text on an amber wash is hard to read.
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
