import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

/// Edit Profile — change display name and upload a new avatar.
///
/// Name persists to FirebaseAuth + the Firestore `/users/{uid}` document; the
/// avatar is uploaded to Cloud Storage (`avatars/{uid}.jpg`) and its URL saved
/// to the same places. All wiring goes through [AuthProvider.updateProfile]
/// (Widget → Provider → Repository → Service). Never touches Firebase directly.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();

  /// A newly-picked avatar not yet uploaded, or null to keep the current one.
  File? _pickedAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final name = context.read<AuthProvider>().user?.name ?? '';
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _pickedAvatar = File(picked.path));
      }
    } catch (_) {
      if (!mounted) return;
      _snack("Couldn't open your gallery. Please try again.");
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final bool ok = await auth.updateProfile(
      name: _nameController.text,
      avatarFile: _pickedAvatar,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack('Profile updated');
      Navigator.pop(context);
    } else {
      _snack(auth.errorMessage ?? 'Could not update your profile.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final email = (user?.email ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Edit Profile', style: AppTextStyles.title),
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
                  16,
                  context.pagePadding,
                  24,
                ),
                children: [
                  const SizedBox(height: 8),
                  Center(child: _avatarPicker(user?.photoUrl)),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      label: const Text('Change photo'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Please enter your name';
                      if (text.length < 2) return 'Name is too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _emailField(email),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    text: _saving ? 'SAVING…' : 'SAVE CHANGES',
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

  Widget _avatarPicker(String? photoUrl) {
    final bool hasPicked = _pickedAvatar != null;
    final bool hasRemote = (photoUrl ?? '').isNotEmpty;

    return GestureDetector(
      onTap: _saving ? null : _pickImage,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.surface,
              backgroundImage: hasPicked
                  ? FileImage(_pickedAvatar!)
                  : (hasRemote ? NetworkImage(photoUrl!) : null)
                      as ImageProvider<Object>?,
              child: (hasPicked || hasRemote)
                  ? null
                  : const Icon(Icons.person, size: 52, color: AppColors.secondary),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only email display (email changes are out of scope for M11).
  Widget _emailField(String email) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: AppDimensions.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email.isEmpty ? 'No email on file' : email,
              style: AppTextStyles.subtitle,
            ),
          ),
          const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}
