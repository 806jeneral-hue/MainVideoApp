import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/data/models/playlist.dart';
import 'package:main_video/data/models/video.dart';
import 'package:main_video/data/models/video_folder.dart';
import 'package:main_video/data/models/watch_record.dart';

Video makeVideo({
  required String path,
  String? title,
  int durationMs = 60000,
  int sizeBytes = 1024,
  int width = 1920,
  int height = 1080,
}) {
  final sep = Platform.pathSeparator;
  return Video(
    id: path,
    assetId: 'asset-$path',
    title: title ?? path.split(sep).last,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    dateAdded: DateTime(2025, 1, 1),
    dateModified: DateTime(2025, 1, 2),
    width: width,
    height: height,
  );
}

String p(List<String> parts) => parts.join(Platform.pathSeparator);

void main() {
  group('Video', () {
    test('splits the parent folder out of the path', () {
      final video = makeVideo(path: p(['storage', 'DCIM', 'Camera', 'a.mp4']));
      expect(video.folderName, 'Camera');
      expect(video.folderPath, p(['storage', 'DCIM', 'Camera']));
    });

    test('exposes the extension as the file type', () {
      expect(makeVideo(path: 'a.mkv').fileType, 'MKV');
      expect(makeVideo(path: 'noextension').fileType, 'VIDEO');
    });

    test('strips the extension for display', () {
      expect(makeVideo(path: 'Holiday clip.mp4').displayName, 'Holiday clip');
      expect(makeVideo(path: 'noextension').displayName, 'noextension');
    });

    test('reports resolution, falling back when it is unknown', () {
      expect(makeVideo(path: 'a.mp4').resolution, '1920 x 1080');
      expect(makeVideo(path: 'a.mp4', width: 0, height: 0).resolution, '—');
    });

    test('identity is the file path', () {
      expect(makeVideo(path: 'a.mp4'), makeVideo(path: 'a.mp4'));
      expect(makeVideo(path: 'a.mp4') == makeVideo(path: 'b.mp4'), isFalse);
    });
  });

  group('VideoFolder', () {
    test('sums sizes and finds the newest entry', () {
      final folder = VideoFolder(
        path: p(['storage', 'Movies']),
        videos: [
          makeVideo(path: 'a.mp4', sizeBytes: 100),
          makeVideo(path: 'b.mp4', sizeBytes: 250),
        ],
      );
      expect(folder.name, 'Movies');
      expect(folder.count, 2);
      expect(folder.totalSizeBytes, 350);
      expect(folder.lastAdded, DateTime(2025, 1, 1));
    });
  });

  group('WatchRecord', () {
    test('computes progress and clamps it', () {
      final record = WatchRecord(
        videoId: 'a.mp4',
        positionMs: 30000,
        durationMs: 60000,
        lastPlayed: DateTime(2025, 1, 1),
      );
      expect(record.progress, 0.5);
      expect(record.isFinished, isFalse);
    });

    test('treats the last few seconds as finished', () {
      final record = WatchRecord(
        videoId: 'a.mp4',
        positionMs: 59000,
        durationMs: 60000,
        lastPlayed: DateTime(2025, 1, 1),
      );
      expect(record.isFinished, isTrue);
    });

    test('survives a round trip through storage', () {
      final record = WatchRecord(
        videoId: 'a.mp4',
        positionMs: 1234,
        durationMs: 5678,
        lastPlayed: DateTime(2025, 3, 4, 5, 6),
      );
      final restored = WatchRecord.fromMap(record.toMap());
      expect(restored.videoId, record.videoId);
      expect(restored.positionMs, record.positionMs);
      expect(restored.durationMs, record.durationMs);
      expect(restored.lastPlayed, record.lastPlayed);
    });
  });

  group('Playlist', () {
    test('survives a round trip through storage', () {
      final playlist = Playlist(
        id: 'pl_1',
        name: 'Trip',
        videoIds: const ['a.mp4', 'b.mp4'],
        createdAt: DateTime(2025, 2, 2),
      );
      final restored = Playlist.fromMap(playlist.toMap());
      expect(restored.id, 'pl_1');
      expect(restored.name, 'Trip');
      expect(restored.videoIds, ['a.mp4', 'b.mp4']);
      expect(restored.count, 2);
      expect(restored.createdAt, DateTime(2025, 2, 2));
    });

    test('falls back sensibly on a malformed record', () {
      final restored = Playlist.fromMap({'id': 'pl_2'});
      expect(restored.name, 'Playlist');
      expect(restored.videoIds, isEmpty);
    });
  });
}
