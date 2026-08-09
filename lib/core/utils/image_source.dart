import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'app_image_cache.dart';

/// Resolves a stored avatar/photo string into an [ImageProvider].
///
/// Avatars are stored **as compressed base64 `data:` URIs inside the Firestore
/// user document** (free — no Cloud Storage / Blaze plan required), while
/// curated/remote photos are plain `http(s)` URLs. This helper transparently
/// handles both: a `data:image/...;base64,...` string decodes to a
/// [MemoryImage], anything else becomes a [NetworkImage].
///
/// Returns `null` for a null/empty/malformed value so callers can fall back to
/// an initial or a placeholder icon.
///
/// The `http(s)` branch is disk-cached (see [cachedNetworkImage]). In practice
/// that only affects **Google account photos** — avatars the user sets are
/// `data:` URIs already living in the Firestore document, so they need no
/// network fetch and no disk cache.
///
/// ⚠️ Callers must still resolve this ONCE per URL and hold the result, not
/// call it on every build: the `data:` branch decodes base64 into a fresh
/// `Uint8List` each time, and [MemoryImage] keys its cache on that list's
/// identity — so re-resolving per build is always a cache miss and the avatar
/// visibly flickers. See `profile_avatar.dart`, which does exactly that and is
/// pinned by a test.
ImageProvider<Object>? imageProviderFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;

  if (url.startsWith('data:image')) {
    final int comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  // No cacheWidth: the caller knows the display size, not this helper, and
  // avatars are small enough that a native decode is not a concern.
  return cachedNetworkImage(url);
}
