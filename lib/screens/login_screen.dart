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

/// Sign-in screen for CookMate AI.
///
/// Brand mark and welcome copy sit directly on the cream background; the form
/// lives in a single white card so the eye lands on the inputs. The layout is
/// scroll-safe with the keyboard open and caps its width on tablets.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool rememberMe = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      emailController.text.trim(),
      passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _showError(auth.errorMessage ?? 'Sign in failed.');
    }
  }

  Future<void> _googleSignIn() async {
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
                AppDimensions.spaceXl,
                AppDimensions.spaceXl,
                MediaQuery.viewInsetsOf(context).bottom + AppDimensions.spaceXl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeSlideIn(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: AppDimensions.brLg,
                            child: Image.asset(
                              AppAssets.logo,
                              height: 72,
                              width: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 72,
                                width: 72,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 36,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceM),
                          Text(
                            AppStrings.appName,
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceXl),
                          Text(
                            AppStrings.welcomeBack,
                            style: AppTextStyles.display,
                          ),
                          const SizedBox(height: AppDimensions.spaceXs),
                          Text(
                            AppStrings.loginSubtitle,
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
                              controller: emailController,
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
                              textInputAction: TextInputAction.done,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              validator: Validators.password,
                              onFieldSubmitted: (_) {
                                if (!isLoading) _signIn();
                              },
                            ),

                            const SizedBox(height: AppDimensions.spaceS),

                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: rememberMe,
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    onChanged: (value) => setState(
                                      () => rememberMe = value ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spaceS),
                                Flexible(
                                  child: Text(
                                    AppStrings.rememberMe,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  ),
                                  child: Text(
                                    AppStrings.forgotPassword,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppDimensions.spaceL),

                            PrimaryButton(
                              text: AppStrings.signIn,
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _signIn,
                            ),

                            const SizedBox(height: AppDimensions.spaceL),
                            const OrDivider(),
                            const SizedBox(height: AppDimensions.spaceL),

                            GoogleButton(
                              onPressed: isLoading ? null : _googleSignIn,
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
                          AppStrings.noAccount,
                          style: AppTextStyles.body,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.register,
                          ),
                          child: Text(
                            AppStrings.signUp,
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
