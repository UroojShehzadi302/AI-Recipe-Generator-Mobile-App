import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// The app's About dialog — brand mark, tagline, one-line description, version.
///
/// Extracted here (rather than duplicated) because both Profile and Settings
/// offer an "About" entry and they must not drift apart. Deliberately NOT the
/// framework's [showAboutDialog]: that one ships a "View licenses" button and
/// an unbranded layout.
Future<void> showAppAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.onPrimary,
              size: AppDimensions.iconMd,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          const Expanded(child: Text(AppStrings.appName)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.tagline, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppDimensions.spaceS),
          Text(AppStrings.aboutBody, style: AppTextStyles.subtitle),
          const SizedBox(height: AppDimensions.spaceM),
          Text('Version $kAppVersion', style: AppTextStyles.caption),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(AppStrings.close),
        ),
      ],
    ),
  );
}

/// The app version shown in the About dialog and the Profile footer.
///
/// Must match `version:` in `pubspec.yaml`. Lives beside the dialog so the two
/// places that display it read one constant.
const String kAppVersion = '1.0.0';
