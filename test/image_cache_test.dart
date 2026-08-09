// Tests for the image caching layer.
//
// SCOPE NOTE — why these are logic tests, not rendering tests.
// `Image.network` (and any ImageProvider that hits the network) never actually
// loads in a widget-test environment: the test HttpClient returns a 400 for
// every request by design. Asserting "the photo appeared" would therefore prove
// nothing. So these tests exercise the parts that carry the real risk and are
// genuinely verifiable:
//   * key derivation (filesystem-safe, collision-free, traversal-proof)
//   * read/write round-trips
//   * size accounting and oldest-first eviction under a byte budget
//   * the failure policy — every path degrades to a miss instead of throwing
//   * the ImageProvider's equality contract, which is what lets Flutter's own
//     in-memory cache dedupe two providers for the same photo
//   * the infinity guard on cacheWidth, a real past crash

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_recipe_generator/core/utils/app_image_cache.dart';
import 'package:ai_recipe_generator/core/utils/cached_network_image_provider.dart';
import 'package:ai_recipe_generator/services/disk_image_cache.dart';
import 'package:ai_recipe_generator/services/image_cache_service.dart';

/// Deterministic bytes of a given length, so a test can assert on size.
Uint8List _bytes(int length, {int fill = 7}) =>
    Uint8List.fromList(List<int>.filled(length, fill));

void main() {
  // Required by the AppImageCache group: touching
  // `PaintingBinding.instance.imageCache` throws without an initialized
  // binding. Harmless for the pure-IO tests above it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_cache_test');
  });

  tearDown(() async {
    AppImageCache.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DiskImageCache cacheWith({int? maxSizeBytes}) => DiskImageCache(
        directory: tempDir,
        maxSizeBytes: maxSizeBytes ?? DiskImageCache.defaultMaxSizeBytes,
      );

  group('key derivation', () {
    test('produces a filesystem-safe name for hostile URLs', () {
      // Real URLs from this app: the Wikimedia desi photos contain %22 (an
      // encoded quote), and every URL has slashes and a query-ish tail. None of
      // those characters may reach the filename.
      const List<String> urls = <String>[
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/%22Hyderabadi_Dum_Biryani%22.jpg/500px-%22Hyderabadi_Dum_Biryani%22.jpg',
        'https://www.themealdb.com/images/media/meals/1548772327.jpg',
        'https://example.com/a?b=c&d=e#frag',
      ];

      for (final String url in urls) {
        final String name = DiskImageCache.fileNameFor(url);
        expect(name, matches(RegExp(r'^[0-9a-f]{16}\.img$')),
            reason: 'name must be fixed-length lowercase hex: $name');
      }
    });

    test('cannot escape the cache directory via path traversal', () {
      // A URL is attacker-influenced in the general case; if it were used
      // verbatim as a filename it could write outside the cache dir.
      final String name = DiskImageCache.fileNameFor('../../../etc/passwd');
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('..')));
      expect(name, isNot(contains(r'\')));
    });

    test('is stable for the same URL and distinct for different URLs', () {
      const String a = 'https://www.themealdb.com/images/media/meals/a.jpg';
      const String b = 'https://www.themealdb.com/images/media/meals/b.jpg';

      expect(DiskImageCache.fileNameFor(a), DiskImageCache.fileNameFor(a));
      expect(
        DiskImageCache.fileNameFor(a),
        isNot(DiskImageCache.fileNameFor(b)),
      );
    });

    test('distributes without collisions across many realistic URLs', () {
      // Guards the hand-rolled FNV-1a: a broken implementation (e.g. one that
      // dropped the multiply) would collapse similar URLs onto one name and
      // silently serve the wrong photo.
      final Set<String> names = <String>{};
      for (int i = 0; i < 2000; i++) {
        names.add(DiskImageCache.fileNameFor(
          'https://www.themealdb.com/images/media/meals/meal_$i.jpg',
        ));
      }
      expect(names.length, 2000);
    });
  });

  group('read / write round-trip', () {
    test('writes bytes and reads them back unchanged', () async {
      final DiskImageCache cache = cacheWith();
      final Uint8List payload = _bytes(1024, fill: 42);

      await cache.write('https://example.com/a.jpg', payload);
      final Uint8List? read = await cache.read('https://example.com/a.jpg');

      expect(read, isNotNull);
      expect(read, equals(payload));
    });

    test('returns null for a URL that was never cached', () async {
      final DiskImageCache cache = cacheWith();
      expect(await cache.read('https://example.com/missing.jpg'), isNull);
    });

    test('ignores empty URLs and empty payloads', () async {
      final DiskImageCache cache = cacheWith();

      await cache.write('', _bytes(10));
      await cache.write('https://example.com/a.jpg', Uint8List(0));

      expect(await cache.read(''), isNull);
      expect(await cache.read('https://example.com/a.jpg'), isNull);
      expect(await cache.currentSizeBytes(), 0);
    });

    test('treats a zero-length file as a miss and cleans it up', () async {
      final DiskImageCache cache = cacheWith();
      const String url = 'https://example.com/truncated.jpg';

      // Simulate a write interrupted by a crash.
      await tempDir.create(recursive: true);
      final File file =
          File('${tempDir.path}/${DiskImageCache.fileNameFor(url)}');
      await file.writeAsBytes(<int>[]);

      expect(await cache.read(url), isNull);
      expect(await file.exists(), isFalse,
          reason: 'a corrupt zero-length entry should be removed');
    });

    test('rejects an implausibly large entry', () async {
      final DiskImageCache cache = cacheWith();
      // 5 MB > the 4 MB per-entry ceiling; one pathological response must not
      // be able to eat the whole budget.
      await cache.write('https://example.com/huge.jpg', _bytes(5 * 1024 * 1024));
      expect(await cache.read('https://example.com/huge.jpg'), isNull);
    });

    test('overwrites an existing entry rather than duplicating it', () async {
      final DiskImageCache cache = cacheWith();
      const String url = 'https://example.com/a.jpg';

      await cache.write(url, _bytes(500, fill: 1));
      await cache.write(url, _bytes(800, fill: 2));

      final Uint8List? read = await cache.read(url);
      expect(read!.length, 800);
      expect(read.first, 2);
      expect(await cache.currentSizeBytes(), 800);
    });
  });

  group('size accounting and eviction', () {
    test('currentSizeBytes sums the cached entries', () async {
      final DiskImageCache cache = cacheWith();

      await cache.write('https://example.com/a.jpg', _bytes(1000));
      await cache.write('https://example.com/b.jpg', _bytes(2000));

      expect(await cache.currentSizeBytes(), 3000);
    });

    test('currentSizeBytes is 0 before anything is written', () async {
      expect(await cacheWith().currentSizeBytes(), 0);
    });

    test('evicts oldest-first once over the byte budget', () async {
      // Budget fits two 1000-byte entries but not three.
      final DiskImageCache cache = cacheWith(maxSizeBytes: 2500);

      await cache.write('https://example.com/oldest.jpg', _bytes(1000));
      // Distinct mtimes: the filesystem timestamp is the eviction key, and on
      // some platforms it has coarse (~1s) granularity, so without a real gap
      // the sort order would be arbitrary and this test would be flaky.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await cache.write('https://example.com/middle.jpg', _bytes(1000));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await cache.write('https://example.com/newest.jpg', _bytes(1000));

      expect(await cache.currentSizeBytes(), lessThanOrEqualTo(2500));
      expect(await cache.read('https://example.com/oldest.jpg'), isNull,
          reason: 'the oldest entry should have been evicted first');
      expect(await cache.read('https://example.com/newest.jpg'), isNotNull,
          reason: 'the newest entry must survive');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('stays within budget across many writes', () async {
      final DiskImageCache cache = cacheWith(maxSizeBytes: 5000);

      for (int i = 0; i < 20; i++) {
        await cache.write('https://example.com/img_$i.jpg', _bytes(1000));
      }

      expect(await cache.currentSizeBytes(), lessThanOrEqualTo(5000));
    });

    test('clear removes everything', () async {
      final DiskImageCache cache = cacheWith();

      await cache.write('https://example.com/a.jpg', _bytes(1000));
      await cache.write('https://example.com/b.jpg', _bytes(1000));
      await cache.clear();

      expect(await cache.currentSizeBytes(), 0);
      expect(await cache.read('https://example.com/a.jpg'), isNull);
    });
  });

  group('failure policy: never throws, always degrades to a miss', () {
    test('read on a non-existent directory reports a miss', () async {
      final DiskImageCache cache = DiskImageCache(
        directory: Directory('${tempDir.path}/does/not/exist'),
      );
      expect(await cache.read('https://example.com/a.jpg'), isNull);
      expect(await cache.currentSizeBytes(), 0);
    });

    test('clear on a non-existent directory is a no-op, not an error',
        () async {
      final DiskImageCache cache = DiskImageCache(
        directory: Directory('${tempDir.path}/does/not/exist'),
      );
      await expectLater(cache.clear(), completes);
    });

    test('write into an unusable location fails silently', () async {
      // A file where the cache directory should be: `create()` cannot succeed,
      // so the write must be swallowed rather than surfaced.
      final File blocker = File('${tempDir.path}/blocker');
      await blocker.writeAsString('not a directory');

      final DiskImageCache cache =
          DiskImageCache(directory: Directory(blocker.path));

      await expectLater(
        cache.write('https://example.com/a.jpg', _bytes(100)),
        completes,
      );
      expect(await cache.read('https://example.com/a.jpg'), isNull);
    });
  });

  group('CachedNetworkImageProvider', () {
    const String url = 'https://www.themealdb.com/images/media/meals/a.jpg';

    test('two providers for the same URL are equal', () {
      // This is what lets Flutter's in-memory ImageCache dedupe. If equality
      // included the cache instance, every rebuild that constructed a new
      // provider would miss and re-decode — the exact bug that made the
      // profile avatar flicker.
      final ImageCacheService cacheA = cacheWith();
      final ImageCacheService cacheB = cacheWith();

      final a = CachedNetworkImageProvider(url, cache: cacheA);
      final b = CachedNetworkImageProvider(url, cache: cacheB);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('providers for different URLs are not equal', () {
      final ImageCacheService cache = cacheWith();
      expect(
        CachedNetworkImageProvider(url, cache: cache),
        isNot(equals(CachedNetworkImageProvider('${url}x', cache: cache))),
      );
    });

    test('scale participates in equality', () {
      final ImageCacheService cache = cacheWith();
      expect(
        CachedNetworkImageProvider(url, cache: cache),
        isNot(equals(
          CachedNetworkImageProvider(url, cache: cache, scale: 2.0),
        )),
      );
    });

    test('obtainKey resolves synchronously to itself', () async {
      final provider = CachedNetworkImageProvider(url, cache: cacheWith());
      expect(
        await provider.obtainKey(ImageConfiguration.empty),
        same(provider),
      );
    });
  });

  group('cachedNetworkImage helper', () {
    const String url = 'https://www.themealdb.com/images/media/meals/a.jpg';

    setUp(() => AppImageCache.instance = DiskImageCache(directory: tempDir));

    test('wraps in ResizeImage when a finite cacheWidth is given', () {
      final ImageProvider<Object> provider =
          cachedNetworkImage(url, cacheWidth: 400);

      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).width, 400);
      expect(provider.imageProvider, isA<CachedNetworkImageProvider>());
    });

    test('returns a bare provider when cacheWidth is null', () {
      expect(cachedNetworkImage(url), isA<CachedNetworkImageProvider>());
    });

    test('ignores a non-positive cacheWidth instead of crashing', () {
      // Defensive: guards the documented "Unsupported operation: Infinity or
      // NaN toInt" crash class. A grid passes width: double.infinity, and a
      // call site that derived a bad decode size from it must degrade to a
      // native decode rather than render a red error box.
      expect(cachedNetworkImage(url, cacheWidth: 0),
          isA<CachedNetworkImageProvider>());
      expect(cachedNetworkImage(url, cacheWidth: -10),
          isA<CachedNetworkImageProvider>());
    });
  });

  group('AppImageCache configuration', () {
    test('memory budget is 48 MiB and below Flutter\'s 100 MiB default', () {
      // Pinned deliberately: this is a measured trade-off (see AppImageCache),
      // not an arbitrary constant, so a silent change should fail a test.
      expect(AppImageCache.maxMemoryCacheBytes, 48 * 1024 * 1024);
      expect(AppImageCache.maxMemoryCacheBytes, lessThan(100 << 20));
    });

    test('configureMemoryCache applies the budget to the live ImageCache', () {
      final int original = PaintingBinding.instance.imageCache.maximumSizeBytes;
      addTearDown(
        () => PaintingBinding.instance.imageCache.maximumSizeBytes = original,
      );

      AppImageCache.configureMemoryCache();

      expect(
        PaintingBinding.instance.imageCache.maximumSizeBytes,
        AppImageCache.maxMemoryCacheBytes,
      );
    });

    test('leaves the entry-count limit alone', () {
      // The byte budget always binds first at this app's decode sizes
      // (48 MiB / ~0.6 MB per grid photo ≈ 80 images, far under 1000), so
      // touching maximumSize would change nothing observable.
      final int original = PaintingBinding.instance.imageCache.maximumSizeBytes;
      addTearDown(
        () => PaintingBinding.instance.imageCache.maximumSizeBytes = original,
      );

      final int countBefore = PaintingBinding.instance.imageCache.maximumSize;
      AppImageCache.configureMemoryCache();

      expect(PaintingBinding.instance.imageCache.maximumSize, countBefore);
    });

    test('instance is overridable and resettable for tests', () {
      final DiskImageCache injected = DiskImageCache(directory: tempDir);
      AppImageCache.instance = injected;
      expect(AppImageCache.instance, same(injected));

      AppImageCache.reset();
      expect(AppImageCache.instance, isNot(same(injected)));
    });
  });
}
