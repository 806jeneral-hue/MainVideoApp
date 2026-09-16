import '../local/app_database.dart';
import '../models/playlist.dart';

/// Manually created playlists (phase 3).
class PlaylistRepository {
  const PlaylistRepository();

  /// Pinned playlists first, then newest, so a pin is visible immediately.
  List<Playlist> all() {
    final list = AppDatabase.playlists.values.map(Playlist.fromMap).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  Playlist? byId(String id) {
    final map = AppDatabase.playlists.get(id);
    return map == null ? null : Playlist.fromMap(map);
  }

  Future<Playlist> create(
    String name, {
    List<String> videoIds = const [],
  }) async {
    final playlist = Playlist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Untitled' : name.trim(),
      videoIds: List<String>.from(videoIds),
      createdAt: DateTime.now(),
    );
    await AppDatabase.playlists.put(playlist.id, playlist.toMap());
    return playlist;
  }

  Future<void> save(Playlist playlist) =>
      AppDatabase.playlists.put(playlist.id, playlist.toMap());

  Future<void> rename(String id, String name) async {
    final playlist = byId(id);
    if (playlist == null) return;
    await save(playlist.copyWith(name: name.trim()));
  }

  Future<void> delete(String id) => AppDatabase.playlists.delete(id);

  Future<void> addVideos(String id, Iterable<String> videoIds) async {
    final playlist = byId(id);
    if (playlist == null) return;
    final ids = List<String>.from(playlist.videoIds);
    for (final videoId in videoIds) {
      if (!ids.contains(videoId)) ids.add(videoId);
    }
    await save(playlist.copyWith(videoIds: ids));
  }

  Future<void> removeVideo(String id, String videoId) =>
      removeVideos(id, [videoId]);

  Future<void> removeVideos(String id, Iterable<String> videoIds) async {
    final playlist = byId(id);
    if (playlist == null) return;
    final drop = videoIds.toSet();
    final ids = playlist.videoIds.where((v) => !drop.contains(v)).toList();
    await save(playlist.copyWith(videoIds: ids));
  }

  Future<void> setStyle(
    String id, {
    int? colorValue,
    String? iconKey,
    bool clearColor = false,
    bool clearIcon = false,
  }) async {
    final playlist = byId(id);
    if (playlist == null) return;
    await save(
      playlist.copyWith(
        colorValue: colorValue,
        iconKey: iconKey,
        clearColor: clearColor,
        clearIcon: clearIcon,
      ),
    );
  }

  Future<void> setPinned(String id, bool pinned) async {
    final playlist = byId(id);
    if (playlist == null) return;
    await save(playlist.copyWith(pinned: pinned));
  }

  /// Drops a deleted file from every playlist that referenced it.
  Future<void> purgeVideo(String videoId) async {
    for (final playlist in all()) {
      if (playlist.videoIds.contains(videoId)) {
        await removeVideo(playlist.id, videoId);
      }
    }
  }

  /// Keeps playlists pointing at the right file after a rename.
  Future<void> rekey(String oldId, String newId) async {
    for (final playlist in all()) {
      final index = playlist.videoIds.indexOf(oldId);
      if (index < 0) continue;
      final ids = List<String>.from(playlist.videoIds);
      ids[index] = newId;
      await save(playlist.copyWith(videoIds: ids));
    }
  }
}
