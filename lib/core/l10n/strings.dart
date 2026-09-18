/// Every user-visible string in the app, in each supported language.
///
/// A plain class rather than generated code: there are two languages and no
/// build step to keep in sync, and this way a missing translation is a
/// compile error instead of a fallback at runtime.
abstract class Strings {
  const Strings();

  String get languageName;

  // ------------------------------------------------------------------ shared
  String get appTitle;
  String get cancel;
  String get save;
  String get create;
  String get delete;
  String get rename;
  String get clear;
  String get done;
  String get goBack;
  String get all;

  String videoCount(int count);
  String selectedCount(int count);

  // -------------------------------------------------------------- date words
  String get today;
  String get yesterday;
  String daysAgo(int days);

  /// Twelve short month names, January first.
  List<String> get months;

  // -------------------------------------------------------------- navigation
  String get navHome;
  String get navFolders;
  String get navFavorites;
  String get navMore;

  // -------------------------------------------------------------------- home
  String get searchVideos;
  String get search;
  String get closeSearch;
  String get sort;
  String get gridView;
  String get listView;
  String get compactView;
  String get filterAll;
  String get filterRecentlyAdded;
  String get filterRecentlyPlayed;
  String get allVideos;
  String stillScanning(String count);
  String matchingQuery(String count, String query);
  String sortedBy(String count, String field);
  String get newestOnDevice;
  String get pickUpWhereYouLeftOff;
  String get nothingFound;
  String noVideoMatches(String query);
  String get nothingWatchedYet;
  String get nothingWatchedYetBody;
  String get noVideosFound;
  String get noVideosFoundBody;

  // ------------------------------------------------------------- permissions
  String get accessNeeded;
  String get accessNeededBody;
  String get grantAccess;
  String get openSettings;
  String get gettingReady;
  String scanningProgress(int done, int total);
  String get checkingPermissions;
  String get scanningVideos;

  // ------------------------------------------------------------------- sort
  String get sortBy;
  String get sortDateAdded;
  String get sortLength;
  String get sortName;
  String get sortSize;
  String get sortWatchHistory;
  String get sortCustom;
  String get sortCustomHint;
  String get order;
  String get descending;
  String get ascending;
  String get customOrder;

  // ---------------------------------------------------------------- folders
  String get folders;
  String get playlists;
  String get deviceFolders;
  String get favorites;
  String get newPlaylist;
  String get playlistName;
  String get renamePlaylist;
  String get deletePlaylist;
  String get deletePlaylistBody;
  String get colorAndIcon;
  String get colorLabel;
  String get iconLabel;
  String get resetToDefault;
  String get pinToTop;
  String get unpinFromTop;
  String get hideThisFolder;
  String get hideThisFolderBody;
  String get addAllToPlaylist;
  String get chooseFoldersToScan;
  String get noFoldersToShow;
  String get noFoldersToShowBody;
  String get playAll;
  String get addVideos;
  String addToPlaylistTitle(String name);
  String get addToPlaylist;
  String addVideosToPlaylist(int count);
  String get nothingToAdd;
  String get nothingToAddBody;
  String addedTo(String name);
  String get emptyPlaylist;
  String get emptyPlaylistBody;
  String get noFavorites;
  String get noFavoritesBody;
  String get folderEmpty;
  String get folderEmptyBody;
  String addCount(int count);

  // ------------------------------------------------------------ video actions
  String get play;
  String get more;
  String get select;
  String get addToFavorites;
  String get removeFromFavorites;
  String get removeFromThisPlaylist;
  String get moveTo;
  String get videoInfo;
  String get deleteFromDevice;
  String get renameVideo;
  String get newName;
  String get renamed;
  String get couldNotRename;
  String get deleteVideoTitle;
  String deleteVideoBody(String name);
  String get videoDeleted;
  String get permissionDenied;
  String get fileGone;
  String get couldNotDelete;
  String deleteManyTitle(int count);
  String get deleteManyBody;
  String deletedCount(int count);
  String partialDelete(int deleted, int failed);
  String get favorite;
  String get unfavorite;
  String get addTo;
  String get move;
  String get remove;
  String get selectAll;

  // ------------------------------------------------------------------- move
  String moveCount(int count);
  String get moveExplainer;
  String movedCount(int count);
  String partialMove(int moved, int failed);
  String movedToPlaylist(String name);

  // -------------------------------------------------------------- video info
  String get videoInfoTitle;
  String get infoName;
  String get infoType;
  String get infoResolution;
  String get infoLength;
  String get infoSize;
  String get infoFolder;
  String get infoDateAdded;
  String get infoDateModified;
  String get infoPath;
  String get copyPath;
  String get pathCopied;

  // ----------------------------------------------------------------- player
  String get minimise;
  String get pictureInPicture;
  String get playingQueue;
  String get previous;
  String get next;
  String get pause;
  String get lock;
  String get abRepeat;
  String get shuffle;
  String get repeat;
  String get repeatAll;
  String get repeatOne;
  String get repeatOff;
  String get sleep;
  String get sleepTimer;
  String get playbackSpeed;
  String get screenLocked;
  String get videoCouldNotOpen;
  String abPointSet(String at);
  String abLooping(String from, String to);
  String sleepStopsIn(String remaining);
  String get cancelTimer;
  String minutesOption(int minutes);
  String queueWithCount(int count);

  // --------------------------------------------------------------- settings
  String get settings;
  String get appSettings;
  String get playbackSettings;
  String get playbackSettingsBody;
  String get appearance;
  String get darkMode;
  String get darkModeBody;
  String get followSystemTheme;
  String get followSystemThemeBody;
  String get language;
  String get languageBody;
  String get systemLanguage;
  String get history;
  String get showWatchHistory;
  String get showWatchHistoryBody;
  String get clearWatchHistory;
  String get clearWatchHistoryBody;
  String get clearHistoryConfirmTitle;
  String get clearHistoryConfirmBody;
  String get historyCleared;
  String get playback;
  String get foldersToScan;
  String allFoldersHidden(int hidden);
  String selectedFoldersHidden(int selected, int hidden);
  String get rescanDevice;
  String get rescanDeviceBody;
  String get libraryRescanned;
  String get about;
  String get aboutApp;
  String version(String value);
  String get aboutBody;
  String get library;
  String get statVideos;

  // ----------------------------------------------------- playback settings
  String get startingAVideo;
  String get resumePlayback;
  String get resumePlaybackBody;
  String get autoplayNext;
  String get autoplayNextBody;
  String get whilePlaying;
  String get gestureControls;
  String get gestureControlsBody;
  String get skipAmount;
  String get skipAmountBody;
  String get keepScreenOn;
  String get keepScreenOnBody;
  String get pipTitle;
  String get pipBody;
  String get pipUnsupported;
  String get backgroundPlayback;
  String get backgroundPlaybackBody;
  String get availableInPlayer;
  String get abRepeatBody;
  String get sleepTimerBody;
  String get defaults;
  String get defaultSpeed;
  String get defaultSpeedBody;
  String get shuffleByDefault;
  String get shuffleByDefaultBody;
  String get defaultRepeatMode;
  String get defaultRepeatModeBody;
  String secondsOption(int seconds);

  // -------------------------------------------------------- scan folders
  String get scanFoldersTitle;
  String get scanningEverything;
  String scanningSome(int selected, int total);
  String get noFoldersFound;
  String get noFoldersFoundBody;
  String get unhideFolder;
  String get hideFolder;
}

class StringsEn extends Strings {
  const StringsEn();

  @override
  String get languageName => 'English';

  @override
  String get appTitle => 'Main Video';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get create => 'Create';
  @override
  String get delete => 'Delete';
  @override
  String get rename => 'Rename';
  @override
  String get clear => 'Clear';
  @override
  String get done => 'Done';
  @override
  String get goBack => 'Go back';
  @override
  String get all => 'All';

  @override
  String videoCount(int count) => count == 1 ? '1 video' : '$count videos';
  @override
  String selectedCount(int count) => '$count selected';

  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String daysAgo(int days) => '$days days ago';
  @override
  List<String> get months => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  String get navHome => 'Home';
  @override
  String get navFolders => 'Folders';
  @override
  String get navFavorites => 'Favorites';
  @override
  String get navMore => 'More';

  @override
  String get searchVideos => 'Search videos';
  @override
  String get search => 'Search';
  @override
  String get closeSearch => 'Close search';
  @override
  String get sort => 'Sort';
  @override
  String get gridView => 'Grid view';
  @override
  String get listView => 'List view';
  @override
  String get compactView => 'Compact list';
  @override
  String get filterAll => 'All';
  @override
  String get filterRecentlyAdded => 'Added';
  @override
  String get filterRecentlyPlayed => 'Played';
  @override
  String get allVideos => 'All videos';
  @override
  String stillScanning(String count) => 'Still scanning…  $count so far';
  @override
  String matchingQuery(String count, String query) =>
      '$count matching "$query"';
  @override
  String sortedBy(String count, String field) => '$count  ·  sorted by $field';
  @override
  String get newestOnDevice => 'The newest videos on your device';
  @override
  String get pickUpWhereYouLeftOff => 'Pick up where you left off';
  @override
  String get nothingFound => 'Nothing found';
  @override
  String noVideoMatches(String query) => 'No video matches "$query".';
  @override
  String get nothingWatchedYet => 'Nothing watched yet';
  @override
  String get nothingWatchedYetBody =>
      'Videos you start playing will show up here.';
  @override
  String get noVideosFound => 'No videos found';
  @override
  String get noVideosFoundBody =>
      'Nothing was found in the folders being scanned. Pull down to rescan, or '
      'change which folders are scanned in Settings.';

  @override
  String get accessNeeded => 'Access to your videos is needed';
  @override
  String get accessNeededBody =>
      'Main Video reads the videos already on this device. Nothing is uploaded '
      'anywhere.';
  @override
  String get grantAccess => 'Grant access';
  @override
  String get openSettings => 'Open settings';
  @override
  String get gettingReady => 'Getting things ready…';
  @override
  String scanningProgress(int done, int total) =>
      'Scanning your videos… $done / $total';
  @override
  String get checkingPermissions => 'Checking permissions…';
  @override
  String get scanningVideos => 'Scanning your videos…';

  @override
  String get sortBy => 'Sort by';
  @override
  String get sortDateAdded => 'Date added';
  @override
  String get sortLength => 'Length';
  @override
  String get sortName => 'Name';
  @override
  String get sortSize => 'Size';
  @override
  String get sortWatchHistory => 'Watch history';
  @override
  String get sortCustom => 'Custom order';
  @override
  String get sortCustomHint => 'Drag videos into the order you want';
  @override
  String get order => 'Order';
  @override
  String get descending => 'Desc';
  @override
  String get ascending => 'Asc';
  @override
  String get customOrder => 'custom order';

  @override
  String get folders => 'Folders';
  @override
  String get playlists => 'Playlists';
  @override
  String get deviceFolders => 'Device folders';
  @override
  String get favorites => 'Favorites';
  @override
  String get newPlaylist => 'New playlist';
  @override
  String get playlistName => 'Playlist name';
  @override
  String get renamePlaylist => 'Rename playlist';
  @override
  String get deletePlaylist => 'Delete playlist';
  @override
  String get deletePlaylistBody => 'The videos themselves are kept';
  @override
  String get colorAndIcon => 'Color and icon';
  @override
  String get colorLabel => 'Color';
  @override
  String get iconLabel => 'Icon';
  @override
  String get resetToDefault => 'Reset to default';
  @override
  String get pinToTop => 'Pin to top';
  @override
  String get unpinFromTop => 'Unpin from top';
  @override
  String get hideThisFolder => 'Hide this folder';
  @override
  String get hideThisFolderBody => 'It stays on the device, just not listed';
  @override
  String get addAllToPlaylist => 'Add all to a playlist';
  @override
  String get chooseFoldersToScan => 'Choose folders to scan';
  @override
  String get noFoldersToShow => 'No folders to show';
  @override
  String get noFoldersToShowBody =>
      'Either no videos were found, or every folder is hidden.';
  @override
  String get playAll => 'Play all';
  @override
  String get addVideos => 'Add videos';
  @override
  String addToPlaylistTitle(String name) => 'Add to $name';
  @override
  String get addToPlaylist => 'Add to playlist';
  @override
  String addVideosToPlaylist(int count) => 'Add $count videos to playlist';
  @override
  String get nothingToAdd => 'Nothing to add';
  @override
  String get nothingToAddBody => 'Every video is already in this playlist.';
  @override
  String addedTo(String name) => 'Added to $name';
  @override
  String get emptyPlaylist => 'This playlist is empty';
  @override
  String get emptyPlaylistBody =>
      'Use the + button above to add videos from anywhere.';
  @override
  String get noFavorites => 'No favorites yet';
  @override
  String get noFavoritesBody =>
      'Long-press any video and choose "Add to favorites" to keep it here, '
      'wherever it lives on the device.';
  @override
  String get folderEmpty => 'Nothing here';
  @override
  String get folderEmptyBody => 'This folder has no videos any more.';
  @override
  String addCount(int count) => 'Add $count';

  @override
  String get play => 'Play';
  @override
  String get more => 'More';
  @override
  String get select => 'Select';
  @override
  String get addToFavorites => 'Add to favorites';
  @override
  String get removeFromFavorites => 'Remove from favorites';
  @override
  String get removeFromThisPlaylist => 'Remove from this playlist';
  @override
  String get moveTo => 'Move to…';
  @override
  String get videoInfo => 'Video info';
  @override
  String get deleteFromDevice => 'Delete from device';
  @override
  String get renameVideo => 'Rename video';
  @override
  String get newName => 'New name';
  @override
  String get renamed => 'Renamed';
  @override
  String get couldNotRename => 'Could not rename the file';
  @override
  String get deleteVideoTitle => 'Delete video?';
  @override
  String deleteVideoBody(String name) =>
      '"$name" will be removed from this device. This cannot be undone.';
  @override
  String get videoDeleted => 'Video deleted';
  @override
  String get permissionDenied => 'Permission denied';
  @override
  String get fileGone => 'The file no longer exists';
  @override
  String get couldNotDelete => 'Could not delete the file';
  @override
  String deleteManyTitle(int count) => 'Delete ${videoCount(count)}?';
  @override
  String get deleteManyBody =>
      'The files will be removed from this device. This cannot be undone.';
  @override
  String deletedCount(int count) => '${videoCount(count)} deleted';
  @override
  String partialDelete(int deleted, int failed) =>
      '$deleted deleted, $failed could not be removed';
  @override
  String get favorite => 'Favorite';
  @override
  String get unfavorite => 'Unfavorite';
  @override
  String get addTo => 'Add to';
  @override
  String get move => 'Move';
  @override
  String get remove => 'Remove';
  @override
  String get selectAll => 'Select all';

  @override
  String moveCount(int count) => 'Move ${videoCount(count)}';
  @override
  String get moveExplainer =>
      'Moving to a folder changes where the file lives on the device.';
  @override
  String movedCount(int count) => '${videoCount(count)} moved';
  @override
  String partialMove(int moved, int failed) =>
      '$moved moved, $failed could not be moved';
  @override
  String movedToPlaylist(String name) => 'Moved to $name';

  @override
  String get videoInfoTitle => 'Video info';
  @override
  String get infoName => 'Name';
  @override
  String get infoType => 'Type';
  @override
  String get infoResolution => 'Resolution';
  @override
  String get infoLength => 'Length';
  @override
  String get infoSize => 'Size';
  @override
  String get infoFolder => 'Folder';
  @override
  String get infoDateAdded => 'Date added';
  @override
  String get infoDateModified => 'Date modified';
  @override
  String get infoPath => 'Path';
  @override
  String get copyPath => 'Copy path';
  @override
  String get pathCopied => 'Path copied';

  @override
  String get minimise => 'Minimise';
  @override
  String get pictureInPicture => 'Picture-in-picture';
  @override
  String get playingQueue => 'Playing queue';
  @override
  String get previous => 'Previous';
  @override
  String get next => 'Next';
  @override
  String get pause => 'Pause';
  @override
  String get lock => 'Lock';
  @override
  String get abRepeat => 'A-B';
  @override
  String get shuffle => 'Shuffle';
  @override
  String get repeat => 'Repeat';
  @override
  String get repeatAll => 'All';
  @override
  String get repeatOne => 'One';
  @override
  String get repeatOff => 'Repeat off';
  @override
  String get sleep => 'Sleep';
  @override
  String get sleepTimer => 'Sleep timer';
  @override
  String get playbackSpeed => 'Playback speed';
  @override
  String get screenLocked => 'Screen is locked — unlock to go back';
  @override
  String get videoCouldNotOpen => 'This video could not be opened.';
  @override
  String abPointSet(String at) => 'A set at $at — tap A-B again for B';
  @override
  String abLooping(String from, String to) => 'Looping $from → $to';
  @override
  String sleepStopsIn(String remaining) => 'Playback stops in $remaining';
  @override
  String get cancelTimer => 'Cancel timer';
  @override
  String minutesOption(int minutes) => '$minutes min';
  @override
  String queueWithCount(int count) => 'Playing queue  ·  $count';

  @override
  String get settings => 'Settings';
  @override
  String get appSettings => 'App settings';
  @override
  String get playbackSettings => 'Playback settings';
  @override
  String get playbackSettingsBody =>
      'Resume, autoplay, gestures, PiP, sleep timer';
  @override
  String get appearance => 'Appearance';
  @override
  String get darkMode => 'Dark mode';
  @override
  String get darkModeBody => 'A dark background with one calm accent';
  @override
  String get followSystemTheme => 'Follow system theme';
  @override
  String get followSystemThemeBody => 'Match whatever the phone is set to';
  @override
  String get language => 'Language';
  @override
  String get languageBody => 'Interface language';
  @override
  String get systemLanguage => 'System language';
  @override
  String get history => 'History';
  @override
  String get showWatchHistory => 'Show watch history';
  @override
  String get showWatchHistoryBody =>
      'Show resume bars and the "Recently played" list on Home';
  @override
  String get clearWatchHistory => 'Clear watch history';
  @override
  String get clearWatchHistoryBody => 'Also clears every saved resume position';
  @override
  String get clearHistoryConfirmTitle => 'Clear watch history?';
  @override
  String get clearHistoryConfirmBody =>
      'Every video will start from the beginning again. The videos themselves '
      'are not touched.';
  @override
  String get historyCleared => 'Watch history cleared';
  @override
  String get playback => 'Playback';
  @override
  String get foldersToScan => 'Folders to scan';
  @override
  String allFoldersHidden(int hidden) => 'All folders  ·  $hidden hidden';
  @override
  String selectedFoldersHidden(int selected, int hidden) =>
      '$selected selected  ·  $hidden hidden';
  @override
  String get rescanDevice => 'Rescan device';
  @override
  String get rescanDeviceBody => 'Look for videos added since the last scan';
  @override
  String get libraryRescanned => 'Library rescanned';
  @override
  String get about => 'About';
  @override
  String get aboutApp => 'About Main Video';
  @override
  String version(String value) => 'Version $value';
  @override
  String get aboutBody =>
      'A local video player for the videos already on this device.\n\n'
      'There is no account and no server: nothing is uploaded, and playlists, '
      'favorites and watch history stay on the phone.';
  @override
  String get library => 'Library';
  @override
  String get statVideos => 'Videos';

  @override
  String get startingAVideo => 'Starting a video';
  @override
  String get resumePlayback => 'Resume playback';
  @override
  String get resumePlaybackBody => 'Continue from where you stopped last time';
  @override
  String get autoplayNext => 'Autoplay next';
  @override
  String get autoplayNextBody =>
      'Play the next video in the same list automatically';
  @override
  String get whilePlaying => 'While playing';
  @override
  String get gestureControls => 'Gesture controls';
  @override
  String get gestureControlsBody =>
      'Swipe sideways to seek, up and down for volume and brightness';
  @override
  String get skipAmount => 'Skip amount';
  @override
  String get skipAmountBody =>
      'How far a double-tap on the left or right jumps';
  @override
  String get keepScreenOn => 'Keep screen on';
  @override
  String get keepScreenOnBody => 'Stop the screen dimming during a video';
  @override
  String get pipTitle => 'Picture-in-picture';
  @override
  String get pipBody =>
      'Shrink the video into a floating window when you leave';
  @override
  String get pipUnsupported =>
      'This device does not support picture-in-picture';
  @override
  String get backgroundPlayback => 'Background playback';
  @override
  String get backgroundPlaybackBody =>
      'Keep the sound going after leaving the app';
  @override
  String get availableInPlayer => 'Available in the player';
  @override
  String get abRepeatBody => 'Show the button that loops a chosen segment';
  @override
  String get sleepTimerBody => 'Show the 15 / 30 / 45 / 60 minute timer';
  @override
  String get defaults => 'Defaults';
  @override
  String get defaultSpeed => 'Default playback speed';
  @override
  String get defaultSpeedBody => 'Every video starts at this speed';
  @override
  String get shuffleByDefault => 'Shuffle by default';
  @override
  String get shuffleByDefaultBody => 'Start every queue in a random order';
  @override
  String get defaultRepeatMode => 'Default repeat mode';
  @override
  String get defaultRepeatModeBody => 'Applied when the player opens';
  @override
  String secondsOption(int seconds) => '$seconds seconds';

  @override
  String get scanFoldersTitle => 'Folders to scan';
  @override
  String get scanningEverything =>
      'Every folder is being scanned. Uncheck one to leave it out.';
  @override
  String scanningSome(int selected, int total) =>
      '$selected of $total folders are being scanned.';
  @override
  String get noFoldersFound => 'No folders found';
  @override
  String get noFoldersFoundBody =>
      'No videos were found anywhere on this device.';
  @override
  String get unhideFolder => 'Unhide folder';
  @override
  String get hideFolder => 'Hide folder';
}

class StringsAr extends Strings {
  const StringsAr();

  @override
  String get languageName => 'العربية';

  @override
  String get appTitle => 'Main Video';
  @override
  String get cancel => 'إلغاء';
  @override
  String get save => 'حفظ';
  @override
  String get create => 'إنشاء';
  @override
  String get delete => 'حذف';
  @override
  String get rename => 'إعادة تسمية';
  @override
  String get clear => 'مسح';
  @override
  String get done => 'تم';
  @override
  String get goBack => 'رجوع';
  @override
  String get all => 'الكل';

  @override
  String videoCount(int count) => switch (count) {
    0 => 'لا فيديوهات',
    1 => 'فيديو واحد',
    2 => 'فيديوهان',
    _ when count <= 10 => '$count فيديوهات',
    _ => '$count فيديو',
  };
  @override
  String selectedCount(int count) => 'تم تحديد $count';

  @override
  String get today => 'اليوم';
  @override
  String get yesterday => 'أمس';
  @override
  String daysAgo(int days) => 'منذ $days أيام';
  @override
  List<String> get months => const [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  String get navHome => 'الرئيسية';
  @override
  String get navFolders => 'المجلدات';
  @override
  String get navFavorites => 'المفضلة';
  @override
  String get navMore => 'المزيد';

  @override
  String get searchVideos => 'ابحث في الفيديوهات';
  @override
  String get search => 'بحث';
  @override
  String get closeSearch => 'إغلاق البحث';
  @override
  String get sort => 'ترتيب';
  @override
  String get gridView => 'عرض شبكي';
  @override
  String get listView => 'عرض قائمة';
  @override
  String get compactView => 'قائمة مصغّرة';
  @override
  String get filterAll => 'الكل';
  @override
  String get filterRecentlyAdded => 'المضاف حديثًا';
  @override
  String get filterRecentlyPlayed => 'المشغّل حديثًا';
  @override
  String get allVideos => 'كل الفيديوهات';
  @override
  String stillScanning(String count) => 'جارٍ الفحص…  $count حتى الآن';
  @override
  String matchingQuery(String count, String query) =>
      '$count مطابقة لـ "$query"';
  @override
  String sortedBy(String count, String field) => '$count  ·  مرتبة حسب $field';
  @override
  String get newestOnDevice => 'أحدث الفيديوهات على جهازك';
  @override
  String get pickUpWhereYouLeftOff => 'أكمل من حيث توقفت';
  @override
  String get nothingFound => 'لا توجد نتائج';
  @override
  String noVideoMatches(String query) => 'لا يوجد فيديو مطابق لـ "$query".';
  @override
  String get nothingWatchedYet => 'لم تشاهد شيئًا بعد';
  @override
  String get nothingWatchedYetBody => 'الفيديوهات التي تبدأ تشغيلها ستظهر هنا.';
  @override
  String get noVideosFound => 'لا توجد فيديوهات';
  @override
  String get noVideosFoundBody =>
      'لم يُعثر على شيء في المجلدات التي يتم فحصها. اسحب للأسفل لإعادة الفحص، '
      'أو غيّر المجلدات المفحوصة من الإعدادات.';

  @override
  String get accessNeeded => 'التطبيق يحتاج إذن الوصول لفيديوهاتك';
  @override
  String get accessNeededBody =>
      'التطبيق يقرأ الفيديوهات الموجودة على هذا الجهاز فقط. لا شيء يُرفع إلى '
      'أي مكان.';
  @override
  String get grantAccess => 'منح الإذن';
  @override
  String get openSettings => 'فتح الإعدادات';
  @override
  String get gettingReady => 'جارٍ التجهيز…';
  @override
  String scanningProgress(int done, int total) =>
      'جارٍ فحص الفيديوهات… $done / $total';
  @override
  String get checkingPermissions => 'جارٍ التحقق من الأذونات…';
  @override
  String get scanningVideos => 'جارٍ فحص الفيديوهات…';

  @override
  String get sortBy => 'الترتيب حسب';
  @override
  String get sortDateAdded => 'تاريخ الإضافة';
  @override
  String get sortLength => 'المدة';
  @override
  String get sortName => 'الاسم';
  @override
  String get sortSize => 'الحجم';
  @override
  String get sortWatchHistory => 'سجل المشاهدة';
  @override
  String get sortCustom => 'ترتيب مخصص';
  @override
  String get sortCustomHint => 'اسحب الفيديوهات للترتيب الذي تريده';
  @override
  String get order => 'الاتجاه';
  @override
  String get descending => 'تنازلي';
  @override
  String get ascending => 'تصاعدي';
  @override
  String get customOrder => 'ترتيب مخصص';

  @override
  String get folders => 'المجلدات';
  @override
  String get playlists => 'قوائم التشغيل';
  @override
  String get deviceFolders => 'مجلدات الجهاز';
  @override
  String get favorites => 'المفضلة';
  @override
  String get newPlaylist => 'قائمة جديدة';
  @override
  String get playlistName => 'اسم القائمة';
  @override
  String get renamePlaylist => 'إعادة تسمية القائمة';
  @override
  String get deletePlaylist => 'حذف القائمة';
  @override
  String get deletePlaylistBody => 'الفيديوهات نفسها تبقى كما هي';
  @override
  String get colorAndIcon => 'اللون والأيقونة';
  @override
  String get colorLabel => 'اللون';
  @override
  String get iconLabel => 'الأيقونة';
  @override
  String get resetToDefault => 'إعادة للافتراضي';
  @override
  String get pinToTop => 'تثبيت في الأعلى';
  @override
  String get unpinFromTop => 'إلغاء التثبيت';
  @override
  String get hideThisFolder => 'إخفاء هذا المجلد';
  @override
  String get hideThisFolderBody => 'يبقى على الجهاز لكن لا يظهر في القائمة';
  @override
  String get addAllToPlaylist => 'إضافة الكل إلى قائمة';
  @override
  String get chooseFoldersToScan => 'اختيار المجلدات المفحوصة';
  @override
  String get noFoldersToShow => 'لا توجد مجلدات';
  @override
  String get noFoldersToShowBody =>
      'إما لم يُعثر على فيديوهات، أو أن كل المجلدات مخفية.';
  @override
  String get playAll => 'تشغيل الكل';
  @override
  String get addVideos => 'إضافة فيديوهات';
  @override
  String addToPlaylistTitle(String name) => 'إضافة إلى $name';
  @override
  String get addToPlaylist => 'إضافة إلى قائمة';
  @override
  String addVideosToPlaylist(int count) =>
      'إضافة ${videoCount(count)} إلى قائمة';
  @override
  String get nothingToAdd => 'لا يوجد ما يُضاف';
  @override
  String get nothingToAddBody => 'كل الفيديوهات موجودة بالفعل في هذه القائمة.';
  @override
  String addedTo(String name) => 'تمت الإضافة إلى $name';
  @override
  String get emptyPlaylist => 'هذه القائمة فارغة';
  @override
  String get emptyPlaylistBody =>
      'استخدم زر + في الأعلى لإضافة فيديوهات من أي مكان.';
  @override
  String get noFavorites => 'لا توجد مفضلات بعد';
  @override
  String get noFavoritesBody =>
      'اضغط مطولًا على أي فيديو واختر "إضافة إلى المفضلة" ليبقى هنا، أيًا كان '
      'مكانه على الجهاز.';
  @override
  String get folderEmpty => 'لا يوجد شيء هنا';
  @override
  String get folderEmptyBody => 'هذا المجلد لم يعد يحتوي على فيديوهات.';
  @override
  String addCount(int count) => 'إضافة $count';

  @override
  String get play => 'تشغيل';
  @override
  String get more => 'المزيد';
  @override
  String get select => 'تحديد';
  @override
  String get addToFavorites => 'إضافة إلى المفضلة';
  @override
  String get removeFromFavorites => 'إزالة من المفضلة';
  @override
  String get removeFromThisPlaylist => 'إزالة من هذه القائمة';
  @override
  String get moveTo => 'نقل إلى…';
  @override
  String get videoInfo => 'معلومات الفيديو';
  @override
  String get deleteFromDevice => 'حذف من الجهاز';
  @override
  String get renameVideo => 'إعادة تسمية الفيديو';
  @override
  String get newName => 'الاسم الجديد';
  @override
  String get renamed => 'تمت إعادة التسمية';
  @override
  String get couldNotRename => 'تعذّرت إعادة تسمية الملف';
  @override
  String get deleteVideoTitle => 'حذف الفيديو؟';
  @override
  String deleteVideoBody(String name) =>
      'سيُحذف "$name" من هذا الجهاز. لا يمكن التراجع عن هذا.';
  @override
  String get videoDeleted => 'تم حذف الفيديو';
  @override
  String get permissionDenied => 'تم رفض الإذن';
  @override
  String get fileGone => 'الملف لم يعد موجودًا';
  @override
  String get couldNotDelete => 'تعذّر حذف الملف';
  @override
  String deleteManyTitle(int count) => 'حذف ${videoCount(count)}؟';
  @override
  String get deleteManyBody =>
      'سيتم حذف الملفات من هذا الجهاز. لا يمكن التراجع عن هذا.';
  @override
  String deletedCount(int count) => 'تم حذف ${videoCount(count)}';
  @override
  String partialDelete(int deleted, int failed) =>
      'تم حذف $deleted، وتعذّر حذف $failed';
  @override
  String get favorite => 'مفضلة';
  @override
  String get unfavorite => 'إزالة';
  @override
  String get addTo => 'إضافة إلى';
  @override
  String get move => 'نقل';
  @override
  String get remove => 'إزالة';
  @override
  String get selectAll => 'تحديد الكل';

  @override
  String moveCount(int count) => 'نقل ${videoCount(count)}';
  @override
  String get moveExplainer =>
      'النقل إلى مجلد يغيّر مكان الملف فعليًا على الجهاز.';
  @override
  String movedCount(int count) => 'تم نقل ${videoCount(count)}';
  @override
  String partialMove(int moved, int failed) =>
      'تم نقل $moved، وتعذّر نقل $failed';
  @override
  String movedToPlaylist(String name) => 'تم النقل إلى $name';

  @override
  String get videoInfoTitle => 'معلومات الفيديو';
  @override
  String get infoName => 'الاسم';
  @override
  String get infoType => 'النوع';
  @override
  String get infoResolution => 'الدقة';
  @override
  String get infoLength => 'المدة';
  @override
  String get infoSize => 'الحجم';
  @override
  String get infoFolder => 'المجلد';
  @override
  String get infoDateAdded => 'تاريخ الإضافة';
  @override
  String get infoDateModified => 'تاريخ التعديل';
  @override
  String get infoPath => 'المسار';
  @override
  String get copyPath => 'نسخ المسار';
  @override
  String get pathCopied => 'تم نسخ المسار';

  @override
  String get minimise => 'تصغير';
  @override
  String get pictureInPicture => 'نافذة عائمة';
  @override
  String get playingQueue => 'قائمة التشغيل';
  @override
  String get previous => 'السابق';
  @override
  String get next => 'التالي';
  @override
  String get pause => 'إيقاف مؤقت';
  @override
  String get lock => 'قفل';
  @override
  String get abRepeat => 'أ-ب';
  @override
  String get shuffle => 'عشوائي';
  @override
  String get repeat => 'تكرار';
  @override
  String get repeatAll => 'الكل';
  @override
  String get repeatOne => 'واحد';
  @override
  String get repeatOff => 'بدون تكرار';
  @override
  String get sleep => 'مؤقت';
  @override
  String get sleepTimer => 'مؤقت النوم';
  @override
  String get playbackSpeed => 'سرعة التشغيل';
  @override
  String get screenLocked => 'الشاشة مقفلة — افتح القفل للرجوع';
  @override
  String get videoCouldNotOpen => 'تعذّر فتح هذا الفيديو.';
  @override
  String abPointSet(String at) => 'تم تحديد أ عند $at — اضغط أ-ب مرة أخرى لـ ب';
  @override
  String abLooping(String from, String to) => 'تكرار من $from إلى $to';
  @override
  String sleepStopsIn(String remaining) => 'سيتوقف التشغيل بعد $remaining';
  @override
  String get cancelTimer => 'إلغاء المؤقت';
  @override
  String minutesOption(int minutes) => '$minutes دقيقة';
  @override
  String queueWithCount(int count) => 'قائمة التشغيل  ·  $count';

  @override
  String get settings => 'الإعدادات';
  @override
  String get appSettings => 'إعدادات التطبيق';
  @override
  String get playbackSettings => 'إعدادات التشغيل';
  @override
  String get playbackSettingsBody =>
      'الاستئناف، التشغيل التلقائي، الإيماءات، النافذة العائمة، المؤقت';
  @override
  String get appearance => 'المظهر';
  @override
  String get darkMode => 'الوضع الداكن';
  @override
  String get darkModeBody => 'خلفية داكنة بلون مميز هادئ';
  @override
  String get followSystemTheme => 'اتباع مظهر النظام';
  @override
  String get followSystemThemeBody => 'مطابقة ما هو مضبوط على الهاتف';
  @override
  String get language => 'اللغة';
  @override
  String get languageBody => 'لغة الواجهة';
  @override
  String get systemLanguage => 'لغة النظام';
  @override
  String get history => 'السجل';
  @override
  String get showWatchHistory => 'إظهار سجل المشاهدة';
  @override
  String get showWatchHistoryBody =>
      'إظهار شريط الاستئناف وقائمة "المشغّل حديثًا" في الرئيسية';
  @override
  String get clearWatchHistory => 'مسح سجل المشاهدة';
  @override
  String get clearWatchHistoryBody => 'يمسح أيضًا كل مواضع الاستئناف المحفوظة';
  @override
  String get clearHistoryConfirmTitle => 'مسح سجل المشاهدة؟';
  @override
  String get clearHistoryConfirmBody =>
      'كل فيديو سيبدأ من البداية مرة أخرى. الفيديوهات نفسها لن تتأثر.';
  @override
  String get historyCleared => 'تم مسح سجل المشاهدة';
  @override
  String get playback => 'التشغيل';
  @override
  String get foldersToScan => 'المجلدات المفحوصة';
  @override
  String allFoldersHidden(int hidden) => 'كل المجلدات  ·  $hidden مخفي';
  @override
  String selectedFoldersHidden(int selected, int hidden) =>
      '$selected محدد  ·  $hidden مخفي';
  @override
  String get rescanDevice => 'إعادة فحص الجهاز';
  @override
  String get rescanDeviceBody => 'البحث عن فيديوهات أُضيفت منذ آخر فحص';
  @override
  String get libraryRescanned => 'تمت إعادة فحص المكتبة';
  @override
  String get about => 'حول';
  @override
  String get aboutApp => 'حول Main Video';
  @override
  String version(String value) => 'الإصدار $value';
  @override
  String get aboutBody =>
      'مشغّل فيديو محلي للفيديوهات الموجودة على هذا الجهاز.\n\n'
      'لا يوجد حساب ولا خادم: لا شيء يُرفع، وقوائم التشغيل والمفضلة وسجل '
      'المشاهدة كلها تبقى على الهاتف.';
  @override
  String get library => 'المكتبة';
  @override
  String get statVideos => 'فيديوهات';

  @override
  String get startingAVideo => 'عند بدء الفيديو';
  @override
  String get resumePlayback => 'استئناف التشغيل';
  @override
  String get resumePlaybackBody => 'المتابعة من حيث توقفت آخر مرة';
  @override
  String get autoplayNext => 'تشغيل التالي تلقائيًا';
  @override
  String get autoplayNextBody => 'تشغيل الفيديو التالي في نفس القائمة تلقائيًا';
  @override
  String get whilePlaying => 'أثناء التشغيل';
  @override
  String get gestureControls => 'التحكم بالإيماءات';
  @override
  String get gestureControlsBody =>
      'اسحب أفقيًا للتقديم، ورأسيًا للصوت والسطوع';
  @override
  String get skipAmount => 'مقدار التقديم';
  @override
  String get skipAmountBody =>
      'المدة التي يقفزها الضغط المزدوج يمينًا أو يسارًا';
  @override
  String get keepScreenOn => 'إبقاء الشاشة مضاءة';
  @override
  String get keepScreenOnBody => 'منع خفوت الشاشة أثناء الفيديو';
  @override
  String get pipTitle => 'النافذة العائمة';
  @override
  String get pipBody => 'تصغير الفيديو في نافذة عائمة عند مغادرة التطبيق';
  @override
  String get pipUnsupported => 'هذا الجهاز لا يدعم النافذة العائمة';
  @override
  String get backgroundPlayback => 'التشغيل في الخلفية';
  @override
  String get backgroundPlaybackBody => 'استمرار الصوت بعد مغادرة التطبيق';
  @override
  String get availableInPlayer => 'متاح في المشغّل';
  @override
  String get abRepeatBody => 'إظهار زر تكرار مقطع محدد';
  @override
  String get sleepTimerBody => 'إظهار مؤقت 15 / 30 / 45 / 60 دقيقة';
  @override
  String get defaults => 'الإعدادات الافتراضية';
  @override
  String get defaultSpeed => 'سرعة التشغيل الافتراضية';
  @override
  String get defaultSpeedBody => 'كل فيديو يبدأ بهذه السرعة';
  @override
  String get shuffleByDefault => 'العشوائي افتراضيًا';
  @override
  String get shuffleByDefaultBody => 'بدء كل قائمة بترتيب عشوائي';
  @override
  String get defaultRepeatMode => 'وضع التكرار الافتراضي';
  @override
  String get defaultRepeatModeBody => 'يُطبَّق عند فتح المشغّل';
  @override
  String secondsOption(int seconds) => '$seconds ثانية';

  @override
  String get scanFoldersTitle => 'المجلدات المفحوصة';
  @override
  String get scanningEverything =>
      'يتم فحص كل المجلدات. ألغِ تحديد أي مجلد لاستبعاده.';
  @override
  String scanningSome(int selected, int total) =>
      'يتم فحص $selected من أصل $total مجلدًا.';
  @override
  String get noFoldersFound => 'لا توجد مجلدات';
  @override
  String get noFoldersFoundBody => 'لم يُعثر على فيديوهات على هذا الجهاز.';
  @override
  String get unhideFolder => 'إظهار المجلد';
  @override
  String get hideFolder => 'إخفاء المجلد';
}

/// Strings added by the phase 3 and 4 improvement rounds.
///
/// Kept as an extension so the base [Strings] contract stays readable; each
/// language resolves them from what it already defines plus these.
extension ImprovementStrings on Strings {
  bool get _isArabic => this is StringsAr;

  // -------------------------------------------------------------- rotation
  String get rotationAuto => _isArabic ? 'تدوير تلقائي' : 'Auto-rotate';
  String get rotationLandscape => _isArabic ? 'أفقي' : 'Landscape';
  String get rotationPortrait => _isArabic ? 'رأسي' : 'Portrait';

  // ------------------------------------------------------------- play all
  String get playInOrder => _isArabic ? 'تشغيل بالترتيب' : 'Play in order';
  String get playShuffled => _isArabic ? 'تشغيل عشوائي' : 'Shuffle';
  String get howToPlay => _isArabic ? 'طريقة التشغيل' : 'How to play';

  // ---------------------------------------------------------- hide videos
  String get hideVideo => _isArabic ? 'إخفاء الفيديو' : 'Hide video';
  String get unhideVideo => _isArabic ? 'إظهار الفيديو' : 'Unhide video';
  String get hiddenVideos => _isArabic ? 'الفيديوهات المخفية' : 'Hidden videos';
  String get hiddenVideosBody => _isArabic
      ? 'تبقى على الجهاز لكن لا تظهر في أي قائمة'
      : 'They stay on the device but appear in no list';
  String get noHiddenVideos =>
      _isArabic ? 'لا توجد فيديوهات مخفية' : 'Nothing is hidden';
  String get noHiddenVideosBody => _isArabic
      ? 'اضغط مطولًا على أي فيديو واختر "إخفاء الفيديو".'
      : 'Long-press any video and choose "Hide video".';
  String get unhideAll => _isArabic ? 'إظهار الكل' : 'Unhide all';
  String hiddenCount(int count) => _isArabic ? '$count مخفي' : '$count hidden';

  // -------------------------------------------------------- recycle bin
  String get recycleBin => _isArabic ? 'سلة المحذوفات' : 'Recycle bin';
  String get recycleBinToggle =>
      _isArabic ? 'استخدام سلة المحذوفات' : 'Use the recycle bin';
  String get recycleBinToggleBody => _isArabic
      ? 'الفيديو المحذوف يروح للسلة بدل ما يُمسح فورًا، وتقدر ترجّعه'
      : 'Deleted videos go to the bin first, so they can be restored';
  String get recycleBinEmpty => _isArabic ? 'السلة فارغة' : 'The bin is empty';
  String get recycleBinEmptyBody => _isArabic
      ? 'الفيديوهات اللي تحذفها هتظهر هنا.'
      : 'Videos you delete will show up here.';
  String get restore => _isArabic ? 'استرجاع' : 'Restore';
  String get restored => _isArabic ? 'تم الاسترجاع' : 'Restored';
  String get deleteForever => _isArabic ? 'حذف نهائي' : 'Delete forever';
  String get emptyBin => _isArabic ? 'تفريغ السلة' : 'Empty the bin';
  String get emptyBinConfirm => _isArabic
      ? 'هيتم حذف كل اللي في السلة نهائيًا. لا يمكن التراجع.'
      : 'Everything in the bin will be erased for good. This cannot be undone.';
  String get movedToBin => _isArabic ? 'تم النقل للسلة' : 'Moved to the bin';
  String daysLeft(int days) => _isArabic
      ? (days <= 0 ? 'هيتمسح قريبًا' : 'باقي $days يوم')
      : (days <= 0 ? 'Clearing soon' : '$days days left');
  String binCount(int count) => _isArabic
      ? (count == 0 ? 'فارغة' : '$count في السلة')
      : (count == 0 ? 'Empty' : '$count in the bin');

  // ------------------------------------------------------ personalisation
  String get accentColor => _isArabic ? 'اللون المميز' : 'Accent color';
  String get accentColorBody => _isArabic
      ? 'اللون المستخدم للعناصر المحددة'
      : 'Used to mark what is selected';
  String get haptics => _isArabic ? 'اهتزاز الإيماءات' : 'Haptic feedback';
  String get hapticsBody => _isArabic
      ? 'اهتزاز خفيف عند التقديم وتغيير الصوت والسطوع'
      : 'A light buzz while seeking or changing volume and brightness';

  String get accentSage => _isArabic ? 'زيتوني' : 'Sage';
  String get accentTerracotta => _isArabic ? 'طيني' : 'Terracotta';
  String get accentIndigo => _isArabic ? 'نيلي' : 'Indigo';
  String get accentPlum => _isArabic ? 'برقوقي' : 'Plum';
  String get accentTeal => _isArabic ? 'تركوازي' : 'Teal';
  String get accentAmber => _isArabic ? 'عنبري' : 'Amber';
  String get accentRose => _isArabic ? 'وردي' : 'Rose';
  String get accentSlate => _isArabic ? 'رمادي' : 'Slate';

  String accentName(String key) => switch (key) {
    'terracotta' => accentTerracotta,
    'indigo' => accentIndigo,
    'plum' => accentPlum,
    'teal' => accentTeal,
    'amber' => accentAmber,
    'rose' => accentRose,
    'slate' => accentSlate,
    _ => accentSage,
  };

  // ------------------------------------------------------------- display
  String get displayMode => _isArabic ? 'وضع العرض' : 'Display';
  String get displayFit => _isArabic ? 'احتواء' : 'Fit';
  String get displayFill => _isArabic ? 'ملء الشاشة' : 'Fill';
  String get displayStretch => _isArabic ? 'مطّ' : 'Stretch';
  String get displayOriginal => _isArabic ? 'الحجم الأصلي' : 'Original size';
  String get resetZoom => _isArabic ? 'إلغاء التكبير' : 'Reset zoom';

  // ---------------------------------------------------------- background
  String get backgroundImage =>
      _isArabic ? 'صورة الخلفية' : 'Background picture';
  String get backgroundImageBody => _isArabic
      ? 'اختر صورة من جهازك لتظهر خلف التطبيق.'
      : 'Pick a photo from your device to show behind the app.';
  String get chooseImage => _isArabic ? 'اختيار صورة' : 'Choose picture';
  String get changeImage => _isArabic ? 'تغيير' : 'Change';
  String get removeImage => _isArabic ? 'إزالة' : 'Remove';
  String get backgroundBlur => _isArabic ? 'درجة التمويه' : 'Blur';
  String get glassStrength => _isArabic ? 'شفافية الزجاج' : 'Glass';
  String get glassStrengthBody => _isArabic
      ? 'اسحب لتتحكم في مدى شفافية البطاقات والأزرار.'
      : 'Slide to set how see-through cards and buttons are.';
}
