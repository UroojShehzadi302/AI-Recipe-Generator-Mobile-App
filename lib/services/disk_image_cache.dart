// A small, dependency-free [ImageCacheService] backed by `dart:io` files.
//
// See `image_cache_service.dart` for WHY this exists (short version: Flutter's
// NetworkImage writes nothing to disk, so every image re-downloads on every
// cold launch) and for the one-line migration to `cached_network_image`.
//
// DESIGN NOTES
// ------------
// * **Keys are hashes of the URL.** Remote URLs contain `/`, `?`, `%`, and
//   quotes (the Wikimedia desi photos genuinely contain `%22`), none of which
//   are safe as filenames — and a raw URL could otherwise escape the cache
//   directory via `../`. Hashing yields a fixed-length, filesystem-safe,
//   traversal-proof name.
//   ⚠️ The hash is hand-rolled (64-bit FNV-1a, below) rather than `sha1` from
//   `package:crypto`, because **crypto is not a direct dependency of this app**
//   — it is only present transitively, and importing it would create a hidden
//   dependency that a future `pub upgrade` could remove without warning. This
//   is a filename, not a security boundary, so a fast non-cryptographic digest
//   is the right tool: a collision would merely serve the wrong cached photo,
//   and at 64 bits over a few hundred entries that is vanishingly unlikely.
// * **Eviction is oldest-first by modification time**, triggered on write when
//   the directory exceeds [maxSizeBytes]. Access does not refresh the mtime
//   (that would mean a write on every read, which is the opposite of what a
//   cache is for), so this is insertion-order LRU — adequate given the whole
//   budget holds far more images than a session touches.
// * **Every method swallows its own errors.** A cache is an optimisation; if
//   the disk is full or a file is corrupt the caller must fall through to the
//   network rather than see an exception. `kDebugMode` logging is the only way
//   to distinguish a real failure from a plain miss — keep those lines.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'image_cache_service.dart';

/// A bounded on-disk image cache using plain files.
class DiskImageCache implements ImageCacheService {
  /// Creates a cache rooted at [directory].
  ///
  /// [directory] is injected rather than resolved internally so tests can point
  /// it at a temp folder — this class stays free of any plugin dependency
  /// (`path_provider` is not in this project), which also keeps it usable in a
  /// plain `flutter test` with no platform channels.
  DiskImageCache({
    required this.directory,
    this.maxSizeBytes = defaultMaxSizeBytes,
  });

  /// Root directory holding the cached files.
  final Directory directory;

  /// Total byte budget for the cache. Writes past this evict oldest-first.
  final int maxSizeBytes;

  /// Default disk budget: **24 MB**.
  ///
  /// Reasoned from measured data, not a round number picked by feel:
  /// TheMealDB photos measure 60–110 KB (≈85 KB average) and Wikimedia
  /// thumbnails ≈68 KB. 24 MB therefore holds roughly 280 images — comfortably
  /// more than the largest realistic working set (the 167-meal Dessert grid,
  /// or a full Home session of ~124 cards), so a normal user never evicts at
  /// all. It is also small enough to be an unremarkable line in Android's
  /// per-app storage breakdown, which matters because the user cannot see or
  /// manage this cache from inside the app.
  static const int defaultMaxSizeBytes = 24 * 1024 * 1024;

  /// Ignore anything implausibly large for a recipe photo. A pathological
  /// response should not be able to consume the entire budget in one entry.
  static const int _maxEntryBytes = 4 * 1024 * 1024;

  /// Filename for [url]: a hash, so the name is fixed-length, filesystem-safe,
  /// and cannot traverse out of the cache directory.
  ///
  /// See the header note on why this is FNV-1a and not `package:crypto`.
  @visibleForTesting
  static String fileNameFor(String url) => '${_fnv1a64(url)}.img';

  /// 64-bit FNV-1a over the UTF-8 bytes of [input], as a fixed 16-char hex
  /// string. Chosen for being tiny, dependency-free, and well-distributed —
  /// this names files, it does not protect anything.
  ///
  /// Dart ints are 64-bit two's-complement and wrap on overflow, which is
  /// exactly the arithmetic FNV-1a expects.
  ///
  /// ⚠️ The result is rendered as two unsigned 32-bit halves rather than via
  /// `hash.toRadixString(16)`. Dart's int is *signed*, so a hash with the top
  /// bit set is a negative number and `toRadixString` emits a leading `-` —
  /// producing filenames like `-4594188e37737c4a.img`. A caught test failure,
  /// not a hypothetical: `toUnsigned(64)` is a no-op on a 64-bit int and does
  /// NOT fix it. Splitting into halves keeps every character hex.
  static String _fnv1a64(String input) {
    // FNV-1a 64-bit offset basis and prime.
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (final int byte in utf8.encode(input)) {
      hash ^= byte;
      hash = hash * prime; // Wraps at 64 bits, as the algorithm intends.
    }
    // Render as two unsigned 32-bit halves so the output is always 16 hex
    // characters with no sign.
    final String high =
        ((hash >> 32) & 0xffffffff).toRadixString(16).padLeft(8, '0');
    final String low = (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return '$high$low';
  }

  @override
  Future<Uint8List?> read(String url) async {
    if (url.isEmpty) return null;
    try {
      final File file = File('${directory.path}/${fileNameFor(url)}');
      if (!await file.exists()) return null;
      final Uint8List bytes = await file.readAsBytes();
      // A zero-length file means an interrupted write. Treat it as a miss and
      // clean it up rather than handing the decoder empty bytes.
      if (bytes.isEmpty) {
        await _deleteQuietly(file);
        return null;
      }
      return bytes;
    } catch (error) {
      if (kDebugMode) debugPrint('DiskImageCache: read failed for $url: $error');
      return null;
    }
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    if (url.isEmpty || bytes.isEmpty || bytes.length > _maxEntryBytes) return;
    try {
      await directory.create(recursive: true);
      final File file = File('${directory.path}/${fileNameFor(url)}');
      // Write to a temp file then rename: a crash mid-write would otherwise
      // leave a truncated file that reads back as a corrupt image.
      final File tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      await _evictIfOverBudget();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('DiskImageCache: write failed for $url: $error');
      }
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('DiskImageCache: clear failed: $error');
    }
  }

  @override
  Future<int> currentSizeBytes() async {
    try {
      final List<_Entry> entries = await _entries();
      return entries.fold<int>(0, (int sum, _Entry e) => sum + e.size);
    } catch (error) {
      if (kDebugMode) debugPrint('DiskImageCache: size failed: $error');
      return 0;
    }
  }

  /// Deletes oldest-first until the directory is back within budget.
  Future<void> _evictIfOverBudget() async {
    try {
      final List<_Entry> entries = await _entries();
      int total = entries.fold<int>(0, (int sum, _Entry e) => sum + e.size);
      if (total <= maxSizeBytes) return;

      // Oldest first.
      entries.sort((_Entry a, _Entry b) => a.modified.compareTo(b.modified));
      for (final _Entry entry in entries) {
        if (total <= maxSizeBytes) break;
        await _deleteQuietly(entry.file);
        total -= entry.size;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('DiskImageCache: eviction failed: $error');
    }
  }

  /// Lists cached entries with their size and mtime. Files that vanish between
  /// listing and stat (a concurrent eviction) are skipped rather than throwing.
  Future<List<_Entry>> _entries() async {
    if (!await directory.exists()) return const <_Entry>[];
    final List<_Entry> entries = <_Entry>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.img')) continue;
      try {
        final FileStat stat = await entity.stat();
        entries.add(_Entry(entity, stat.size, stat.modified));
      } catch (_) {
        // Raced with a delete — ignore.
      }
    }
    return entries;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } catch (_) {
      // Already gone, or not ours to delete. Either way, nothing to do.
    }
  }
}

/// One cached file plus the stats eviction needs.
class _Entry {
  const _Entry(this.file, this.size, this.modified);

  final File file;
  final int size;
  final DateTime modified;
}
