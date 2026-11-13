import 'dart:io';

import 'song.dart';

export 'playable.dart';

/// A single video file discovered on the device.
///
/// [id] is the absolute file path: it stays stable across rescans, which is
/// what favourites, history and playlists are keyed by. [assetId] is the
/// MediaStore id and is only used to pull a thumbnail out of photo_manager.
class Video implements Playable {
  const Video({
    required this.id,
    required this.assetId,
    required this.title,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAdded,
    required this.dateModified,
    required this.width,
    required this.height,
  });

  factory Video.fromSong(Song song) => Video(
    id: song.id,
    assetId: '${song.mediaId}',
    title: song.title.isNotEmpty ? song.title : song.displayName,
    durationMs: song.durationMs,
    sizeBytes: song.sizeBytes,
    dateAdded: song.dateAdded,
    dateModified: song.dateAdded,
    width: 0,
    height: 0,
  );

  factory Video.fromPath(String path, {String? title, int? sizeBytes}) {
    final file = File(path);
    final fileName =
        title ??
        (path.split(Platform.pathSeparator).isNotEmpty
            ? path.split(Platform.pathSeparator).last
            : path);
    final length = sizeBytes ?? (file.existsSync() ? file.lengthSync() : 0);
    final now = DateTime.now();
    return Video(
      id: path,
      assetId: path,
      title: fileName,
      durationMs: 0,
      sizeBytes: length,
      dateAdded: now,
      dateModified: now,
      width: 1920,
      height: 1080,
    );
  }

  @override
  final String id;
  final String assetId;
  final String title;
  @override
  final int durationMs;
  final int sizeBytes;
  final DateTime dateAdded;
  final DateTime dateModified;
  final int width;
  final int height;

  @override
  String get path => id;

  @override
  String get subtitle => folderName;

  @override
  bool get isAudio {
    final lower = id.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus') ||
        (!isArchive && width == 0 && height == 0);
  }

  /// Whether the file is a compressed archive containing media (.zip, .rar, .7z, etc.).
  bool get isArchive {
    final lower = id.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.bz2') ||
        lower.endsWith('.xz');
  }

  Duration get duration => Duration(milliseconds: durationMs);

  /// Absolute path of the directory holding the file.
  String get folderPath {
    final i = id.lastIndexOf(Platform.pathSeparator);
    if (i <= 0) return id;
    return id.substring(0, i);
  }

  /// Just the directory name, e.g. `Camera`.
  String get folderName {
    final p = folderPath;
    final i = p.lastIndexOf(Platform.pathSeparator);
    return i < 0 ? p : p.substring(i + 1);
  }

  /// `MP4`, `MKV`, `ZIP`, `RAR` ... derived from the extension.
  String get fileType {
    final i = title.lastIndexOf('.');
    if (i < 0 || i == title.length - 1) {
      return isArchive ? 'ZIP' : 'VIDEO';
    }
    return title.substring(i + 1).toUpperCase();
  }

  /// `1920 x 1080`, or a dash when the scanner could not read it.
  String get resolution => (width > 0 && height > 0) ? '$width x $height' : '—';

  /// Name without the extension, for a cleaner list.
  @override
  String get displayName {
    final i = title.lastIndexOf('.');
    return i > 0 ? title.substring(0, i) : title;
  }

  Video copyWith({String? id, String? title}) => Video(
    id: id ?? this.id,
    assetId: assetId,
    title: title ?? this.title,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    dateAdded: dateAdded,
    dateModified: dateModified,
    width: width,
    height: height,
  );

  @override
  bool operator ==(Object other) => other is Video && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
