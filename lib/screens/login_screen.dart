import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/google_button.dart';
import '../core/widgets/or_divider.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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
    if (auth.errorMessage != null) {
      _showError(auth.errorMessage!);
    }
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
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 30,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        Image.asset(
                          AppAssets.logo,
                          height: 80,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          AppStrings.welcomeBack,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          AppStrings.loginSubtitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 22),

                        Card(
                          elevation: 5,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            child: Column(
                              children: [
                                AppTextField(
                                  controller: emailController,
                                  label: AppStrings.email,
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: Validators.email,
                                ),

                                const SizedBox(height: 16),

                                AppTextField(
                                  controller: passwordController,
                                  label: AppStrings.password,
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  validator: Validators.password,
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 0.85,
                                      child: Checkbox(
                                        value: rememberMe,
                                        activeColor: AppColors.primary,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (value) {
                                          setState(() {
                                            rememberMe = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const Text(
                                      AppStrings.rememberMe,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.forgotPassword,
                                      ),
                                      child: const Text(
                                        AppStrings.forgotPassword,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                PrimaryButton(
                                  text: AppStrings.signIn,
                                  isLoading: isLoading,
                                  onPressed: isLoading ? null : _signIn,
                                ),

                                const SizedBox(height: 16),

                                const OrDivider(),

                                const SizedBox(height: 16),

                                GoogleButton(
                                  onPressed: isLoading ? null : _googleSignIn,
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      AppStrings.noAccount,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.register,
                                      ),
                                      child: const Text(
                                        AppStrings.signUp,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
