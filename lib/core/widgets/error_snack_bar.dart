// Error presentation that survives a diagnostic message.
//
// The default `SnackBar(content: Text(msg))` clips to a single line and
// ellipsises the rest, which silently destroys exactly the part worth reading:
// `ErrorMapper.withDetail` puts the provider's raw text on a second line.
//
// ⚠️ Raising maxLines is NOT enough, and shipping that was a real mistake: a
// floating SnackBar is also bounded by its own width and the screen, so on a
// 2026-08-17 device build the message still cut off mid-sentence at
// "...Android client application co..." — losing the package name, which is
// the identifying half of the string. Anything long now opens a dialog that
// scrolls and can be copied.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Shows [message] to the user, choosing a container that can hold it.
///
/// A short message gets an ordinary error SnackBar. A message carrying a
/// `Details:` line (see `ErrorMapper.withDetail`) opens a dialog instead: it
/// scrolls, it stays until dismissed, and it offers **Copy** so the user can
/// paste the exact text into a bug report. That last part is the whole point —
/// a truncated error in a screenshot is worth nothing.
void showErrorSnackBar(
  BuildContext context,
  String message, {
  int maxLines = 4,
}) {
  // Detail messages arrive as "friendly\n\nDetails: raw", so a newline is the
  // signal that there is more here than a glanceable sentence.
  if (message.contains('\n')) {
    _showErrorDetailDialog(context, message);
    return;
  }

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
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
}

/// The long-message form: scrollable, dismissible only by choice, copyable.
///
/// Split at the first blank line so the friendly sentence reads as the headline
/// and the provider's raw text sits below it in a monospace block — visibly
/// "technical detail" rather than something the user is expected to act on.
void _showErrorDetailDialog(BuildContext context, String message) {
  final int split = message.indexOf('\n\n');
  final String headline =
      split == -1 ? message : message.substring(0, split).trim();
  final String detail =
      split == -1 ? '' : message.substring(split).trim();

  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: AppColors.error,
        size: AppDimensions.iconLg,
      ),
      title: Text(
        headline,
        style: AppTextStyles.cardTitle.copyWith(color: AppColors.textPrimary),
      ),
      content: detail.isEmpty
          ? null
          : SingleChildScrollView(
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(AppDimensions.spaceM),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: SelectableText(
                  detail,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        if (detail.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Error details copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
            },
            icon: Icon(
              Icons.copy_rounded,
              size: AppDimensions.iconSm,
              color: AppColors.primary,
            ),
            label: Text(
              'Copy',
              style: AppTextStyles.button.copyWith(color: AppColors.primary),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            'Dismiss',
            style: AppTextStyles.button.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}
