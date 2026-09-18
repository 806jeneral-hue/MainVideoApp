import 'package:hive_flutter/hive_flutter.dart';

/// Local storage for everything the app remembers: playlists, favourites,
/// watch history and user settings.
///
/// Only primitives and plain maps are stored, so no generated Hive adapters
/// and no build_runner step are needed.
class AppDatabase {
  const AppDatabase._();

  static const String settingsBox = 'settings';
  static const String favoritesBox = 'favorites';
  static const String historyBox = 'history';
  static const String playlistsBox = 'playlists';
  static const String collectionPrefsBox = 'collection_prefs';
  static const String recycleBinBox = 'recycle_bin';
  static const String musicFavoritesBox = 'music_favorites';
  static const String musicHistoryBox = 'music_history';
  static const String musicPlaylistsBox = 'music_playlists';
  static const String stopMarkersBox = 'stop_markers';
  static const String momentsBox = 'moments';
  static const String playPlansBox = 'play_plans';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(settingsBox),
      Hive.openBox<bool>(favoritesBox),
      Hive.openBox<Map<dynamic, dynamic>>(historyBox),
      Hive.openBox<Map<dynamic, dynamic>>(playlistsBox),
      Hive.openBox<Map<dynamic, dynamic>>(collectionPrefsBox),
      Hive.openBox<Map<dynamic, dynamic>>(recycleBinBox),
      Hive.openBox<int>(musicFavoritesBox),
      Hive.openBox<int>(musicHistoryBox),
      Hive.openBox<Map<dynamic, dynamic>>(musicPlaylistsBox),
      Hive.openBox<Map<dynamic, dynamic>>(stopMarkersBox),
      Hive.openBox<List<dynamic>>(momentsBox),
      Hive.openBox<Map<dynamic, dynamic>>(playPlansBox),
    ]);
  }

  static Box<dynamic> get settings => Hive.box<dynamic>(settingsBox);
  static Box<bool> get favorites => Hive.box<bool>(favoritesBox);
  static Box<Map<dynamic, dynamic>> get history =>
      Hive.box<Map<dynamic, dynamic>>(historyBox);
  static Box<Map<dynamic, dynamic>> get playlists =>
      Hive.box<Map<dynamic, dynamic>>(playlistsBox);
  static Box<Map<dynamic, dynamic>> get collectionPrefs =>
      Hive.box<Map<dynamic, dynamic>>(collectionPrefsBox);
  static Box<Map<dynamic, dynamic>> get recycleBin =>
      Hive.box<Map<dynamic, dynamic>>(recycleBinBox);

  // Music keeps its own favourites, history and playlists, apart from video.
  /// Song id to the time it was favourited, so the newest can come first.
  static Box<int> get musicFavorites => Hive.box<int>(musicFavoritesBox);
  static Box<int> get musicHistory => Hive.box<int>(musicHistoryBox);
  static Box<Map<dynamic, dynamic>> get musicPlaylists =>
      Hive.box<Map<dynamic, dynamic>>(musicPlaylistsBox);

  /// One "I stopped here" marker per list — home, each folder, each
  /// playlist — keyed by the list.
  static Box<Map<dynamic, dynamic>> get stopMarkers =>
      Hive.box<Map<dynamic, dynamic>>(stopMarkersBox);

  /// Each video's saved moments, in milliseconds, keyed by video id.
  static Box<List<dynamic>> get moments => Hive.box<List<dynamic>>(momentsBox);

  /// The last custom play session of each list, keyed by the list.
  static Box<Map<dynamic, dynamic>> get playPlans =>
      Hive.box<Map<dynamic, dynamic>>(playPlansBox);
}

/// Every settings key in one place so nothing is stringly-typed twice.
class SettingsKeys {
  const SettingsKeys._();

  // Appearance (phase 7)
  static const themeMode = 'themeMode';
  static const locale = 'locale';

  // Library / home (phase 2)
  static const viewMode = 'viewMode';
  static const sortField = 'sortField';
  static const sortDescending = 'sortDescending';

  // Folders (phase 3)
  static const scanFolders = 'scanFolders';
  static const hiddenFolders = 'hiddenFolders';

  // Pinning (improvements round)
  static const pinnedVideos = 'pinnedVideos';
  static const pinnedFolders = 'pinnedFolders';

  // Incremental scan bookkeeping
  static const lastScanAt = 'lastScanAt';

  // History (phase 7)
  static const showHistory = 'showHistory';

  // Playback (phase 5)
  static const resumePlayback = 'resumePlayback';
  static const autoplayNext = 'autoplayNext';
  static const pipEnabled = 'pipEnabled';
  static const backgroundPlayback = 'backgroundPlayback';
  static const gesturesEnabled = 'gesturesEnabled';
  static const defaultSpeed = 'defaultSpeed';
  static const abRepeatEnabled = 'abRepeatEnabled';
  static const sleepTimerEnabled = 'sleepTimerEnabled';
  static const shuffle = 'shuffle';
  static const repeatMode = 'repeatMode';
  static const keepScreenOn = 'keepScreenOn';
  static const seekSeconds = 'seekSeconds';
  static const swipeSeekSeconds = 'swipeSeekSeconds';
  static const hapticsEnabled = 'hapticsEnabled';

  // Privacy and safety (phase 3 improvements)
  static const recycleBinEnabled = 'recycleBinEnabled';
  static const recycleBinDays = 'recycleBinDays';
  static const hiddenVideos = 'hiddenVideos';

  // Personalisation (phase 3 improvements)
  static const accentKey = 'accentKey';
  static const backgroundImage = 'backgroundImage';
  static const backgroundBlur = 'backgroundBlur';
  static const glassStrength = 'glassStrength';
  static const appStyle = 'appStyle';
  static const folderGrid = 'folderGrid';
  static const quickMenuTipShown = 'quickMenuTipShown';

  // Music
  static const musicSort = 'musicSort';
  static const musicSortDescending = 'musicSortDescending';
  static const musicAskedNotifications = 'musicAskedNotifications';

  // Files
  static const askedAllFilesAccess = 'askedAllFilesAccess';
}
