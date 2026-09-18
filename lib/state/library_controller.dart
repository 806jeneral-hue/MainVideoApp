// Dart forbids named parameters that start with an underscore, so the
// dependencies below cannot be written as initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/collection_prefs.dart';
import '../data/models/enums.dart';
import '../data/models/playlist.dart';
import '../data/models/video.dart';
import '../data/models/video_folder.dart';
import '../data/models/watch_record.dart';
import '../data/repositories/collection_prefs_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/models/trashed_video.dart';
import '../data/repositories/playlist_repository.dart';
import '../data/repositories/recycle_bin_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/media_scanner.dart';
import '../data/services/permission_service.dart';
import '../data/services/thumbnail_service.dart';
import '../data/services/video_file_service.dart';

enum LibraryStatus { idle, permissionRequired, scanning, ready, denied }

/// The single source of truth for the video library: what is on the device,
/// how each list is filtered, sorted and pinned, and every change the user
/// makes to it.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required SettingsRepository settings,
    required FavoritesRepository favorites,
    required HistoryRepository history,
    required PlaylistRepository playlists,
    required CollectionPrefsRepository collectionPrefs,
  }) : _settings = settings,
       _favorites = favorites,
       _history = history,
       _playlists = playlists,
       _prefs = collectionPrefs {
    _viewMode = _settings.viewMode;
    // Folders keep their own layout; the first time, they follow the videos.
    _foldersAsGrid = _settings.folderGrid ?? (_viewMode == ViewMode.grid);
    _scanFolders = _settings.scanFolders;
    _hiddenFolders = _settings.hiddenFolders;
    _pinnedVideos = _settings.pinnedVideos.toSet();
    _hiddenVideos = _settings.hiddenVideos.toSet();
    _pinnedFolders = _settings.pinnedFolders.toSet();
    _prefsCache = _prefs.all();
  }

  final SettingsRepository _settings;
  final FavoritesRepository _favorites;
  final HistoryRepository _history;
  final PlaylistRepository _playlists;
  final CollectionPrefsRepository _prefs;

  /// Lets the playback session follow a video that was renamed, or close
  /// itself when the file it was playing is deleted.
  void Function(String oldId, Video? replacement)? onVideoChanged;

  LibraryStatus _status = LibraryStatus.idle;
  String _scanMessage = '';
  double _scanProgress = 0;

  /// True for the whole scan, even after the first videos are on screen.
  bool _scanning = false;

  List<Video> _allVideos = const [];
  Map<String, Video> _byId = const {};
  Set<String> _favoriteIds = const {};
  // Mutable on purpose: the player patches single entries as a video plays.
  Map<String, WatchRecord> _historyById = <String, WatchRecord>{};
  List<Playlist> _playlistCache = const [];
  Map<String, CollectionPrefs> _prefsCache = const {};

  List<String> _scanFolders = const [];
  List<String> _hiddenFolders = const [];
  Set<String> _pinnedVideos = const {};
  Set<String> _pinnedFolders = const {};

  ViewMode _viewMode = ViewMode.list;
  String _query = '';

  // ------------------------------------------------------------------- status
  LibraryStatus get status => _status;
  String get scanMessage => _scanMessage;
  double get scanProgress => _scanProgress;

  /// Still reading the device. The list may already be showing what was found
  /// so far, so this drives a subtle indicator rather than a full-screen one.
  bool get isScanning => _scanning;

  // ---------------------------------------------------------------- selectors
  List<Video> get allVideos => _allVideos;

  ViewMode get viewMode => _viewMode;
  String get query => _query;

  List<String> get scanFolders => _scanFolders;
  List<String> get hiddenFolders => _hiddenFolders;

  Video? videoById(String id) => _byId[id];

  bool isFavorite(String id) => _favoriteIds.contains(id);

  WatchRecord? historyFor(String id) => _historyById[id];

  int resumePositionMs(String id) {
    final record = _historyById[id];
    if (record == null || record.isFinished) return 0;
    return record.positionMs;
  }

  // Derived lists are read on every rebuild of a screen, so they are memoised
  // and dropped by [_invalidate] — a notification from, say, a resume-position
  // save must not re-sort the whole library on four different screens.
  List<Video>? _visibleCache;
  List<Video>? _homeCache;
  List<Video>? _favoritesCache;
  List<Video>? _recentlyAddedCache;
  List<Video>? _recentlyPlayedCache;
  List<VideoFolder>? _foldersCache;
  List<VideoFolder>? _allFoldersCache;
  final Map<String, List<Video>> _collectionCache = {};

  void _invalidate() {
    _visibleCache = null;
    _homeCache = null;
    _favoritesCache = null;
    _recentlyAddedCache = null;
    _recentlyPlayedCache = null;
    _foldersCache = null;
    _allFoldersCache = null;
    _collectionCache.clear();
  }

  /// Videos left after the scan-folder allow-list and the hidden-folder list.
  List<Video> get visibleVideos => _visibleCache ??= _computeVisible();

  List<Video> _computeVisible() {
    if (_scanFolders.isEmpty &&
        _hiddenFolders.isEmpty &&
        _hiddenVideos.isEmpty) {
      return _allVideos;
    }
    final allow = _scanFolders.toSet();
    final hidden = _hiddenFolders.toSet();
    return _allVideos.where((v) {
      if (_hiddenVideos.contains(v.id)) return false;
      final folder = v.folderPath;
      if (hidden.contains(folder)) return false;
      if (allow.isNotEmpty && !allow.contains(folder)) return false;
      return true;
    }).toList();
  }

  // ---------------------------------------------------------- hidden videos
  /// Videos the user hid one by one. They stay on the device and in their
  /// folder — they just do not show up in any list until unhidden.
  Set<String> _hiddenVideos = const {};

  bool isVideoHidden(String id) => _hiddenVideos.contains(id);

  int get hiddenVideoCount => _hiddenVideos.length;

  /// The hidden ones, for the screen that lets the user bring them back.
  List<Video> get hiddenVideos {
    final out = <Video>[];
    for (final id in _hiddenVideos) {
      final video = _byId[id];
      if (video != null) out.add(video);
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }

  Future<void> toggleVideoHidden(String id) async {
    final next = Set<String>.from(_hiddenVideos);
    if (!next.remove(id)) next.add(id);
    _hiddenVideos = next;
    _invalidate();
    notifyListeners();
    await _settings.setHiddenVideos(next.toList());
  }

  Future<void> setVideosHidden(Iterable<String> ids, bool hidden) async {
    final next = Set<String>.from(_hiddenVideos);
    if (hidden) {
      next.addAll(ids);
    } else {
      next.removeAll(ids);
    }
    _hiddenVideos = next;
    _invalidate();
    notifyListeners();
    await _settings.setHiddenVideos(next.toList());
  }

  /// What the home screen shows: visible videos, searched and ordered.
  List<Video> get homeVideos => _homeCache ??= orderVideos(
    CollectionKey.home,
    _search(visibleVideos, _query),
  );

  List<Video> get favoriteVideos => _favoritesCache ??= orderVideos(
    CollectionKey.favorites,
    visibleVideos.where((v) => _favoriteIds.contains(v.id)).toList(),
  );

  List<Video> get recentlyAdded =>
      _recentlyAddedCache ??= _computeRecentlyAdded();

  List<Video> _computeRecentlyAdded() {
    final list = List<Video>.from(visibleVideos)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return list.take(30).toList();
  }

  List<Video> get recentlyPlayed =>
      _recentlyPlayedCache ??= _computeRecentlyPlayed();

  /// The video watched most recently, or null with no history.
  String? get lastPlayedId =>
      recentlyPlayed.isEmpty ? null : recentlyPlayed.first.id;

  List<Video> _computeRecentlyPlayed() {
    final records = _historyById.values.toList()
      ..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    final out = <Video>[];
    final hidden = _hiddenFolders.toSet();
    final allow = _scanFolders.toSet();
    for (final record in records) {
      final video = _byId[record.videoId];
      if (video == null) continue;
      if (hidden.contains(video.folderPath)) continue;
      if (allow.isNotEmpty && !allow.contains(video.folderPath)) continue;
      out.add(video);
      if (out.length >= 30) break;
    }
    return out;
  }

  /// Real device folders that survive the filters, pinned ones first.
  List<VideoFolder> get folders =>
      _foldersCache ??= _groupFolders(visibleVideos);

  /// Every folder found on the device — used by the Scan Folders screen so the
  /// user can re-enable something they previously excluded.
  List<VideoFolder> get allFolders =>
      _allFoldersCache ??= _groupFolders(_allVideos);

  List<Playlist> get playlists => _playlistCache;

  List<Video> videosOfPlaylist(Playlist playlist) {
    final key = CollectionKey.playlist(playlist.id);
    return _collectionCache.putIfAbsent(key.value, () {
      final out = <Video>[];
      for (final id in playlist.videoIds) {
        final video = _byId[id];
        if (video != null) out.add(video);
      }
      return orderVideos(key, out);
    });
  }

  List<Video> videosOfFolder(String folderPath) {
    final key = CollectionKey.folder(folderPath);
    return _collectionCache.putIfAbsent(
      key.value,
      () => orderVideos(
        key,
        _allVideos.where((v) => v.folderPath == folderPath).toList(),
      ),
    );
  }

  Playlist? playlistById(String id) {
    for (final playlist in _playlistCache) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  // ------------------------------------------------------------------ loading
  Future<void> load({bool force = false}) async {
    if (_scanning) return;
    if (!force && _status == LibraryStatus.ready) return;

    _scanning = true;
    _status = LibraryStatus.scanning;
    _scanProgress = 0;
    _scanMessage = 'Checking permissions…';
    notifyListeners();

    final access = await PermissionService.requestMediaAccess();
    if (access == MediaAccess.denied ||
        access == MediaAccess.permanentlyDenied) {
      _scanning = false;
      _status = LibraryStatus.denied;
      _scanMessage = 'Main Video needs access to your videos.';
      notifyListeners();
      return;
    }

    _scanMessage = 'Scanning your videos…';
    notifyListeners();

    if (force) {
      await MediaScanner.invalidateCache();
      ThumbnailService.clear();
    }

    // Favourites, history and playlists are read once up front so the very
    // first batch of videos can be rendered complete.
    _refreshCaches();

    final collected = <Video>[];
    final byId = <String, Video>{};

    final videos = await MediaScanner.scan(
      onBatch: (batch) {
        // Publish each batch as it lands, so the list fills in while the rest
        // of the device is still being read instead of showing a spinner.
        collected.addAll(batch);
        for (final v in batch) {
          byId[v.id] = v;
        }
        _allVideos = List<Video>.of(collected);
        _byId = Map<String, Video>.of(byId);
        _status = LibraryStatus.ready;
        _invalidate();
      },
      onProgress: (done, total) {
        _scanProgress = total == 0 ? 0 : done / total;
        _scanMessage = 'Scanning your videos… $done / $total';
        notifyListeners();
      },
    );

    _allVideos = videos;
    _byId = {for (final v in videos) v.id: v};
    _invalidate();

    _scanning = false;
    _status = LibraryStatus.ready;
    _scanProgress = 1;
    _scanMessage = '';
    await _settings.setLastScanAt(DateTime.now());
    notifyListeners();
  }

  Future<void> refresh() => load(force: true);

  /// Incremental scan: picks up videos recorded or downloaded since the last
  /// scan, and drops any whose file has gone, without re-reading the device.
  ///
  /// Runs when the app returns to the foreground.
  Future<void> syncNewVideos() async {
    if (_scanning || _status != LibraryStatus.ready) return;

    final since = _settings.lastScanAt;
    if (since == null) return;

    var changed = false;

    try {
      // A little overlap covers clock skew between MediaStore and the app.
      final fresh = await MediaScanner.scanSince(
        since.subtract(const Duration(minutes: 2)),
      );
      final additions = fresh.where((v) => !_byId.containsKey(v.id)).toList();

      if (additions.isNotEmpty) {
        final merged = List<Video>.from(_allVideos)..addAll(additions);
        _allVideos = merged;
        final byId = Map<String, Video>.of(_byId);
        for (final v in additions) {
          byId[v.id] = v;
        }
        _byId = byId;
        changed = true;
      }

      // Cheap deletion check: only bother when the device count disagrees.
      final deviceCount = await MediaScanner.countVideos();
      if (deviceCount < _allVideos.length) {
        final surviving = _allVideos
            .where((v) => File(v.path).existsSync())
            .toList();
        if (surviving.length != _allVideos.length) {
          _allVideos = surviving;
          _byId = {for (final v in surviving) v.id: v};
          changed = true;
        }
      }
    } catch (_) {
      // A failed sync is not worth surfacing; the next one will catch up.
      return;
    }

    await _settings.setLastScanAt(DateTime.now());
    if (!changed) return;

    _invalidate();
    notifyListeners();
  }

  void _refreshCaches() {
    _favoriteIds = _favorites.all();
    _historyById = _history.asMap();
    _playlistCache = _playlists.all();
    _prefsCache = _prefs.all();
    _invalidate();
  }

  // ------------------------------------------------------------- view options
  Future<void> setViewMode(ViewMode mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
    await _settings.setViewMode(mode);
  }

  Future<void> toggleViewMode() => setViewMode(nextViewMode);

  /// The Folders tab has just two layouts, list and cards, kept apart from the
  /// video lists' three so switching one never changes the other.
  bool _foldersAsGrid = false;
  bool get foldersAsGrid => _foldersAsGrid;

  Future<void> toggleFoldersLayout() async {
    _foldersAsGrid = !_foldersAsGrid;
    notifyListeners();
    await _settings.setFolderGrid(_foldersAsGrid);
  }

  /// The layout after the current one: list, then compact list, then grid.
  ViewMode get nextViewMode =>
      ViewMode.values[(_viewMode.index + 1) % ViewMode.values.length];

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _homeCache = null;
    notifyListeners();
  }

  void clearQuery() => setQuery('');

  // ------------------------------------------------------- per-collection sort
  /// Every folder, playlist, favourites and the home screen keeps its own
  /// order, so changing one never disturbs another.
  CollectionPrefs prefsFor(CollectionKey key) =>
      _prefsCache[key.value] ?? const CollectionPrefs();

  Future<void> setSortFor(
    CollectionKey key,
    SortField field, {
    bool? descending,
  }) async {
    final current = prefsFor(key);
    var next = current.copyWith(
      sortField: field,
      descending: descending ?? current.descending,
    );

    // Switching to a custom order seeds it from whatever is on screen now, so
    // the list does not jump around before the first drag.
    if (field == SortField.manual && current.manualOrder.isEmpty) {
      next = next.copyWith(
        manualOrder: _currentOrderFor(key, current).map((v) => v.id).toList(),
      );
    }
    await _writePrefs(key, next);
  }

  Future<void> toggleSortDirectionFor(CollectionKey key) async {
    final prefs = prefsFor(key);
    await _writePrefs(key, prefs.copyWith(descending: !prefs.descending));
  }

  /// Applies a drag-and-drop reorder and switches the list to custom order.
  ///
  /// [newIndex] is the destination after the dragged item was taken out, which
  /// is what `SliverReorderableList.onReorderItem` provides.
  Future<void> reorder(
    CollectionKey key,
    List<Video> current,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = current.map((v) => v.id).toList();
    if (oldIndex < 0 || oldIndex >= ids.length) return;

    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);

    await _writePrefs(
      key,
      prefsFor(key).copyWith(sortField: SortField.manual, manualOrder: ids),
    );
  }

  Future<void> _writePrefs(CollectionKey key, CollectionPrefs prefs) async {
    _prefsCache = {..._prefsCache, key.value: prefs};
    _invalidate();
    notifyListeners();
    await _prefs.write(key, prefs);
  }

  List<Video> _currentOrderFor(CollectionKey key, CollectionPrefs prefs) {
    if (key == CollectionKey.home) return homeVideos;
    if (key == CollectionKey.favorites) return favoriteVideos;
    final value = key.value;
    if (value.startsWith('folder:')) {
      return videosOfFolder(value.substring('folder:'.length));
    }
    if (value.startsWith('playlist:')) {
      final playlist = playlistById(value.substring('playlist:'.length));
      return playlist == null ? const [] : videosOfPlaylist(playlist);
    }
    return const [];
  }

  // --------------------------------------------------------------------- pins
  bool isVideoPinned(String id) => _pinnedVideos.contains(id);

  Future<void> toggleVideoPin(String id) async {
    final pins = Set<String>.from(_pinnedVideos);
    if (!pins.remove(id)) pins.add(id);
    _pinnedVideos = pins;
    _invalidate();
    notifyListeners();
    await _settings.setPinnedVideos(pins.toList());
  }

  bool isFolderPinned(String path) => _pinnedFolders.contains(path);

  Future<void> toggleFolderPin(String path) async {
    final pins = Set<String>.from(_pinnedFolders);
    if (!pins.remove(path)) pins.add(path);
    _pinnedFolders = pins;
    _invalidate();
    notifyListeners();
    await _settings.setPinnedFolders(pins.toList());
  }

  Future<void> togglePlaylistPin(String id) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    await _playlists.setPinned(id, !playlist.pinned);
    _playlistCache = _playlists.all();
    notifyListeners();
  }

  // ----------------------------------------------------------------- favorites
  Future<bool> toggleFavorite(String videoId) async {
    final now = await _favorites.toggle(videoId);
    if (now) {
      _favoriteIds = {..._favoriteIds, videoId};
    } else {
      _favoriteIds = {..._favoriteIds}..remove(videoId);
    }
    _favoritesCache = null;
    notifyListeners();
    return now;
  }

  Future<void> setFavorites(Iterable<String> videoIds, bool value) async {
    final ids = Set<String>.from(_favoriteIds);
    for (final id in videoIds) {
      await _favorites.set(id, value);
      value ? ids.add(id) : ids.remove(id);
    }
    _favoriteIds = ids;
    _favoritesCache = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------- history
  /// [notify] is false for the player's periodic saves: the cache is kept in
  /// step, but the screens underneath are not rebuilt every few seconds while
  /// a video is playing.
  Future<void> savePosition({
    required String videoId,
    required int positionMs,
    required int durationMs,
    bool notify = true,
  }) async {
    await _history.save(
      videoId: videoId,
      positionMs: positionMs,
      durationMs: durationMs,
    );
    // Patch the one entry instead of re-reading the whole box.
    _historyById[videoId] = WatchRecord(
      videoId: videoId,
      positionMs: positionMs,
      durationMs: durationMs,
      lastPlayed: DateTime.now(),
    );
    _invalidateHistoryDerived();
    if (notify) notifyListeners();
  }

  /// Tells the screens about resume points saved silently while the player
  /// was covering them.
  void notifyHistoryChanged() => notifyListeners();

  Future<void> clearHistory() async {
    await _history.clear();
    _historyById = {};
    _invalidateHistoryDerived();
    notifyListeners();
  }

  Future<void> removeFromHistory(String videoId) async {
    await _history.remove(videoId);
    _historyById.remove(videoId);
    _invalidateHistoryDerived();
    notifyListeners();
  }

  /// Only the lists that actually depend on watch history.
  void _invalidateHistoryDerived() {
    _recentlyPlayedCache = null;
    _homeCache = null;
    _favoritesCache = null;
    _collectionCache.clear();
  }

  // ----------------------------------------------------------------- playlists
  Future<Playlist> createPlaylist(
    String name, {
    List<String> videoIds = const [],
  }) async {
    final playlist = await _playlists.create(name, videoIds: videoIds);
    _playlistCache = _playlists.all();
    _invalidate();
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) async {
    await _playlists.rename(id, name);
    _playlistCache = _playlists.all();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _playlists.delete(id);
    await _prefs.remove(CollectionKey.playlist(id));
    _playlistCache = _playlists.all();
    _prefsCache = _prefs.all();
    _invalidate();
    notifyListeners();
  }

  Future<void> setPlaylistStyle(
    String id, {
    int? colorValue,
    String? iconKey,
    bool clearColor = false,
    bool clearIcon = false,
  }) async {
    await _playlists.setStyle(
      id,
      colorValue: colorValue,
      iconKey: iconKey,
      clearColor: clearColor,
      clearIcon: clearIcon,
    );
    _playlistCache = _playlists.all();
    notifyListeners();
  }

  Future<void> addToPlaylist(String id, Iterable<String> videoIds) async {
    await _playlists.addVideos(id, videoIds);
    _playlistCache = _playlists.all();
    _invalidate();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String id, String videoId) =>
      removeManyFromPlaylist(id, [videoId]);

  Future<void> removeManyFromPlaylist(
    String id,
    Iterable<String> videoIds,
  ) async {
    await _playlists.removeVideos(id, videoIds);
    _playlistCache = _playlists.all();
    _invalidate();
    notifyListeners();
  }

  /// Moves videos out of one playlist and into another in a single step.
  Future<void> moveBetweenPlaylists({
    required String fromId,
    required String toId,
    required Iterable<String> videoIds,
  }) async {
    if (fromId == toId) return;
    await _playlists.addVideos(toId, videoIds);
    await _playlists.removeVideos(fromId, videoIds);
    _playlistCache = _playlists.all();
    _invalidate();
    notifyListeners();
  }

  // ------------------------------------------------------------- scan folders
  Future<void> setScanFolders(List<String> paths) async {
    _scanFolders = paths;
    _invalidate();
    notifyListeners();
    await _settings.setScanFolders(paths);
  }

  Future<void> setHiddenFolders(List<String> paths) async {
    _hiddenFolders = paths;
    _invalidate();
    notifyListeners();
    await _settings.setHiddenFolders(paths);
  }

  Future<void> toggleHiddenFolder(String path) async {
    final list = List<String>.from(_hiddenFolders);
    if (list.contains(path)) {
      list.remove(path);
    } else {
      list.add(path);
    }
    await setHiddenFolders(list);
  }

  bool isFolderHidden(String path) => _hiddenFolders.contains(path);

  bool isFolderScanned(String path) =>
      _scanFolders.isEmpty || _scanFolders.contains(path);

  // ------------------------------------------------------------ file actions
  /// Set by the app so deleting can honour the recycle-bin setting without the
  /// library depending on the settings controller.
  bool Function()? recycleBinEnabled;

  final RecycleBinRepository _bin = const RecycleBinRepository();
  RecycleBinRepository get recycleBin => _bin;

  int get recycleBinCount => _bin.count;
  List<TrashedVideo> get trashedVideos => _bin.all();

  bool get _useBin => recycleBinEnabled?.call() ?? false;

  Future<FileOpResult> deleteVideo(Video video) async {
    final result = await _removeOne(video);
    if (!result.ok) return result;
    await _forgetVideo(video.id);
    _invalidate();
    notifyListeners();
    return result;
  }

  /// Either moves the file into the bin or erases it, depending on the
  /// setting.
  Future<FileOpResult> _removeOne(Video video) async {
    if (!_useBin) return VideoFileService.delete(video);
    final error = await _bin.moveToBin(video);
    return error == null
        ? const FileOpResult(FileOpStatus.success)
        : FileOpResult(FileOpStatus.failed, message: error);
  }

  /// Puts a video back where it was deleted from.
  Future<String?> restoreFromBin(TrashedVideo item) async {
    final error = await _bin.restore(item);
    if (error != null) return error;
    await syncNewVideos();
    notifyListeners();
    return null;
  }

  Future<void> deleteFromBinForever(TrashedVideo item) async {
    await _bin.deleteForever(item);
    notifyListeners();
  }

  Future<void> emptyRecycleBin() async {
    await _bin.empty();
    notifyListeners();
  }

  /// Bulk delete. Returns how many files actually went, plus the first failure
  /// so the UI can explain what stopped.
  Future<({int deleted, FileOpResult? failure})> deleteVideos(
    List<Video> videos,
  ) async {
    var deleted = 0;
    FileOpResult? failure;

    for (final video in videos) {
      final result = await _removeOne(video);
      if (result.ok) {
        await _forgetVideo(video.id);
        deleted++;
      } else {
        failure ??= result;
      }
    }

    if (deleted > 0) {
      _invalidate();
      notifyListeners();
    }
    return (deleted: deleted, failure: failure);
  }

  Future<FileOpResult> renameVideo(Video video, String newName) async {
    final result = await VideoFileService.rename(video, newName);
    if (!result.ok || result.newPath == null) return result;
    await _replaceVideoPath(video, result.newPath!);
    return result;
  }

  /// Moves files into another real folder on the device.
  Future<({int moved, FileOpResult? failure})> moveVideosToFolder(
    List<Video> videos,
    String targetFolder,
  ) async {
    var moved = 0;
    FileOpResult? failure;

    for (final video in videos) {
      final result = await VideoFileService.move(video, targetFolder);
      if (result.ok && result.newPath != null) {
        await _replaceVideoPath(video, result.newPath!, notify: false);
        moved++;
      } else if (!result.ok) {
        failure ??= result;
      }
    }

    if (moved > 0) {
      _invalidate();
      notifyListeners();
    }
    return (moved: moved, failure: failure);
  }

  Future<void> _forgetVideo(String id) async {
    _allVideos = _allVideos.where((v) => v.id != id).toList();
    _byId = {for (final v in _allVideos) v.id: v};
    await _favorites.remove(id);
    await _history.remove(id);
    await _playlists.purgeVideo(id);
    await _prefs.purgeVideo(id);

    _favoriteIds = {..._favoriteIds}..remove(id);
    _historyById.remove(id);
    _playlistCache = _playlists.all();
    _prefsCache = _prefs.all();

    if (_pinnedVideos.contains(id)) {
      final pins = Set<String>.from(_pinnedVideos)..remove(id);
      _pinnedVideos = pins;
      await _settings.setPinnedVideos(pins.toList());
    }
    onVideoChanged?.call(id, null);
  }

  Future<void> _replaceVideoPath(
    Video video,
    String newPath, {
    bool notify = true,
  }) async {
    final newTitle = newPath.split(RegExp(r'[\\/]')).last;
    final updated = video.copyWith(id: newPath, title: newTitle);

    _allVideos = _allVideos
        .map((v) => v.id == video.id ? updated : v)
        .toList(growable: false);
    _byId = {for (final v in _allVideos) v.id: v};

    await _favorites.rekey(video.id, newPath);
    await _history.rekey(video.id, newPath);
    await _playlists.rekey(video.id, newPath);
    await _prefs.rekey(video.id, newPath);

    if (_pinnedVideos.contains(video.id)) {
      final pins = Set<String>.from(_pinnedVideos)
        ..remove(video.id)
        ..add(newPath);
      _pinnedVideos = pins;
      await _settings.setPinnedVideos(pins.toList());
    }

    _favoriteIds = _favorites.all();
    _historyById = _history.asMap();
    _playlistCache = _playlists.all();
    _prefsCache = _prefs.all();

    onVideoChanged?.call(video.id, updated);

    if (notify) {
      _invalidate();
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ helpers
  /// Applies one collection's own sort order, then floats pinned videos to the
  /// top of it.
  List<Video> orderVideos(CollectionKey key, List<Video> input) {
    final prefs = prefsFor(key);
    final list = List<Video>.from(input);

    if (prefs.isManual) {
      const unplaced = 1 << 30;
      final rank = <String, int>{};
      for (var i = 0; i < prefs.manualOrder.length; i++) {
        rank[prefs.manualOrder[i]] = i;
      }
      // Anything added since the order was made goes to the end, by name.
      list.sort((a, b) {
        final ai = rank[a.id] ?? unplaced;
        final bi = rank[b.id] ?? unplaced;
        if (ai != bi) return ai.compareTo(bi);
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    } else {
      final sign = prefs.descending ? -1 : 1;
      list.sort((a, b) => sign * _compare(prefs.sortField, a, b));
    }

    if (_pinnedVideos.isEmpty) return list;

    final pinned = <Video>[];
    final rest = <Video>[];
    for (final video in list) {
      (_pinnedVideos.contains(video.id) ? pinned : rest).add(video);
    }
    return [...pinned, ...rest];
  }

  int _compare(SortField field, Video a, Video b) {
    switch (field) {
      case SortField.dateAdded:
        return a.dateAdded.compareTo(b.dateAdded);
      case SortField.duration:
        return a.durationMs.compareTo(b.durationMs);
      case SortField.name:
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      case SortField.size:
        return a.sizeBytes.compareTo(b.sizeBytes);
      case SortField.lastWatched:
        final aAt = _historyById[a.id]?.lastPlayed;
        final bAt = _historyById[b.id]?.lastPlayed;
        if (aAt == null && bAt == null) {
          return a.dateAdded.compareTo(b.dateAdded);
        }
        // Never-watched videos always sit at the bottom of the list.
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        return aAt.compareTo(bAt);
      case SortField.manual:
        return 0;
    }
  }

  List<Video> _search(List<Video> input, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return input;
    return input
        .where(
          (v) =>
              v.title.toLowerCase().contains(q) ||
              v.folderName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<VideoFolder> _groupFolders(List<Video> input) {
    final grouped = <String, List<Video>>{};
    for (final video in input) {
      grouped.putIfAbsent(video.folderPath, () => []).add(video);
    }
    final folders =
        grouped.entries
            .map((e) => VideoFolder(path: e.key, videos: e.value))
            .toList()
          ..sort((a, b) {
            final aPinned = _pinnedFolders.contains(a.path);
            final bPinned = _pinnedFolders.contains(b.path);
            if (aPinned != bPinned) return aPinned ? -1 : 1;
            return b.lastAdded.compareTo(a.lastAdded);
          });
    return folders;
  }
}
