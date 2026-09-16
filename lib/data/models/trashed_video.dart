/// A video sitting in the recycle bin.
///
/// The file itself has been moved into the app's private storage, so it is no
/// longer visible to the gallery or to any other app, but it is still on the
/// device and can be put back exactly where it came from.
class TrashedVideo {
  const TrashedVideo({
    required this.id,
    required this.originalPath,
    required this.binPath,
    required this.title,
    required this.durationMs,
    required this.sizeBytes,
    required this.deletedAt,
  });

  /// The path the video had before it was deleted — also its library id.
  final String id;
  final String originalPath;

  /// Where the file lives now, inside the app's own folder.
  final String binPath;

  final String title;
  final int durationMs;
  final int sizeBytes;
  final DateTime deletedAt;

  String get displayName {
    final dot = title.lastIndexOf('.');
    return dot <= 0 ? title : title.substring(0, dot);
  }

  /// The folder it will go back to.
  String get originalFolder {
    final i = originalPath.lastIndexOf(RegExp(r'[\\/]'));
    return i <= 0 ? originalPath : originalPath.substring(0, i);
  }

  int daysLeft(int keepDays) {
    final gone = DateTime.now().difference(deletedAt).inDays;
    final left = keepDays - gone;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'originalPath': originalPath,
    'binPath': binPath,
    'title': title,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'deletedAt': deletedAt.millisecondsSinceEpoch,
  };

  factory TrashedVideo.fromMap(Map<dynamic, dynamic> map) => TrashedVideo(
    id: map['id'] as String,
    originalPath: map['originalPath'] as String? ?? map['id'] as String,
    binPath: map['binPath'] as String? ?? '',
    title: map['title'] as String? ?? '',
    durationMs: map['durationMs'] as int? ?? 0,
    sizeBytes: map['sizeBytes'] as int? ?? 0,
    deletedAt: DateTime.fromMillisecondsSinceEpoch(
      map['deletedAt'] as int? ?? 0,
    ),
  );
}
