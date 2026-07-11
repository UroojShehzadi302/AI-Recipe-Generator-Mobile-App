import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A circular profile avatar with a subtle border and shadow.
///
/// Shows the user's remote image when available, falling back to an initial or
/// a generic person icon. Kept resilient to broken image URLs so a bad link
/// never leaves an empty circle.
///
/// TODO(Phase 6): swap plain [NetworkImage] for `cached_network_image` once the
/// package is added, to get disk caching and placeholder/error widgets.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.radius = 40,
    this.fallbackInitial,
  });

  /// Remote image URL. When null/empty the fallback content is shown.
  final String? imageUrl;

  /// Radius of the circular avatar.
  final double radius;

  /// Single character shown when no image is available.
  final String? fallbackInitial;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retry loading if the URL changes after a previous failure.
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFailed = false;
    }
  }

  bool get _hasImage =>
      widget.imageUrl != null && widget.imageUrl!.isNotEmpty && !_imageFailed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: AppColors.surface,
        backgroundImage: _hasImage ? NetworkImage(widget.imageUrl!) : null,
        onBackgroundImageError: _hasImage
            ? (Object error, StackTrace? stackTrace) {
                if (mounted) {
                  setState(() => _imageFailed = true);
                }
              }
            : null,
        child: _hasImage ? null : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    final initial = widget.fallbackInitial;
    if (initial != null && initial.isNotEmpty) {
      return Text(
        initial.substring(0, 1).toUpperCase(),
        style: AppTextStyles.title,
      );
    }
    return Icon(
      Icons.person,
      size: widget.radius,
      color: AppColors.secondary,
    );
  }
}
