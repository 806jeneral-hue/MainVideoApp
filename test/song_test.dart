import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/data/models/playable.dart';
import 'package:main_video/data/models/song.dart';

Map<String, Object?> songMap({
  String path = '/music/Artist/song.mp3',
  String title = 'A Song',
  String artist = 'Artist',
  String album = 'Album',
  int albumId = 7,
}) => {
  'mediaId': 42,
  'path': path,
  'title': title,
  'artist': artist,
  'album': album,
  'albumId': albumId,
  'durationMs': 215000,
  'sizeBytes': 5000000,
  'dateAddedSec': 1700000000,
  'track': 3,
  'year': 2020,
};

void main() {
  group('Song.fromMap', () {
    test('reads every field MediaStore sends', () {
      final song = Song.fromMap(songMap());
      expect(song.id, '/music/Artist/song.mp3');
      expect(song.path, song.id);
      expect(song.mediaId, 42);
      expect(song.title, 'A Song');
      expect(song.artist, 'Artist');
      expect(song.album, 'Album');
      expect(song.albumId, 7);
      expect(song.durationMs, 215000);
      expect(song.track, 3);
      expect(song.year, 2020);
      expect(
        song.dateAdded,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
    });

    test("turns MediaStore's <unknown> placeholder into an empty artist", () {
      final song = Song.fromMap(
        songMap(artist: '<unknown>', album: '<unknown>'),
      );
      expect(song.artist, isEmpty);
      expect(song.album, isEmpty);
    });

    test('falls back to the file name when there is no title', () {
      final sep = Platform.pathSeparator;
      final song = Song.fromMap(
        songMap(path: '${sep}music${sep}Track Name.flac', title: ''),
      );
      expect(song.title, 'Track Name');
    });

    test('is played as audio, with the artist as its second line', () {
      final Playable song = Song.fromMap(songMap());
      expect(song.isAudio, isTrue);
      expect(song.displayName, 'A Song');
      expect(song.subtitle, 'Artist');
    });
  });

  group('Song grouping', () {
    test('songs sharing an album id share an album key', () {
      final a = Song.fromMap(songMap(path: '/m/a.mp3', albumId: 9));
      final b = Song.fromMap(songMap(path: '/m/b.mp3', albumId: 9));
      final c = Song.fromMap(songMap(path: '/m/c.mp3', albumId: 10));
      expect(a.albumKey, b.albumKey);
      expect(a.albumKey, isNot(c.albumKey));
    });

    test('equality follows the path', () {
      final a = Song.fromMap(songMap(path: '/m/a.mp3', title: 'One'));
      final b = Song.fromMap(songMap(path: '/m/a.mp3', title: 'Two'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('MusicPlaylist', () {
    test('survives a round trip through storage', () {
      final playlist = MusicPlaylist(
        id: 'p1',
        name: 'Road trip',
        songIds: const ['/m/a.mp3', '/m/b.mp3'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final restored = MusicPlaylist.fromMap(playlist.toMap());
      expect(restored.id, 'p1');
      expect(restored.name, 'Road trip');
      expect(restored.songIds, ['/m/a.mp3', '/m/b.mp3']);
      expect(restored.createdAt, playlist.createdAt);
    });
  });

  group('Music strings', () {
    test('count songs with Arabic plural forms', () {
      const ar = StringsAr();
      expect(ar.songCount(1), 'أغنية واحدة');
      expect(ar.songCount(2), 'أغنيتان');
      expect(ar.songCount(5), '5 أغاني');
      expect(ar.songCount(25), '25 أغنية');
    });

    test('count songs in English', () {
      const en = StringsEn();
      expect(en.songCount(1), '1 song');
      expect(en.songCount(12), '12 songs');
    });
  });
}
