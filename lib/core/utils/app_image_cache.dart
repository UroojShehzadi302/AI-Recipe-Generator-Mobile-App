// Global access point for image caching, plus the in-memory cache tuning.
//
// WHY A GLOBAL, WHEN EVERYTHING ELSE GOES THROUGH PROVIDER
// --------------------------------------------------------
// This app's rule is Widget → Provider → Repository → Service, and that rule is
// about BUSINESS LOGIC — data the user owns, which needs to be testable and
// swappable. An image byte cache is neither: it is infrastructure sitting
// underneath the rendering layer, the exact tier Flutter itself exposes
// globally as `PaintingBinding.instance.imageCache`.
//
// Routing it through Provider would mean `RecipeCard` — a leaf widget rendered
// hundreds of times in a grid — doing a `context.read` per build purely to
// construct an ImageProvider. That adds an InheritedWidget dependency to the
// hottest widget in the app for no testability gain, since the provider is
// compared by URL and not by cache instance.
//
// The established precedent in this codebase is `NotificationStore`, which is
// static for a similar structural reason (the FCM background isolate has no
// provider graph). The seam is still clean: [instance] is settable, so tests
// inject a temp-directory cache and the widget layer never names a concrete
// implementation.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../services/disk_image_cache.dart';
import '../../services/image_cache_service.dart';
import 'cached_network_image_provider.dart';

/// App-wide image caching configuration and the shared disk cache.
class AppImageCache {
  AppImageCache._();

  static ImageCacheService? _instance;

  /// The shared disk cache.
  ///
  /// Defaults to a [DiskImageCache] under the system temp directory, which on
  /// Android resolves to the app-private cache dir — the correct home for
  /// regenerable data, and one the OS may reclaim under storage pressure
  /// (exactly the right semantics for a cache). Using it avoids a
  /// `path_provider` dependency, which this project does not have.
  static ImageCacheService get instance =>
      _instance ??= DiskImageCache(directory: _defaultDirectory());

  /// Overrides the cache — for tests, which point it at a temp directory.
  @visibleForTesting
  static set instance(ImageCacheService value) => _instance = value;

  /// Resets to the default. Test teardown hook.
  @visibleForTesting
  static void reset() => _instance = null;

  static Directory _defaultDirectory() =>
      Directory('${Directory.systemTemp.path}/cookmate_image_cache');

  /// Applies the in-memory [ImageCache] tuning. Call once from `main()`.
  ///
  /// ⚠️ READ THE NUMBERS BEFORE CHANGING THEM — they are derived from
  /// measurements, not taste.
  ///
  /// Flutter's defaults are 1000 entries / 100 MiB. The **count** limit is
  /// irrelevant here: at the app's decoded sizes the byte budget always binds
  /// first (100 MiB / ~0.6 MB ≈ 173 images, well under 1000), so raising or
  /// lowering the count changes nothing observable. It is left alone.
  ///
  /// The **byte** budget is lowered to 48 MiB. Reasoning:
  /// * A grid cell on a 393dp phone at DPR 2.75 decodes to ~469×322 px ≈
  ///   0.60 MB; a rail card is ~0.62 MB. 48 MiB therefore holds ~80 decoded
  ///   photos — more than a full Home screen (3 rails) plus an open category
  ///   grid, so nothing the user is actually looking at gets evicted.
  /// * 100 MiB is a *desktop-scale* default. On a budget Android device (this
  ///   app's target — the owner tests on an Infinix X663) letting one cache
  ///   claim 100 MB of decoded bitmaps materially raises the odds of a
  ///   low-memory kill. The photos are now on disk, so an eviction costs a
  ///   fast local re-decode rather than a re-download — which is precisely
  ///   what makes trimming this budget safe, and is why the two changes belong
  ///   together.
  ///
  /// Net effect: less RAM pressure, and misses got much cheaper.
  static void configureMemoryCache() {
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxMemoryCacheBytes;
  }

  /// In-memory decoded-image budget: 48 MiB. See [configureMemoryCache].
  static const int maxMemoryCacheBytes = 48 * 1024 * 1024;
}

/// Builds a disk-backed [ImageProvider] for a remote [url], decoded at
/// [cacheWidth] device pixels when that is known.
///
/// The single helper every remote photo in the app goes through, so the disk
/// cache and the decode-size policy stay consistent across call sites.
///
/// ⚠️ [cacheWidth] MUST be null rather than a computed value when the width is
/// unconstrained. Grids pass `width: double.infinity`, and turning that into a
/// decode size throws *"Unsupported operation: Infinity or NaN toInt"* — a real
/// past bug that rendered a red error box instead of the card on Favorites,
/// Saved, Search, and Category. Callers derive the value from `LayoutBuilder`
/// constraints; see `recipe_card.dart`. Guarded by `test/ui_polish_test.dart`.
///
/// A non-finite or non-positive [cacheWidth] is defensively ignored here too,
/// so a future call site cannot reintroduce that crash.
ImageProvider<Object> cachedNetworkImage(String url, {int? cacheWidth}) {
  final ImageProvider<Object> provider = CachedNetworkImageProvider(
    url,
    cache: AppImageCache.instance,
  );

  if (cacheWidth == null || cacheWidth <= 0) return provider;

  // Exactly what `Image.network(cacheWidth:)` does internally: decode the
  // bitmap at display size instead of full resolution. TheMealDB serves large
  // JPEGs, and a grid of native-resolution decodes is the main memory cost on
  // these screens.
  return ResizeImage(provider, width: cacheWidth, allowUpscaling: false);
}
