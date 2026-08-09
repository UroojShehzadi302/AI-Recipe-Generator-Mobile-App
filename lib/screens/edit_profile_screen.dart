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
import '../core/widgets/profile_avatar.dart';
import '../providers/auth_provider.dart';
import 'avatar_crop_screen.dart';

/// Edit Profile — change display name and set a new avatar.
///
/// Name persists to FirebaseAuth + the Firestore `/users/{uid}` document. The
/// avatar is picked from the gallery, cropped square via [AvatarCropScreen],
/// then stored as a compressed base64 `data:` URI **inside the same Firestore
/// document** — deliberately NOT Cloud Storage, which Firebase now gates
/// behind the paid Blaze plan.
///
/// All wiring goes through [AuthProvider.updateProfile] (Widget → Provider →
/// Repository → Service). Never touches Firebase directly.
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
      // Picked at a generous size — the crop screen does the downscaling, and
      // starting from a larger source keeps the cropped region sharp. Capped
      // anyway so a 12 MP photo doesn't blow up memory while cropping.
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;

      // Let the user choose WHICH part of the photo becomes the avatar. This
      // is also what guarantees a square: an uncropped portrait would
      // letterbox with empty bars inside the circular avatar.
      final File? cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute<File?>(
          builder: (_) => AvatarCropScreen(source: File(picked.path)),
        ),
      );
      if (cropped != null && mounted) {
        setState(() => _pickedAvatar = cropped);
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
        title: Text('Edit Profile', style: AppTextStyles.title),
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
          // A freshly-cropped file isn't a URL yet, so it can't go through
          // ProfileAvatar — but it is already square, so a plain cover-fit
          // circle matches exactly how it will look once saved.
          if (hasPicked)
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: ClipOval(
                child: Image.file(
                  _pickedAvatar!,
                  width: 104,
                  height: 104,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            ProfileAvatar(
              radius: 52,
              imageUrl: hasRemote ? photoUrl : null,
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
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
          Icon(Icons.mail_outline, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email.isEmpty ? 'No email on file' : email,
              style: AppTextStyles.subtitle,
            ),
          ),
          Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}
