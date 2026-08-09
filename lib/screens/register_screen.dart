import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/google_button.dart';
import '../core/widgets/or_divider.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

/// Account creation screen for CookMate AI.
///
/// Mirrors [LoginScreen]'s structure — brand mark, heading, then a single white
/// form card — so the two read as one flow. Fields chain focus in order, and
/// the final field submits.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      nameController.text.trim(),
      emailController.text.trim(),
      passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _showError(auth.errorMessage ?? 'Registration failed.');
    }
  }

  Future<void> _googleSignUp() async {
    final auth = context.read<AuthProvider>();
    await auth.signInWithGoogle();
    if (!mounted) return;
    if (auth.status == AuthStatus.authenticated) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else if (auth.errorMessage != null) {
      _showError(auth.errorMessage!);
    }
    // Cancelled sign-in leaves status idle with no error — do nothing.
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>(
      (p) => p.status == AuthStatus.loading,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppDimensions.spaceXl,
                AppDimensions.spaceS,
                AppDimensions.spaceXl,
                MediaQuery.viewInsetsOf(context).bottom + AppDimensions.spaceXl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    FadeSlideIn(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: AppDimensions.brLg,
                            child: Image.asset(
                              AppAssets.logo,
                              height: 64,
                              width: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 32,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceL),
                          Text(
                            AppStrings.createAccount,
                            style: AppTextStyles.display,
                          ),
                          const SizedBox(height: AppDimensions.spaceXs),
                          Text(
                            AppStrings.registerSubtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimensions.spaceXl),

                    FadeSlideIn(
                      delay: AppAnimations.staggerFor(1),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceXl),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppDimensions.brXl,
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          children: [
                            AppTextField(
                              controller: nameController,
                              label: 'Name',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const <String>[
                                AutofillHints.name,
                              ],
                              validator: Validators.name,
                              onFieldSubmitted: (_) =>
                                  _emailFocus.requestFocus(),
                            ),

                            const SizedBox(height: AppDimensions.spaceL),

                            AppTextField(
                              controller: emailController,
                              focusNode: _emailFocus,
                              label: AppStrings.email,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              validator: Validators.email,
                              onFieldSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                            ),

                            const SizedBox(height: AppDimensions.spaceL),

                            AppTextField(
                              controller: passwordController,
                              focusNode: _passwordFocus,
                              label: AppStrings.password,
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.newPassword,
                              ],
                              validator: Validators.password,
                              onFieldSubmitted: (_) =>
                                  _confirmFocus.requestFocus(),
                            ),

                            const SizedBox(height: AppDimensions.spaceL),

                            AppTextField(
                              controller: confirmController,
                              focusNode: _confirmFocus,
                              label: 'Confirm Password',
                              icon: Icons.lock_reset_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) => Validators.confirmPassword(
                                v,
                                passwordController.text,
                              ),
                              onFieldSubmitted: (_) {
                                if (!isLoading) _register();
                              },
                            ),

                            const SizedBox(height: AppDimensions.spaceXl),

                            PrimaryButton(
                              text: AppStrings.signUp,
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _register,
                            ),

                            const SizedBox(height: AppDimensions.spaceL),
                            const OrDivider(),
                            const SizedBox(height: AppDimensions.spaceL),

                            GoogleButton(
                              label: 'Sign up with Google',
                              onPressed: isLoading ? null : _googleSignUp,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppDimensions.spaceL),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.haveAccount,
                          style: AppTextStyles.body,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            AppStrings.signIn,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
}
