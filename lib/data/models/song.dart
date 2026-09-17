import 'dart:io';

import 'playable.dart';

/// One song, as MediaStore describes it.
///
/// Like a video, [id] is the absolute path, so favourites, history and
/// playlists keep pointing at the same file across rescans.
class Song implements Playable {
  const Song({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAdded,
    required this.track,
    required this.year,
  });

  @override
  final String id;

  /// MediaStore's id for the file.
  final int mediaId;

  final String title;

  /// Empty when the file does not say.
  final String artist;
  final String album;
  final int albumId;

  @override
  final int durationMs;
  final int sizeBytes;
  final DateTime dateAdded;

  /// Position on the album; MediaStore may fold the disc number in as
  /// thousands (2003 is disc 2, track 3), which still sorts correctly.
  final int track;
  final int year;

  /// MediaStore fills gaps with this placeholder.
  static const String _unknown = '<unknown>';

  factory Song.fromMap(Map<dynamic, dynamic> map) {
    String text(String key) {
      final value = (map[key] as String? ?? '').trim();
      return value == _unknown ? '' : value;
    }

    final path = map['path'] as String;
    final title = text('title');
    return Song(
      id: path,
      mediaId: (map['mediaId'] as num?)?.toInt() ?? 0,
      title: title.isEmpty ? _fileName(path) : title,
      artist: text('artist'),
      album: text('album'),
      albumId: (map['albumId'] as num?)?.toInt() ?? -1,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        ((map['dateAddedSec'] as num?)?.toInt() ?? 0) * 1000,
      ),
      track: (map['track'] as num?)?.toInt() ?? 0,
      year: (map['year'] as num?)?.toInt() ?? 0,
    );
  }

  static String _fileName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  String get path => id;

  @override
  String get displayName => title;

  @override
  String get subtitle => artist;

  @override
  bool get isAudio => true;

  /// Absolute path of the directory holding the file.
  String get folderPath {
    final i = id.lastIndexOf(Platform.pathSeparator);
    return i <= 0 ? id : id.substring(0, i);
  }

  String get folderName {
    final p = folderPath;
    final i = p.lastIndexOf(Platform.pathSeparator);
    return i < 0 ? p : p.substring(i + 1);
  }

  /// Groups songs into albums: the same album name by different artists is
  /// still one album when MediaStore gives it one id.
  String get albumKey => albumId >= 0 ? 'id:$albumId' : 'name:$album|$artist';

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Songs sharing an album.
class Album {
  const Album({
    required this.key,
    required this.name,
    required this.artist,
    required this.songs,
  });

  final String key;
  final String name;

  /// The album's artist, or empty when its songs disagree or do not say.
  final String artist;

  /// In track order.
  final List<Song> songs;

  /// The song whose cover stands for the album.
  Song get cover => songs.first;

  int get year => songs.fold(0, (y, s) => s.year > y ? s.year : y);
}

/// Songs by one artist, with the albums they appear on.
class Artist {
  const Artist({required this.name, required this.songs, required this.albums});

  final String name;
  final List<Song> songs;
  final List<Album> albums;
}

/// Songs in one directory.
class MusicFolder {
  const MusicFolder({
    required this.path,
    required this.name,
    required this.songs,
  });

  final String path;
  final String name;
  final List<Song> songs;
}

/// A playlist of songs, kept apart from video playlists.
class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;

  MusicPlaylist copyWith({String? name, List<String>? songIds}) =>
      MusicPlaylist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
        createdAt: createdAt,
      );

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory MusicPlaylist.fromMap(Map<dynamic, dynamic> map) => MusicPlaylist(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    songIds: (map['songIds'] as List? ?? const []).cast<String>().toList(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as num?)?.toInt() ?? 0,
    ),
  );
}

/// How the song list is ordered.
enum SongSort { title, artist, album, dateAdded, duration }
