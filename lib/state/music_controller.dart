import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import '../data/models/song.dart';
import '../data/services/music_service.dart';
import '../data/services/permission_service.dart';
import '../data/services/video_file_service.dart' show FileOpResult;

enum MusicStatus { idle, needsPermission, permanentlyDenied, loading, ready }

/// The music library: every song on the device, grouped into albums, artists
/// and folders, plus the listener's favourites, history and playlists.
///
/// Nothing is read until the Music tab is first opened, so launching the app
/// costs no more than before. Every grouping and ordering is worked out once
/// per change and remembered, so scrolling never redoes it.
class MusicController extends ChangeNotifier {
  MusicStatus _status = MusicStatus.idle;
  MusicStatus get status => _status;

  List<Song> _songs = const [];
  Map<String, Song> _byId = const {};

  // ------------------------------------------------------------------ loading
  /// Called when the Music tab is shown. Asks nothing of the user unless the
  /// permission is missing.
  Future<void> ensureLoaded() async {
    if (_status != MusicStatus.idle) return;
    final access = await MusicService.currentAccess();
    if (access == MediaAccess.granted) {
      await _load();
    } else {
      _setStatus(
        access == MediaAccess.permanentlyDenied
            ? MusicStatus.permanentlyDenied
            : MusicStatus.needsPermission,
      );
    }
  }

  Future<void> requestAccess() async {
    final access = await MusicService.requestAccess();
    switch (access) {
      case MediaAccess.granted:
      case MediaAccess.limited:
        await _load();
      case MediaAccess.permanentlyDenied:
        _setStatus(MusicStatus.permanentlyDenied);
      case MediaAccess.denied:
        _setStatus(MusicStatus.needsPermission);
    }
  }

  /// Re-reads MediaStore — one query, cheap enough to run whenever the app
  /// comes back to the foreground.
  Future<void> refresh() async {
    if (_status != MusicStatus.ready) return;
    final songs = await MusicService.querySongs();
    if (songs == null) return;
    _setSongs(songs);
    notifyListeners();
  }

  Future<void> _load() async {
    _setStatus(MusicStatus.loading);
    final songs = await MusicService.querySongs() ?? const <Song>[];
    _setSongs(songs);
    _loadPersonal();
    _status = MusicStatus.ready;
    notifyListeners();
  }

  void _setStatus(MusicStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setSongs(List<Song> songs) {
    _songs = songs;
    _byId = {for (final s in songs) s.id: s};
    _invalidate();
  }

  // -------------------------------------------------------------- the library
  Song? songById(String id) => _byId[id];

  List<Song> get allSongs => _songs;

  SongSort _sort = _readSort();
  bool _descending =
      AppDatabase.settings.get(SettingsKeys.musicSortDescending) as bool? ??
      false;

  SongSort get sort => _sort;
  bool get descending => _descending;

  static SongSort _readSort() {
    final name = AppDatabase.settings.get(SettingsKeys.musicSort) as String?;
    return SongSort.values.firstWhere(
      (s) => s.name == name,
      orElse: () => SongSort.title,
    );
  }

  Future<void> setSort(SongSort sort) async {
    if (sort == _sort) return;
    _sort = sort;
    // Newest first is what anyone sorting by date wants.
    _descending = sort == SongSort.dateAdded;
    _invalidate();
    notifyListeners();
    await AppDatabase.settings.put(SettingsKeys.musicSort, sort.name);
    await AppDatabase.settings.put(
      SettingsKeys.musicSortDescending,
      _descending,
    );
  }

  Future<void> setDescending(bool value) async {
    if (value == _descending) return;
    _descending = value;
    _invalidate();
    notifyListeners();
    await AppDatabase.settings.put(SettingsKeys.musicSortDescending, value);
  }

  List<Song>? _sortedSongs;
  List<Album>? _albums;
  List<Artist>? _artists;
  List<MusicFolder>? _folders;
  final Map<String, _SearchResults> _searchCache = {};

  void _invalidate() {
    _sortedSongs = null;
    _albums = null;
    _artists = null;
    _folders = null;
    _searchCache.clear();
    _favoriteSongs = null;
    _recentSongs = null;
  }

  /// All songs in the chosen order.
  List<Song> get songs => _sortedSongs ??= _sortSongs(_songs);

  List<Song> _sortSongs(List<Song> input) {
    final list = List<Song>.from(input);
    int text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    int byTitle(Song a, Song b) => text(a.title, b.title);

    Comparator<Song> compare = switch (_sort) {
      SongSort.title => byTitle,
      SongSort.artist => (a, b) {
        final c = text(a.artist, b.artist);
        return c != 0 ? c : byTitle(a, b);
      },
      SongSort.album => (a, b) {
        final c = text(a.album, b.album);
        return c != 0 ? c : a.track.compareTo(b.track);
      },
      SongSort.dateAdded => (a, b) => a.dateAdded.compareTo(b.dateAdded),
      SongSort.duration => (a, b) => a.durationMs.compareTo(b.durationMs),
    };
    list.sort(compare);
    return _descending ? list.reversed.toList() : list;
  }

  List<Album> get albums => _albums ??= _buildAlbums(_songs);

  static List<Album> _buildAlbums(List<Song> songs) {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      (groups[song.albumKey] ??= []).add(song);
    }
    final albums = [
      for (final entry in groups.entries)
        Album(
          key: entry.key,
          name: entry.value.first.album,
          artist: _sharedArtist(entry.value),
          songs: entry.value
            ..sort((a, b) {
              final c = a.track.compareTo(b.track);
              return c != 0
                  ? c
                  : a.title.toLowerCase().compareTo(b.title.toLowerCase());
            }),
        ),
    ];
    albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return albums;
  }

  static String _sharedArtist(List<Song> songs) {
    final first = songs.first.artist;
    for (final s in songs) {
      if (s.artist != first) return '';
    }
    return first;
  }

  List<Artist> get artists => _artists ??= _buildArtists();

  List<Artist> _buildArtists() {
    final groups = <String, List<Song>>{};
    for (final song in _songs) {
      (groups[song.artist] ??= []).add(song);
    }
    final artists = [
      for (final entry in groups.entries)
        Artist(
          name: entry.key,
          songs: List<Song>.from(entry.value)
            ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            ),
          albums: _buildAlbums(entry.value),
        ),
    ];
    // Named artists alphabetically; the unnamed bucket last.
    artists.sort((a, b) {
      if (a.name.isEmpty != b.name.isEmpty) return a.name.isEmpty ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return artists;
  }

  List<MusicFolder> get folders => _folders ??= _buildFolders();

  List<MusicFolder> _buildFolders() {
    final groups = <String, List<Song>>{};
    for (final song in _songs) {
      (groups[song.folderPath] ??= []).add(song);
    }
    final folders = [
      for (final entry in groups.entries)
        MusicFolder(
          path: entry.key,
          name: entry.value.first.folderName,
          songs: List<Song>.from(entry.value)
            ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            ),
        ),
    ];
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  Album? albumByKey(String key) {
    for (final album in albums) {
      if (album.key == key) return album;
    }
    return null;
  }

  Artist? artistByName(String name) {
    for (final artist in artists) {
      if (artist.name == name) return artist;
    }
    return null;
  }

  MusicFolder? folderByPath(String path) {
    for (final folder in folders) {
      if (folder.path == path) return folder;
    }
    return null;
  }

  // ------------------------------------------------------------------ delete
  /// Set by the app so a deleted song also leaves the playing queue.
  void Function(String songId)? onSongDeleted;

  /// Deletes [song] from the device and forgets it everywhere: the lists,
  /// favourites and history. Playlists simply stop showing it.
  Future<FileOpResult> deleteSong(Song song) async {
    final result = await MusicFileService.delete(song);
    if (!result.ok) return result;

    _setSongs(_songs.where((s) => s.id != song.id).toList(growable: false));
    _favorites.remove(song.id);
    await AppDatabase.musicFavorites.delete(song.id);
    await AppDatabase.musicHistory.delete(song.id);
    notifyListeners();
    onSongDeleted?.call(song.id);
    return result;
  }

  // ------------------------------------------------------------------- search
  String _query = '';
  String get query => _query;

  void setQuery(String value) {
    final next = value.trim();
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }

  void clearQuery() => setQuery('');

  /// Songs, albums and artists matching the query, in library order.
  ({List<Song> songs, List<Album> albums, List<Artist> artists}) get results {
    final q = _query.toLowerCase();
    final cached = _searchCache[q];
    if (cached != null) return cached.value;

    bool has(String text) => text.toLowerCase().contains(q);
    final value = (
      songs: songs
          .where((s) => has(s.title) || has(s.artist) || has(s.album))
          .toList(growable: false),
      albums: albums
          .where((a) => has(a.name) || has(a.artist))
          .toList(growable: false),
      artists: artists
          .where((a) => a.name.isNotEmpty && has(a.name))
          .toList(growable: false),
    );
    _searchCache[q] = _SearchResults(value);
    return value;
  }

  // --------------------------------------------------------------- favourites
  Set<String> _favorites = {};
  List<Song>? _favoriteSongs;

  bool isFavorite(String songId) => _favorites.contains(songId);

  /// Most recently favourited first.
  List<Song> get favoriteSongs => _favoriteSongs ??= _buildFavorites();

  List<Song> _buildFavorites() {
    final box = AppDatabase.musicFavorites;
    final entries = [
      for (final key in box.keys.cast<String>()) (id: key, at: box.get(key)!),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return [for (final e in entries) ?_byId[e.id]];
  }

  Future<bool> toggleFavorite(String songId) async {
    final box = AppDatabase.musicFavorites;
    final nowFavorite = !_favorites.contains(songId);
    if (nowFavorite) {
      _favorites.add(songId);
      await box.put(songId, DateTime.now().millisecondsSinceEpoch);
    } else {
      _favorites.remove(songId);
      await box.delete(songId);
    }
    _favoriteSongs = null;
    notifyListeners();
    return nowFavorite;
  }

  // ------------------------------------------------------------------ history
  static const int _historyLimit = 200;
  List<Song>? _recentSongs;

  /// Most recently played first.
  List<Song> get recentlyPlayed => _recentSongs ??= _buildRecent();

  List<Song> _buildRecent() {
    final box = AppDatabase.musicHistory;
    final entries = [
      for (final key in box.keys.cast<String>()) (id: key, at: box.get(key)!),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return [for (final e in entries) ?_byId[e.id]];
  }

  Future<void> recordPlayed(String songId) async {
    final box = AppDatabase.musicHistory;
    await box.put(songId, DateTime.now().millisecondsSinceEpoch);
    if (box.length > _historyLimit) {
      final oldest = [
        for (final key in box.keys.cast<String>()) (id: key, at: box.get(key)!),
      ]..sort((a, b) => a.at.compareTo(b.at));
      await box.deleteAll(
        oldest.take(box.length - _historyLimit).map((e) => e.id),
      );
    }
    _recentSongs = null;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await AppDatabase.musicHistory.clear();
    _recentSongs = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- playlists
  List<MusicPlaylist> _playlists = const [];
  List<MusicPlaylist> get playlists => _playlists;

  MusicPlaylist? playlistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Song> songsIn(MusicPlaylist playlist) => [
    for (final id in playlist.songIds) ?_byId[id],
  ];

  Future<MusicPlaylist> createPlaylist(String name) async {
    final playlist = MusicPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      songIds: const [],
      createdAt: DateTime.now(),
    );
    await _savePlaylist(playlist);
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    await _savePlaylist(playlist.copyWith(name: name.trim()));
  }

  Future<void> deletePlaylist(String id) async {
    await AppDatabase.musicPlaylists.delete(id);
    _playlists = _playlists.where((p) => p.id != id).toList(growable: false);
    notifyListeners();
  }

  /// Adds the songs not already in the playlist, keeping their order.
  Future<int> addToPlaylist(String id, List<String> songIds) async {
    final playlist = playlistById(id);
    if (playlist == null) return 0;
    final existing = playlist.songIds.toSet();
    final added = songIds.where(existing.add).toList();
    if (added.isEmpty) return 0;
    await _savePlaylist(
      playlist.copyWith(songIds: [...playlist.songIds, ...added]),
    );
    return added.length;
  }

  Future<void> removeFromPlaylist(String id, String songId) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    await _savePlaylist(
      playlist.copyWith(
        songIds: playlist.songIds.where((s) => s != songId).toList(),
      ),
    );
  }

  Future<void> reorderPlaylist(String id, int oldIndex, int newIndex) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    final ids = List<String>.from(playlist.songIds);
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    await _savePlaylist(playlist.copyWith(songIds: ids));
  }

  Future<void> _savePlaylist(MusicPlaylist playlist) async {
    await AppDatabase.musicPlaylists.put(playlist.id, playlist.toMap());
    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    final next = List<MusicPlaylist>.from(_playlists);
    if (index < 0) {
      next.add(playlist);
    } else {
      next[index] = playlist;
    }
    _playlists = next;
    notifyListeners();
  }

  // ---------------------------------------------------------------- personal
  void _loadPersonal() {
    _favorites = AppDatabase.musicFavorites.keys.cast<String>().toSet();
    _playlists = [
      for (final raw in AppDatabase.musicPlaylists.values)
        MusicPlaylist.fromMap(raw),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _favoriteSongs = null;
    _recentSongs = null;
  }
}

/// Wraps a record so it can sit in a map without a typedef.
class _SearchResults {
  const _SearchResults(this.value);

  final ({List<Song> songs, List<Album> albums, List<Artist> artists}) value;
}
