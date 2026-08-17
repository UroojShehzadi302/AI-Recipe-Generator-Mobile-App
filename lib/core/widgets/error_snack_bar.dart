// A SnackBar that can actually show a diagnostic message.
//
// The default `SnackBar(content: Text(msg))` clips to a single line and
// ellipsises the rest, which silently destroys exactly the part worth reading:
// `ErrorMapper.withDetail` puts the provider's raw text on a second line, so a
// one-line box shows the friendly sentence and eats the evidence.
//
// This also gives every auth screen the same error affordance instead of four
// near-identical private `_showError` helpers.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Shows [message] in a SnackBar sized to fit it.
///
/// Multi-line messages (see `ErrorMapper.withDetail`) are shown in full up to
/// [maxLines], and get a longer display duration because there is more to read.
/// A short message keeps the ordinary brief SnackBar.
///
/// Replaces any SnackBar already on screen, so a rapid second failure does not
/// queue behind the first.
void showErrorSnackBar(
  BuildContext context,
  String message, {
  int maxLines = 8,
}) {
  // Detail messages arrive as "friendly\n\nDetails: raw", so a newline is the
  // signal that there is more than a glanceable sentence here.
  final bool isDetailed = message.contains('\n');

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppDimensions.spaceL),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        duration: isDetailed
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
        // A long error is worth re-reading; without this it vanishes mid-read
        // and the user has to reproduce the failure to see it again.
        action: isDetailed
            ? SnackBarAction(
                label: 'Dismiss',
                textColor: AppColors.onPrimary,
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              )
            : null,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
}
