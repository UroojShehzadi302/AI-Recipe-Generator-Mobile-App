import 'dart:convert';

import 'package:flutter/widgets.dart';

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

  return NetworkImage(url);
}
