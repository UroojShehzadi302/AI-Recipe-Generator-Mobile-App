import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Branded text input reproducing the legacy `CustomTextField` look.
///
/// Filled white field with a warm-brown prefix icon, floating label, rounded
/// 16px borders, and (for passwords) a visibility toggle. Extends the original
/// with validation, change, focus, and input-action wiring so it can be used in
/// forms across the app.
class AppTextField extends StatefulWidget {
  /// Controls the text being edited.
  final TextEditingController controller;

  /// Field label (also used as the floating label).
  final String label;

  /// Leading icon shown in the brand primary color.
  final IconData icon;

  /// When true, obscures text and shows a visibility toggle.
  final bool isPassword;

  /// Keyboard type for the field.
  final TextInputType keyboardType;

  /// Optional validator used inside a [Form].
  final String? Function(String?)? validator;

  /// Called whenever the text changes.
  final void Function(String)? onChanged;

  /// Keyboard action button behavior (e.g. next / done).
  final TextInputAction? textInputAction;

  /// Optional focus node for controlling/observing focus.
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      obscureText: widget.isPassword ? _obscureText : false,
      cursorColor: AppColors.primary,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        alignLabelWithHint: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.fieldContentPadding,
          vertical: AppDimensions.fieldContentPadding,
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(widget.icon, color: AppColors.primary, size: 22),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
              )
            : null,
        labelStyle: const TextStyle(fontSize: 15, color: Colors.grey),
        floatingLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
