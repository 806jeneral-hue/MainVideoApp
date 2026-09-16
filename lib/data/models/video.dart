import 'dart:io';

/// A single video file discovered on the device.
///
/// [id] is the absolute file path: it stays stable across rescans, which is
/// what favourites, history and playlists are keyed by. [assetId] is the
/// MediaStore id and is only used to pull a thumbnail out of photo_manager.
class Video {
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

  final String id;
  final String assetId;
  final String title;
  final int durationMs;
  final int sizeBytes;
  final DateTime dateAdded;
  final DateTime dateModified;
  final int width;
  final int height;

  String get path => id;

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

  /// `MP4`, `MKV`, ... derived from the extension.
  String get fileType {
    final i = title.lastIndexOf('.');
    if (i < 0 || i == title.length - 1) return 'VIDEO';
    return title.substring(i + 1).toUpperCase();
  }

  /// `1920 x 1080`, or a dash when the scanner could not read it.
  String get resolution => (width > 0 && height > 0) ? '$width x $height' : '—';

  /// Name without the extension, for a cleaner list.
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
