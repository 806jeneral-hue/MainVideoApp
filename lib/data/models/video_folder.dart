import 'dart:io';

import 'video.dart';

/// A real device folder that contains at least one video.
class VideoFolder {
  const VideoFolder({required this.path, required this.videos});

  final String path;
  final List<Video> videos;

  int get count => videos.length;

  String get name {
    final i = path.lastIndexOf(Platform.pathSeparator);
    final last = i < 0 ? path : path.substring(i + 1);
    return last.isEmpty ? path : last;
  }

  /// Newest `dateAdded` in the folder, used for sorting the folder list.
  DateTime get lastAdded {
    DateTime newest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final v in videos) {
      if (v.dateAdded.isAfter(newest)) newest = v.dateAdded;
    }
    return newest;
  }

  int get totalSizeBytes => videos.fold(0, (sum, v) => sum + v.sizeBytes);
}
