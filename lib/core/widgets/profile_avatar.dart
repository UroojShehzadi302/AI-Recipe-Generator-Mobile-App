import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../utils/image_source.dart';

/// A circular profile avatar with a subtle border and shadow.
///
/// Shows the user's remote image when available, falling back to an initial or
/// a generic person icon. Kept resilient to broken image URLs so a bad link
/// never leaves an empty circle.
///
/// Caching status (the old `TODO(Phase 6)` is resolved):
/// * **Disk caching is done**, without a new dependency. `imageProviderFromUrl`
///   now returns a disk-backed provider for `http(s)` URLs — see
///   `core/utils/app_image_cache.dart`. In practice this only matters for
///   Google account photos; a user-set avatar is a `data:` URI already stored
///   in the Firestore document, so it never touches the network at all.
/// * **Placeholder/error widgets** were never missing — this widget already
///   renders an initial or a person icon via `errorBuilder`, which is the
///   behaviour that TODO was asking for.
///
/// So there is nothing left here that `cached_network_image` would add. See the
/// `TODO(cached_network_image)` box in `services/image_cache_service.dart` for
/// the one-line migration if the owner ever authorises the package.
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

  /// The resolved provider, built ONCE per URL.
  ///
  /// Load-bearing: avatars are base64 `data:` URIs, and decoding one produces
  /// a fresh `Uint8List` every time. Because [MemoryImage] keys its cache on
  /// that list's identity, resolving on each build made every rebuild a cache
  /// miss — so the avatar re-decoded and visibly flickered whenever an
  /// unrelated bit of the screen rebuilt (favoriting a recipe, for instance).
  ImageProvider<Object>? _provider;

  @override
  void initState() {
    super.initState();
    _provider = imageProviderFromUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild the provider (and retry after a failure) only when the URL
    // genuinely changes.
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFailed = false;
      _provider = imageProviderFromUrl(widget.imageUrl);
    }
  }

  ImageProvider<Object>? get _image => _imageFailed ? null : _provider;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? image = _image;
    final double diameter = widget.radius * 2;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      // ClipOval + BoxFit.cover, rather than CircleAvatar's backgroundImage:
      // cover guarantees the circle is always FILLED. A non-square source
      // otherwise leaves empty bars inside the avatar (avatars are cropped
      // square on the way in now, but remote/Google photos are not ours to
      // control).
      child: ClipOval(
        child: image == null
            ? Center(child: _buildFallback())
            : Image(
                image: image,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                // Keeps the previous frame on screen while a new one resolves,
                // instead of blanking to the background colour.
                gaplessPlayback: true,
                errorBuilder: (_, _, _) {
                  // Deferred: setState during build would throw.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _imageFailed = true);
                  });
                  return Center(child: _buildFallback());
                },
              ),
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
