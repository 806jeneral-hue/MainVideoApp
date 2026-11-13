import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Auto-generated video thumbnails (phase 1), served from two layers of cache:
/// a small in-memory LRU for the rows on screen, and a folder on disk so a
/// thumbnail is only ever decoded from the video once, not on every launch.
class ThumbnailService {
  const ThumbnailService._();

  static const int _maxEntries = 700;

  /// Thumbnails are decoded natively, one platform call each. Flinging a long
  /// grid would otherwise queue hundreds at once and starve the channel the
  /// visible rows are waiting on, so only a few run at a time.
  static const int _maxConcurrent = 4;

  /// Disk cache is trimmed once it grows past this.
  static const int _maxDiskBytes = 64 * 1024 * 1024;

  /// Brightness below this threshold (0..255 scale) is considered "almost black".
  static const double blackThreshold = 18.0;

  /// Max value for signed 32-bit int. Glide/photo_manager casts 'frame' as Int
  /// over the platform channel, so timestamps in microseconds must not exceed this.
  static const int maxFrameMicros = 2147483647;

  static final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Directory? _diskDir;
  static bool _diskReady = false;

  static int _running = 0;
  static final List<Completer<void>> _waiting = [];

  /// Prepares the on-disk cache. Safe to call more than once.
  static Future<void> init() async {
    if (_diskReady) return;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}thumbs');
      if (!await dir.exists()) await dir.create(recursive: true);
      _diskDir = dir;
    } catch (_) {
      _diskDir = null;
    }
    _diskReady = true;
  }

  static Uint8List? peek(String assetId, int width, int height) =>
      _cache[_key(assetId, width, height)];

  static Future<Uint8List?> load(
    String assetId, {
    int width = 320,
    int height = 320,
    int? durationMs,
  }) {
    final key = _key(assetId, width, height);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);

    return _inFlight.putIfAbsent(key, () async {
      // Disk first: far cheaper than asking the platform to decode a frame.
      final fromDisk = await _readDisk(key);
      if (fromDisk != null) {
        _put(key, fromDisk);
        _inFlight.remove(key);
        return fromDisk;
      }

      await _acquire();
      Uint8List? bytes;
      try {
        final asset = await AssetEntity.fromId(assetId);
        if (asset != null) {
          bytes = await _generateRepresentativeThumbnail(
            asset,
            width: width,
            height: height,
            durationMs: durationMs,
          );
        }
      } catch (_) {
        bytes = null;
      } finally {
        _release();
      }

      if (bytes != null) unawaited(_writeDisk(key, bytes));
      _put(key, bytes);
      _inFlight.remove(key);
      return bytes;
    });
  }

  /// Calculates candidate timestamps (in ms) to sample: starts around 10%
  /// of the video, falling back to 25%, 50%, and 75% if earlier frames are black.
  static List<int> getCandidateTimestampsMs(int totalDurationMs) {
    if (totalDurationMs > 0) {
      return [
        (totalDurationMs * 0.10).round(),
        (totalDurationMs * 0.25).round(),
        (totalDurationMs * 0.50).round(),
        (totalDurationMs * 0.75).round(),
      ];
    }
    return const [1000, 3000, 5000, 0];
  }

  /// Decodes and selects a representative thumbnail frame, avoiding black intro frames.
  static Future<Uint8List?> _generateRepresentativeThumbnail(
    AssetEntity asset, {
    required int width,
    required int height,
    int? durationMs,
  }) async {
    final totalDurationMs = (durationMs != null && durationMs > 0)
        ? durationMs
        : (asset.duration * 1000);

    final candidateMs = getCandidateTimestampsMs(totalDurationMs);

    Uint8List? bestBytes;
    double bestBrightness = -1.0;

    for (final ms in candidateMs) {
      final frameMicros = (ms * 1000).clamp(0, maxFrameMicros);
      try {
        final bytes = await asset.thumbnailDataWithSize(
          ThumbnailSize(width, height),
          quality: 80,
          frame: frameMicros,
        );
        if (bytes == null || bytes.isEmpty) continue;

        final brightness = await calculateAverageBrightness(bytes);
        // Non-black frame found: return immediately (avoids extra decodes).
        if (brightness >= blackThreshold) {
          return bytes;
        }

        // Keep the brightest candidate in case all tested frames are dark.
        if (brightness > bestBrightness) {
          bestBrightness = brightness;
          bestBytes = bytes;
        }
      } catch (_) {
        // Continue to next candidate on decoding error.
      }
    }

    return bestBytes;
  }

  /// Calculates the average perceived luminance of [bytes] on a scale of 0.0 to 255.0.
  /// Downscales to 32x32 during decode to evaluate 1,024 pixels in < 1ms.
  static Future<double> calculateAverageBrightness(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frameInfo = await codec.getNextFrame();
      image = frameInfo.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return 0.0;

      final buffer = byteData.buffer.asUint8List();
      final length = buffer.length;
      if (length < 4) return 0.0;

      int totalLuminance = 0;
      final pixelCount = length ~/ 4;

      for (var i = 0; i < length; i += 4) {
        final r = buffer[i];
        final g = buffer[i + 1];
        final b = buffer[i + 2];
        // Standard perceived luminance formula (ITU-R BT.601)
        totalLuminance += (299 * r + 587 * g + 114 * b) ~/ 1000;
      }

      return totalLuminance / pixelCount;
    } catch (_) {
      return 0.0;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  // ------------------------------------------------------------- disk layer
  static File? _fileFor(String key) {
    final dir = _diskDir;
    if (dir == null) return null;
    // The key contains a file path, so it is hashed into a safe short name.
    final name = md5.convert(utf8.encode(key)).toString();
    return File('${dir.path}${Platform.pathSeparator}$name.jpg');
  }

  static Future<Uint8List?> _readDisk(String key) async {
    try {
      final file = _fileFor(key);
      if (file == null || !await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDisk(String key, Uint8List bytes) async {
    try {
      await _fileFor(key)?.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // A full or unwritable cache directory is not worth failing over.
    }
  }

  /// Drops the oldest files once the cache outgrows [_maxDiskBytes].
  static Future<void> trimDisk() async {
    final dir = _diskDir;
    if (dir == null) return;
    try {
      final files = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        total += stat.size;
        files.add((file: entity, size: stat.size, modified: stat.modified));
      }
      if (total <= _maxDiskBytes) return;

      files.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in files) {
        if (total <= _maxDiskBytes) break;
        try {
          await entry.file.delete();
          total -= entry.size;
        } catch (_) {
          // Skip whatever refuses to go.
        }
      }
    } catch (_) {
      // Listing failed; nothing to trim.
    }
  }

  static Future<void> clearDisk() async {
    final dir = _diskDir;
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (_) {
      // Nothing to clear.
    }
  }

  // ---------------------------------------------------------------- plumbing
  static Future<void> _acquire() {
    if (_running < _maxConcurrent) {
      _running++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  static void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
      return;
    }
    _running--;
  }

  static void _put(String key, Uint8List? bytes) {
    _cache.remove(key);
    _cache[key] = bytes;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  static String _key(String assetId, int w, int h) => 'v2_$assetId@${w}x$h';

  /// Forgets in-memory entries only; the disk cache is the whole point and is
  /// kept unless [clearDisk] is called explicitly.
  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
