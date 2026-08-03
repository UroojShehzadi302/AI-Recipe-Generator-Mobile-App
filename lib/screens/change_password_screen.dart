import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

/// Change Password — re-authenticates with the current password, then sets a
/// new one.
///
/// The current password is asked for up front rather than reacting to
/// Firebase's `requires-recent-login`: the user is already in a "prove it's
/// you" frame of mind here, and failing halfway through to ask for the same
/// thing reads as a bug. All wiring goes through
/// [AuthProvider.changePassword] (Widget → Provider → Repository → Service).
///
/// Only reachable for password-backed accounts — a Google-only account has no
/// password to change, and Profile hides the entry point for them.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final bool ok = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      _toast('Password updated');
      return;
    }
    _toast(auth.errorMessage ?? 'Could not change your password.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Change Password', style: AppTextStyles.title),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  AppDimensions.spaceL,
                  context.pagePadding,
                  AppDimensions.spaceXxl,
                ),
                children: <Widget>[
                  Text(
                    'Enter your current password, then choose a new one. '
                    "You'll stay signed in on this device.",
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: AppDimensions.spaceXl),
                  AppTextField(
                    controller: _currentController,
                    label: 'Current password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Enter your current password' : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  AppTextField(
                    controller: _newController,
                    label: 'New password',
                    icon: Icons.lock_reset_outlined,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final String? base = Validators.password(value);
                      if (base != null) return base;
                      if ((value ?? '') == _currentController.text) {
                        return 'New password must differ from the current one';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  AppTextField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        Validators.confirmPassword(value, _newController.text),
                  ),
                  const SizedBox(height: AppDimensions.spaceXxl),
                  PrimaryButton(
                    text: _saving ? 'UPDATING…' : 'UPDATE PASSWORD',
                    onPressed: _saving ? null : _save,
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
