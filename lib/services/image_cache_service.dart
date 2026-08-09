// The seam between the app and on-disk caching of remote images.
//
// Mirrors the [ShareService] / [AiService] pattern: callers depend on THIS
// interface, never on a concrete implementation, so the storage mechanism can
// change (or be swapped for `cached_network_image`) without touching anything
// above it.
//
// WHY THIS EXISTS — the measurement, not a guess
// ----------------------------------------------
// Flutter caches DECODED images in memory via `PaintingBinding.instance
// .imageCache`, and its defaults are already generous: 1000 entries / 100 MiB
// (`_kDefaultSize` / `_kDefaultSizeBytes` in the SDK's `image_cache.dart`).
// That layer was never the problem here.
//
// The gap is DISK. Flutter's [NetworkImage] (`_network_image_io.dart`) issues a
// bare `HttpClient.getUrl` and pipes the bytes straight into the decoder. It
// writes nothing to disk and honours no HTTP cache directive — there is no
// `HttpClient` disk cache in `dart:io` at all. So every image the app has ever
// shown is re-downloaded from scratch on the next cold launch, no matter how
// recently it was fetched.
//
// Measured on the live sources this app actually uses:
//   * TheMealDB photos are 60–110 KB each and serve `Cache-Control:
//     max-age=14400` (4 hours) — a directive nothing in the app can act on.
//   * Wikimedia thumbnails are ~68 KB.
//   * A single Home session touches up to ~124 cards (Beef 95 + desi 10 +
//     Breakfast 19), and one category grid (Dessert) is 167 meals on its own.
//
// At ~85 KB average that is several MB re-downloaded per launch, on mobile
// data, purely because the bytes were thrown away. THAT is the real cost, and
// it is what this service fixes.
//
// CONTRACT NOTES (all load-bearing)
// ---------------------------------
// * NOTHING here may throw. An image cache is an optimisation; a failed read,
//   a full disk, or a corrupt entry must degrade to "cache miss" so the caller
//   silently falls through to the network. A caching bug must never be able to
//   stop a photo from loading.
// * The cache is BOUNDED — capped total bytes, oldest-first eviction — so it
//   cannot grow without limit on a user's device.
// * Keys are derived by hashing the URL, so an arbitrary remote URL can never
//   escape the cache directory via path traversal or an illegal filename.
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ TODO(cached_network_image): ADOPTING THE PACKAGE IS A ONE-LINE CHANGE.   │
// │                                                                          │
// │ This service and `DiskImageCache` exist because adding a dependency is   │
// │ the owner's call and has not been authorised. If that changes, add       │
// │ `cached_network_image` to pubspec.yaml and swap the ONE line that builds │
// │ the image widget in `core/widgets/recipe_card.dart` (`_image()`):        │
// │                                                                          │
// │   FROM: Image.network(recipe.imageUrl, cacheWidth: cacheWidth, ...)      │
// │   TO:   CachedNetworkImage(imageUrl: recipe.imageUrl,                    │
// │                            memCacheWidth: cacheWidth, ...)               │
// │                                                                          │
// │ Then delete this file, `disk_image_cache.dart`, and their wiring in      │
// │ `main.dart`. Nothing else in the app depends on them.                    │
// │                                                                          │
// │ ⚠️ Whatever replaces this, KEEP the `cacheWidth` value derived from      │
// │ LayoutBuilder constraints — see the warning in `recipe_card.dart`.       │
// └──────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/foundation.dart' show Uint8List;

/// Transport-level contract for caching remote image bytes on disk.
///
/// Implementations MUST be non-throwing: every method reports failure by
/// returning `null` / doing nothing, never by raising.
abstract interface class ImageCacheService {
  /// Returns the cached bytes for [url], or `null` on a miss.
  ///
  /// Never throws — an unreadable or corrupt entry reports a miss so the
  /// caller falls through to the network.
  Future<Uint8List?> read(String url);

  /// Stores [bytes] for [url], evicting oldest entries if the cache is over
  /// budget. Never throws; a failed write simply means the next read misses.
  Future<void> write(String url, Uint8List bytes);

  /// Removes every cached entry. Never throws.
  Future<void> clear();

  /// Total bytes currently held on disk, or 0 if that cannot be determined.
  Future<int> currentSizeBytes();
}
