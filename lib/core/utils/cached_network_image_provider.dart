// A disk-backed [ImageProvider], replacing Flutter's [NetworkImage] for remote
// recipe photos.
//
// WHY: Flutter's NetworkImage (`_network_image_io.dart`) issues a bare
// `HttpClient.getUrl` and pipes the bytes straight into the decoder — it writes
// nothing to disk and honours no HTTP cache directive. TheMealDB serves its
// photos with `Cache-Control: max-age=14400`, and nothing in the app can act on
// it, so every photo the user has already seen is re-downloaded on the next
// cold launch. This provider adds the missing disk layer.
//
// HOW IT COMPOSES WITH FLUTTER'S OWN CACHING
// ------------------------------------------
// This is strictly a *third* tier below the two Flutter already has:
//
//   1. ImageCache (live/pending decoded images, in memory) — untouched.
//   2. ImageCache byte budget (100 MiB default)            — untouched.
//   3. THIS: raw encoded bytes on disk, surviving process death.
//
// Because [obtainKey] returns a value-equal key, tiers 1–2 still short-circuit
// this provider entirely for anything already decoded in memory. Disk is only
// consulted on a genuine memory-cache miss, which is exactly the cold-launch
// case it exists to fix.
//
// FAILURE POLICY (load-bearing): the cache is an optimisation and must never be
// able to stop an image from loading. A disk read that fails or misses falls
// through to the network; a disk write that fails is ignored. The network path
// is identical to Flutter's, so worst case this behaves exactly like
// NetworkImage.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../services/image_cache_service.dart';

/// An [ImageProvider] that reads bytes from an [ImageCacheService] before
/// falling back to the network, caching what it downloads.
///
/// Equality is on [url] + [scale] only — deliberately NOT the cache instance —
/// so two providers for the same photo share one entry in Flutter's in-memory
/// [ImageCache]. Including the service would make every rebuild that
/// constructed a new provider a cache miss, which is precisely the bug that
/// once made the profile avatar flicker (see `profile_avatar.dart`).
@immutable
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates a provider for [url], backed by [cache].
  const CachedNetworkImageProvider(
    this.url, {
    required this.cache,
    this.scale = 1.0,
  });

  /// The remote image URL.
  final String url;

  /// Disk cache consulted before the network. Excluded from equality.
  final ImageCacheService cache;

  /// Linear scale factor for the decoded image.
  final double scale;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunkEvents),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Image key', key.url),
      ],
    );
  }

  /// Disk first, network second; cache what the network returns.
  Future<ui.Codec> _load(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    try {
      // --- Tier 3a: disk ---
      // Never throws by contract; a failure or miss returns null.
      final Uint8List? cached = await key.cache.read(key.url);
      if (cached != null && cached.isNotEmpty) {
        try {
          return await decode(
            await ui.ImmutableBuffer.fromUint8List(cached),
          );
        } catch (error) {
          // The cached bytes were not a decodable image (a truncated or
          // corrupt entry). Fall through to the network rather than failing —
          // and the bad entry is overwritten by the fresh download below.
          if (kDebugMode) {
            debugPrint(
              'CachedNetworkImageProvider: corrupt cache entry for '
              '${key.url}: $error — refetching',
            );
          }
        }
      }

      // --- Tier 3b: network ---
      final Uint8List bytes = await _fetch(key.url, chunkEvents);

      // Best-effort write; a failure here must not affect the image.
      unawaited(key.cache.write(key.url, bytes));

      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Mirror NetworkImage: give the in-memory cache a chance to register the
      // key before evicting it, so a transient failure does not poison future
      // resolves of the same URL.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      unawaited(chunkEvents.close());
    }
  }

  /// Downloads [url], reporting progress so `loadingBuilder` still works.
  Future<Uint8List> _fetch(
    String url,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    final HttpClientRequest request =
        await _httpClient.getUrl(Uri.base.resolve(url));
    final HttpClientResponse response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      // Drain so the connection can be reused, then fail exactly as
      // NetworkImage does — RecipeCard's errorBuilder shows the placeholder.
      await response.drain<List<int>>(<int>[]);
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.base.resolve(url),
      );
    }

    final Uint8List bytes = await consolidateHttpClientResponseBytes(
      response,
      onBytesReceived: (int cumulative, int? total) {
        if (!chunkEvents.isClosed) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: cumulative,
              expectedTotalBytes: total,
            ),
          );
        }
      },
    );

    if (bytes.isEmpty) {
      throw Exception('CachedNetworkImageProvider: empty response for $url');
    }
    return bytes;
  }

  /// Shared client, matching NetworkImage's own approach so connections are
  /// pooled across images. `autoUncompress` is false so the byte count we cache
  /// is the bytes actually sent — the same reason the SDK sets it.
  static final HttpClient _httpClient = HttpClient()..autoUncompress = false;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedNetworkImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CachedNetworkImageProvider')}'
      '("$url", scale: ${scale.toStringAsFixed(1)})';
}
