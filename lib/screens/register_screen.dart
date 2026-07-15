import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/google_button.dart';
import '../core/widgets/or_divider.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
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
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                    maxWidth: AppDimensions.maxContentWidth,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Back to Login.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back,
                                  color: AppColors.primary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),

                          Image.asset(
                            AppAssets.logo,
                            height: 64,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.restaurant_menu,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Join and start cooking with AI',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 16),

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
                                    controller: nameController,
                                    label: 'Name',
                                    icon: Icons.person_outline,
                                    textInputAction: TextInputAction.next,
                                    validator: Validators.name,
                                  ),

                                  const SizedBox(height: 14),

                                  AppTextField(
                                    controller: emailController,
                                    label: 'Email',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: Validators.email,
                                  ),

                                  const SizedBox(height: 14),

                                  AppTextField(
                                    controller: passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    textInputAction: TextInputAction.next,
                                    validator: Validators.password,
                                  ),

                                  const SizedBox(height: 14),

                                  AppTextField(
                                    controller: confirmController,
                                    label: 'Confirm Password',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) =>
                                        Validators.confirmPassword(
                                      v,
                                      passwordController.text,
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  PrimaryButton(
                                    text: 'SIGN UP',
                                    isLoading: isLoading,
                                    onPressed: isLoading ? null : _register,
                                  ),

                                  const SizedBox(height: 14),

                                  const OrDivider(),

                                  const SizedBox(height: 14),

                                  GoogleButton(
                                    label: 'Sign up with Google',
                                    onPressed: isLoading ? null : _googleSignUp,
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Already have an account?',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'Sign In',
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
                        ],
                      ),
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
