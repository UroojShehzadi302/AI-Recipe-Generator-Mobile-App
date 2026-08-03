import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A centered error state with an optional retry action.
///
/// Use this to surface failed loads (network errors, generation failures) in a
/// consistent, on-brand way instead of raw error strings.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Human-readable description of what went wrong.
  final String message;

  /// Optional callback; when provided a "Retry" button is shown.
  final VoidCallback? onRetry;

  /// Leading icon for the error. Defaults to [Icons.error_outline].
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spaceL),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceXl),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDimensions.brMd,
                  ),
                ),
                child: Text('Retry', style: AppTextStyles.button),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
