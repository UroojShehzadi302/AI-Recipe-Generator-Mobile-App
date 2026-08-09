import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

/// Password-reset request screen.
///
/// Collects the user's email and asks [AuthProvider.sendPasswordReset] to email
/// them a reset link. Matches the warm brown/cream Login/Register design
/// language, capping content width and staying scrollable so the keyboard never
/// causes an overflow. On success it pops back to Login; on failure it surfaces
/// the provider's error message in a SnackBar.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  /// Drives the button spinner and disables it while a request is in flight.
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);

    final auth = context.read<AuthProvider>();
    await auth.sendPasswordReset(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _sending = false);

    final error = auth.errorMessage;
    if (error != null) {
      _showSnackBar(error);
      auth.clearError();
      return;
    }

    _showSnackBar('Password reset link sent to your email.');
    Navigator.pop(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: AppDimensions.spaceXl,
              right: AppDimensions.spaceXl,
              top: AppDimensions.spaceL,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppDimensions.spaceXl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_reset,
                    size: AppDimensions.logoHeight,
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: AppDimensions.spaceL),

                  Text(
                    'Reset Password',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),

                  const SizedBox(height: AppDimensions.spaceS),

                  Text(
                    "Enter your email and we'll send you a reset link.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),

                  const SizedBox(height: AppDimensions.spaceXl),

                  Card(
                    elevation: 5,
                    shadowColor: Colors.black12,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDimensions.brXl,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceL,
                        vertical: AppDimensions.spaceXl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              validator: Validators.email,
                            ),

                            const SizedBox(height: AppDimensions.spaceL),

                            PrimaryButton(
                              text: 'SEND RESET LINK',
                              isLoading: _sending,
                              onPressed: _sending ? null : _sendResetLink,
                            ),
                          ],
                        ),
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
