import 'strings.dart';

/// Strings for the music section and the reorganised header, in both
/// languages.
extension MusicStrings on Strings {
  bool get _ar => this is StringsAr;

  // --------------------------------------------------------------- header
  String get viewLayout => _ar ? 'طريقة العرض' : 'Layout';
  String get sortAndLayout => _ar ? 'الترتيب والعرض' : 'Sort and layout';

  // ------------------------------------------------------------ navigation
  String get navMusic => _ar ? 'الموسيقى' : 'Music';
  String get music => _ar ? 'الموسيقى' : 'Music';

  // ------------------------------------------------------------- sections
  String get songs => _ar ? 'الأغاني' : 'Songs';
  String get albums => _ar ? 'الألبومات' : 'Albums';
  String get artists => _ar ? 'الفنانين' : 'Artists';
  String get musicFolders => _ar ? 'الفولدرات' : 'Folders';
  String get musicPlaylists => _ar ? 'قوائم التشغيل' : 'Playlists';

  String songCount(int n) {
    if (!_ar) return n == 1 ? '1 song' : '$n songs';
    if (n == 1) return 'أغنية واحدة';
    if (n == 2) return 'أغنيتان';
    if (n >= 3 && n <= 10) return '$n أغاني';
    return '$n أغنية';
  }

  String albumCount(int n) {
    if (!_ar) return n == 1 ? '1 album' : '$n albums';
    if (n == 1) return 'ألبوم واحد';
    if (n == 2) return 'ألبومان';
    if (n >= 3 && n <= 10) return '$n ألبومات';
    return '$n ألبوم';
  }

  String get unknownArtist => _ar ? 'فنان غير معروف' : 'Unknown artist';
  String get unknownAlbum => _ar ? 'ألبوم غير معروف' : 'Unknown album';

  // -------------------------------------------------------------- actions
  String get playAll => _ar ? 'تشغيل الكل' : 'Play all';
  String get shuffleAll => _ar ? 'عشوائي' : 'Shuffle';
  String get nowPlaying => _ar ? 'يتم التشغيل الآن' : 'Now playing';
  String get continueListening => _ar ? 'كمّل الاستماع' : 'Continue listening';
  String get shuffleAllSongs =>
      _ar ? 'تشغيل عشوائي لكل الأغاني' : 'Shuffle all songs';
  String get recentlyAddedSongs => _ar ? 'أضيفت مؤخرًا' : 'Recently added';
  String get seeAll => _ar ? 'عرض الكل' : 'See all';
  String playingFrom(String source) =>
      _ar ? 'يتم التشغيل من $source' : 'Playing from $source';
  String get playNext => _ar ? 'تشغيل بعد الحالية' : 'Play next';
  String get addToQueue => _ar ? 'إضافة لقائمة الانتظار' : 'Add to queue';
  String get addedToQueue => _ar ? 'اتضافت لقائمة الانتظار' : 'Added to queue';
  String get willPlayNext => _ar ? 'هتشتغل بعد الحالية' : 'Will play next';
  String get addToMusicPlaylist =>
      _ar ? 'إضافة لقائمة تشغيل' : 'Add to playlist';
  String get removeFromThisPlaylist =>
      _ar ? 'إزالة من القائمة' : 'Remove from playlist';
  String get goToAlbum => _ar ? 'فتح الألبوم' : 'Go to album';
  String get goToArtist => _ar ? 'فتح الفنان' : 'Go to artist';
  String get songInfo => _ar ? 'معلومات الأغنية' : 'Song info';
  String get deleteSong => _ar ? 'حذف الأغنية' : 'Delete song';
  String deleteSongBody(String title) => _ar
      ? 'هتتمسح "$title" من الموبايل نهائيًا.'
      : '"$title" will be permanently deleted from this device.';
  String get songDeleted => _ar ? 'اتحذفت الأغنية' : 'Song deleted';

  // ------------------------------------------------------------ favourites
  String get favoriteSongs => _ar ? 'الأغاني المفضلة' : 'Favorite songs';
  String get addToFavorites => _ar ? 'إضافة للمفضلة' : 'Add to favorites';
  String get removeFromFavorites =>
      _ar ? 'إزالة من المفضلة' : 'Remove from favorites';
  String get noFavoriteSongs =>
      _ar ? 'مفيش أغاني مفضلة لسه' : 'No favorite songs yet';
  String get noFavoriteSongsBody => _ar
      ? 'دوس على ♡ في شاشة التشغيل أو في قائمة الأغنية.'
      : 'Tap ♡ on the player or in a song\'s menu.';

  // --------------------------------------------------------------- recent
  String get recentlyPlayedSongs => _ar ? 'آخر ما اتشغل' : 'Recently played';
  String get nothingPlayedYet =>
      _ar ? 'مفيش أغاني اتشغلت لسه' : 'Nothing played yet';
  String get nothingPlayedYetBody => _ar
      ? 'الأغاني اللي بتسمعها هتظهر هنا.'
      : 'Songs you listen to will show up here.';

  // ------------------------------------------------------------ playlists
  String get newMusicPlaylist => _ar ? 'قائمة جديدة' : 'New playlist';
  String get noMusicPlaylists =>
      _ar ? 'مفيش قوائم تشغيل لسه' : 'No playlists yet';
  String get noMusicPlaylistsBody => _ar
      ? 'اعمل قائمة وضيف لها أغانيك.'
      : 'Create one and add your songs to it.';
  String get emptyMusicPlaylist =>
      _ar ? 'القائمة فاضية' : 'This playlist is empty';
  String get emptyMusicPlaylistBody =>
      _ar ? 'ضيف أغاني من قائمة أي أغنية.' : 'Add songs from any song\'s menu.';
  String addedToPlaylist(String name) =>
      _ar ? 'اتضافت لـ $name' : 'Added to $name';

  // --------------------------------------------------------------- search
  String get searchMusic =>
      _ar ? 'ابحث عن أغنية أو فنان أو ألبوم' : 'Search songs, artists, albums';
  String noMusicMatches(String query) =>
      _ar ? 'مفيش نتائج لـ "$query"' : 'Nothing matches "$query"';

  // ----------------------------------------------------------------- sort
  String get sortTitle => _ar ? 'الاسم' : 'Title';
  String get sortArtist => _ar ? 'الفنان' : 'Artist';
  String get sortAlbum => _ar ? 'الألبوم' : 'Album';
  String get sortDateAdded => _ar ? 'تاريخ الإضافة' : 'Date added';
  String get sortDuration => _ar ? 'المدة' : 'Duration';

  // ---------------------------------------------------------------- states
  String get musicPermissionTitle =>
      _ar ? 'اسمح بالوصول للموسيقى' : 'Allow access to music';
  String get musicPermissionBody => _ar
      ? 'عشان نعرض الأغاني اللي على موبايلك. مفيش حاجة بتخرج من الجهاز.'
      : 'So your songs can be listed. Nothing leaves your device.';
  String get allowAccess => _ar ? 'السماح' : 'Allow';
  String get openSettings => _ar ? 'فتح الإعدادات' : 'Open settings';
  String get scanningMusic =>
      _ar ? 'بندوّر على الأغاني...' : 'Looking for songs…';
  String get noSongsFound =>
      _ar ? 'مفيش أغاني على الجهاز' : 'No songs on this device';
  String get noSongsFoundBody => _ar
      ? 'الأغاني اللي تحمّلها أو تنقلها للموبايل هتظهر هنا.'
      : 'Songs you download or copy to the phone will show up here.';

  // ---------------------------------------------- the music player's menu
  String get sectionSong => _ar ? 'الأغنية' : 'Song';
  String get tileAlbum => _ar ? 'الألبوم' : 'Album';
  String get tileArtist => _ar ? 'الفنان' : 'Artist';
  String get tileQueue => _ar ? 'الطابور' : 'Queue';
  String get playNextShort => _ar ? 'التالي' : 'Next';
  String deleteSongsTitle(int count) =>
      _ar ? 'حذف $count أغنية؟' : 'Delete $count songs?';
  String get deleteSongsBody => _ar
      ? 'هتتمسح من الجهاز نهائيًا.'
      : 'They will be removed from the device for good.';
}
