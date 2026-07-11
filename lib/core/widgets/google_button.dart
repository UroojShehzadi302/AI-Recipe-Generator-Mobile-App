import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_strings.dart';
import '../theme/app_dimensions.dart';

/// "Continue with Google" social sign-in button.
///
/// Full-width, 52px-tall white [OutlinedButton] with a light grey border,
/// 16px corners, and a centered Google icon + label. Falls back to a generic
/// login icon if the Google asset is missing so the UI never crashes.
class GoogleButton extends StatelessWidget {
  /// Tap callback. Pass `null` to render a disabled button.
  final VoidCallback? onPressed;

  /// Button label. Defaults to [AppStrings.continueWithGoogle].
  final String label;

  const GoogleButton({
    super.key,
    required this.onPressed,
    this.label = AppStrings.continueWithGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.socialButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.brMd,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.googleIcon,
              width: 22,
              height: 22,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.login, size: 22, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
