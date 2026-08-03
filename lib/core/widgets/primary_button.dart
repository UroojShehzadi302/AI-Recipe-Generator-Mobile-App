import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// Visual variants of [PrimaryButton].
enum ButtonVariant {
  /// Filled with the brand gradient — the main call to action on a screen.
  primary,

  /// White surface with a brand-tinted border — secondary actions.
  outlined,

  /// Filled with the error color — destructive confirmations.
  danger,
}

/// The app's call-to-action button.
///
/// One button covering every state the UI needs, so screens never hand-roll a
/// container-with-a-gesture again:
///
/// * **Press** — scales down slightly ([PressableScale]) *and* keeps Material's
///   ripple, so it responds both to the eye and to the finger.
/// * **Loading** — swaps the label for a spinner and blocks taps. The button
///   keeps its exact size, so the layout never jumps mid-submit.
/// * **Disabled** — a flat grey surface with no shadow; unmistakably inert
///   rather than just dimmed.
///
/// [expand] controls whether it fills its parent (default) or hugs its label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.height = AppDimensions.buttonHeight,
  });

  /// Label shown on the button when it is not loading.
  final String text;

  /// Tap callback. Pass `null` to render a disabled button.
  final VoidCallback? onPressed;

  /// When true, shows a spinner instead of [text] and blocks taps.
  final bool isLoading;

  /// Visual treatment — see [ButtonVariant].
  final ButtonVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  /// When true (default) the button stretches to its parent's width.
  final bool expand;

  /// Button height; defaults to [AppDimensions.buttonHeight].
  final double height;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final bool outlined = variant == ButtonVariant.outlined;

    // Foreground stays readable in every state: brand color on the outlined
    // variant, white on the filled ones, muted grey when disabled.
    final Color foreground = !_enabled
        ? AppColors.textDisabled
        : outlined
            ? AppColors.primary
            : AppColors.onPrimary;

    return PressableScale(
      onTap: _enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppAnimations.standard,
        width: expand ? double.infinity : null,
        height: height,
        decoration: BoxDecoration(
          gradient: _enabled && variant == ButtonVariant.primary
              ? AppColors.brandGradient
              : null,
          color: _background,
          borderRadius: AppDimensions.brMd,
          border: outlined
              ? Border.all(
                  color: _enabled ? AppColors.primary : AppColors.border,
                  width: 1.4,
                )
              : null,
          boxShadow: _enabled && !outlined
              ? AppShadows.glow(
                  variant == ButtonVariant.danger
                      ? AppColors.error
                      : AppColors.primary,
                  alpha: 0.28,
                )
              : AppShadows.none,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: AppDimensions.brMd,
            splashColor: foreground.withValues(alpha: 0.12),
            highlightColor: foreground.withValues(alpha: 0.06),
            child: Center(
              // Cross-fade between the label and the spinner so a submit
              // doesn't flicker.
              child: AnimatedSwitcher(
                duration: AppDurations.short,
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey<String>('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(foreground),
                        ),
                      )
                    : Row(
                        key: const ValueKey<String>('label'),
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...<Widget>[
                            Icon(icon, size: AppDimensions.iconMd,
                                color: foreground),
                            const SizedBox(width: AppDimensions.spaceS),
                          ],
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.button
                                  .copyWith(color: foreground),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Solid fill for the variants that don't use the brand gradient.
  Color? get _background {
    if (!_enabled) return AppColors.disabled;
    switch (variant) {
      case ButtonVariant.primary:
        return null; // gradient supplies the fill
      case ButtonVariant.outlined:
        return AppColors.surface;
      case ButtonVariant.danger:
        return AppColors.error;
    }
  }
}
