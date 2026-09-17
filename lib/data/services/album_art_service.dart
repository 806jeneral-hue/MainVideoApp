import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import 'music_service.dart';

/// Album covers, cached the same way as video thumbnails: a small in-memory
/// LRU for what is on screen and a folder on disk, so each cover is read out
/// of MediaStore or the file only once.
///
/// Songs on the same album share one cover, and an album with no cover is
/// remembered as such, so it is not looked for again on every launch.
class AlbumArtService {
  const AlbumArtService._();

  static const int _maxEntries = 240;
  static const int _maxConcurrent = 3;

  static final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Directory? _diskDir;
  static bool _diskReady = false;

  static int _running = 0;
  static final List<Completer<void>> _waiting = [];

  static Future<void> _ensureDisk() async {
    if (_diskReady) return;
    _diskReady = true;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}album_art');
      if (!await dir.exists()) await dir.create(recursive: true);
      _diskDir = dir;
    } catch (_) {
      _diskDir = null;
    }
  }

  static String _key(Song song, int size) => '${song.albumKey}@$size';

  /// Already-loaded cover, so a row scrolling back into view paints at once.
  /// The outer null means "not loaded yet".
  static (Uint8List?,)? peek(Song song, int size) {
    final key = _key(song, size);
    if (!_cache.containsKey(key)) return null;
    return (_cache[key],);
  }

  static Future<Uint8List?> load(Song song, {int size = 300}) {
    final key = _key(song, size);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);

    return _inFlight.putIfAbsent(key, () async {
      await _ensureDisk();
      final file = _fileFor(key);

      // On disk: an empty file means "this album has no cover".
      if (file != null) {
        try {
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final result = bytes.isEmpty ? null : bytes;
            _put(key, result);
            _inFlight.remove(key);
            return result;
          }
        } catch (_) {
          // Fall through to reading it again.
        }
      }

      await _acquire();
      Uint8List? bytes;
      try {
        bytes = await MusicService.albumArt(song, size: size);
      } finally {
        _release();
      }

      if (file != null) {
        unawaited(
          file
              .writeAsBytes(bytes ?? Uint8List(0), flush: false)
              .then((_) {}, onError: (_) {}),
        );
      }
      _put(key, bytes);
      _inFlight.remove(key);
      return bytes;
    });
  }

  static File? _fileFor(String key) {
    final dir = _diskDir;
    if (dir == null) return null;
    final name = md5.convert(utf8.encode(key)).toString();
    return File('${dir.path}${Platform.pathSeparator}$name.jpg');
  }

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
}
