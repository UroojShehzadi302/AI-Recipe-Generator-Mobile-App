import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_durations.dart';
import '../theme/app_text_styles.dart';

/// Branded text input for CookMate AI.
///
/// A filled white [TextFormField] with a floating label, a leading icon that
/// tints as the field takes focus, and (for passwords) a visibility toggle.
///
/// Two details make it feel finished rather than default:
/// * the field tracks its own focus so the icon and label animate together
///   instead of only the border reacting;
/// * validation errors are rendered by the framework (so `Form` semantics and
///   screen readers keep working) but styled through the theme's `errorStyle`,
///   and wrap to two lines so a full sentence stays readable.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.autofillHints,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Controls the text being edited.
  final TextEditingController controller;

  /// Field label (also used as the floating label).
  final String label;

  /// Leading icon shown in the brand primary color.
  final IconData icon;

  /// Optional placeholder shown when the field is focused and empty.
  final String? hint;

  /// When true, obscures text and shows a visibility toggle.
  final bool isPassword;

  /// Keyboard type for the field.
  final TextInputType keyboardType;

  /// Optional validator used inside a [Form].
  final String? Function(String?)? validator;

  /// Called whenever the text changes.
  final void Function(String)? onChanged;

  /// Called when the user submits from the keyboard.
  final void Function(String)? onFieldSubmitted;

  /// Keyboard action button behavior (e.g. next / done).
  final TextInputAction? textInputAction;

  /// Optional focus node. When omitted the field creates and owns one.
  final FocusNode? focusNode;

  /// When false the field is greyed out and non-interactive.
  final bool enabled;

  /// Optional character cap (also renders the counter).
  final int? maxLength;

  /// Number of visible lines; > 1 turns this into a multiline field.
  final int maxLines;

  /// Autofill hints so password managers and the OS can help.
  final List<String>? autofillHints;

  /// Optional input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Capitalization behavior for the soft keyboard.
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;
  bool _focused = false;

  /// Only disposed when this widget created it — a caller-supplied node is the
  /// caller's to manage.
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final bool focused = _effectiveFocusNode.hasFocus;
    if (focused != _focused && mounted) {
      setState(() => _focused = focused);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = !widget.enabled
        ? AppColors.textDisabled
        : _focused
            ? AppColors.primary
            : AppColors.textSecondary;

    return TextFormField(
      controller: widget.controller,
      focusNode: _effectiveFocusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.isPassword && _obscureText,
      cursorColor: AppColors.primary,
      cursorWidth: 1.6,
      cursorRadius: const Radius.circular(2),
      style: AppTextStyles.body.copyWith(
        color: widget.enabled ? AppColors.textPrimary : AppColors.textDisabled,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        // The counter is noise on most fields; callers that set maxLength for
        // validation rarely want the "0/500" chrome.
        counterText: '',
        filled: true,
        fillColor: widget.enabled ? AppColors.surface : AppColors.surfaceAlt,
        prefixIcon: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppAnimations.standard,
          child: Icon(widget.icon, color: iconColor, size: 20),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscureText = !_obscureText),
                tooltip: _obscureText ? 'Show password' : 'Hide password',
                splashRadius: 20,
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              )
            : null,
        // Errors read as a message, not just a red line.
        errorMaxLines: 2,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 46,
          minHeight: 46,
        ),
      ),
    );
  }
}
