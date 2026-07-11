import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A centered loading spinner in the brand color with an optional message.
///
/// Use this while awaiting async data (recipe generation, network calls) to keep
/// loading states visually consistent across the app.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size,
  });

  /// Optional supporting text shown beneath the spinner.
  final String? message;

  /// Optional diameter for the spinner. Defaults to the framework size.
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppDimensions.spaceL),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ],
      ),
    );
  }
}
