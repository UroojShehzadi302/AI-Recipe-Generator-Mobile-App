import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

/// Delete Account — permanently removes the account and all of its data.
///
/// Google Play requires an in-app path to account deletion for any app that
/// lets users create an account, so this is a shipping requirement, not a
/// nicety.
///
/// The flow is deliberately slow. It states exactly what will be destroyed,
/// requires the user to type DELETE, and then re-authenticates (password field
/// for password-backed accounts, a fresh Google sign-in otherwise). Deletion is
/// irreversible and there is no undo, so friction here is the feature.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  /// The word the user must type to arm the delete button.
  static const String _confirmWord = 'DELETE';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _deleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _deleting = true);
    final auth = context.read<AuthProvider>();
    final bool usesPassword = auth.hasPasswordProvider;

    final bool deleted = await auth.deleteAccount(
      password: usesPassword ? _passwordController.text : null,
    );
    if (!mounted) return;
    setState(() => _deleting = false);

    if (deleted) {
      // Tear down the whole stack — there is no account to come back to.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    // `false` with no error message means the user cancelled the Google
    // re-authentication sheet — nothing was deleted, so say nothing.
    final String? error = auth.errorMessage;
    if (error != null) _toast(error);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bool usesPassword = auth.hasPasswordProvider;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Delete Account', style: AppTextStyles.title),
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
                  _warningCard(),
                  const SizedBox(height: AppDimensions.spaceXl),
                  if (usesPassword) ...<Widget>[
                    Text(
                      'Confirm your password',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceM),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value ?? '').isEmpty ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: AppDimensions.spaceL),
                  ] else ...<Widget>[
                    Text(
                      "You'll be asked to sign in with Google again to confirm "
                      "it's you.",
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: AppDimensions.spaceL),
                  ],
                  Text(
                    'Type $_confirmWord to confirm',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
                  AppTextField(
                    controller: _confirmController,
                    label: _confirmWord,
                    icon: Icons.warning_amber_outlined,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    validator: (value) =>
                        (value ?? '').trim().toUpperCase() == _confirmWord
                            ? null
                            : 'Type $_confirmWord exactly',
                  ),
                  const SizedBox(height: AppDimensions.spaceXxl),
                  _deleteButton(),
                  const SizedBox(height: AppDimensions.spaceL),
                  Center(
                    child: TextButton(
                      onPressed: _deleting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Keep my account'),
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

  /// Spells out exactly what is destroyed. Vague warnings ("this cannot be
  /// undone") do not help someone decide; an itemised list does.
  Widget _warningCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceL),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppDimensions.brLg,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(
                child: Text(
                  'This cannot be undone',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Text(
            'Deleting your account permanently removes:',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          ...<String>[
            'Your profile and photo',
            'All favourite recipes',
            'All saved AI recipes',
            'Your entire chat history',
          ].map(_bullet),
          const SizedBox(height: AppDimensions.spaceM),
          Text(
            'We cannot recover any of it afterwards, even if you sign up again '
            'with the same email.',
            style: AppTextStyles.subtitle,
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 6, right: AppDimensions.spaceS),
            child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
          ),
          Expanded(child: Text(text, style: AppTextStyles.subtitle)),
        ],
      ),
    );
  }

  /// Stays disabled until the confirmation word matches, so the destructive
  /// action can never be one stray tap away.
  Widget _deleteButton() {
    final bool armed =
        _confirmController.text.trim().toUpperCase() == _confirmWord;

    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: (!armed || _deleting) ? null : _delete,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.brMd),
        ),
        child: _deleting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'DELETE MY ACCOUNT',
                style: AppTextStyles.button,
              ),
      ),
    );
  }
}
