import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// The app's primary call-to-action button (warm-brown, filled).
///
/// Consolidates the look of the legacy `CustomButton`: a full-width, 55px-tall
/// [ElevatedButton] using the brand primary color, white foreground, soft
/// brown-tinted shadow, and a 16px corner radius.
///
/// When [isLoading] is true a small white [CircularProgressIndicator] replaces
/// the label and the button is disabled (ignores [onPressed]).
class PrimaryButton extends StatelessWidget {
  /// Label shown on the button when it is not loading.
  final String text;

  /// Tap callback. Pass `null` to render a disabled button.
  final VoidCallback? onPressed;

  /// When true, shows a spinner instead of [text] and disables the button.
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.brMd,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(text, style: AppTextStyles.button),
      ),
    );
  }
}
