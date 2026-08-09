import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_strings.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// "Continue with Google" social sign-in button.
///
/// A full-width white surface with a hairline border and the Google mark —
/// deliberately quieter than [PrimaryButton] so the primary action stays the
/// visual anchor. Shares the same press-scale feedback as every other tappable
/// surface in the app.
///
/// Falls back to a generic login icon if the Google asset is missing so the UI
/// never crashes.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.label = AppStrings.continueWithGoogle,
    this.isLoading = false,
  });

  /// Tap callback. Pass `null` to render a disabled button.
  final VoidCallback? onPressed;

  /// Button label. Defaults to [AppStrings.continueWithGoogle].
  final String label;

  /// Shows a spinner and blocks taps while the Google flow is in flight.
  final bool isLoading;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: _enabled ? onPressed : null,
      child: Container(
        width: double.infinity,
        height: AppDimensions.socialButtonHeight,
        decoration: BoxDecoration(
          color: _enabled ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: AppDimensions.brMd,
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: _enabled ? AppShadows.subtle : AppShadows.none,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: AppDimensions.brMd,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          AppAssets.googleIcon,
                          width: 20,
                          height: 20,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.login_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceM),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.button.copyWith(
                              color: _enabled
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
