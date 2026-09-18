import 'strings.dart';

/// Strings for player gestures and their settings, in both languages.
extension PlayerStrings on Strings {
  bool get _ar => this is StringsAr;

  String get swipeSeekSpeed => _ar ? 'سرعة التقديم بالسحب' : 'Swipe seek speed';
  String get swipeSeekSpeedBody => _ar
      ? 'قد إيه سحبة بعرض الشاشة بتقدّم أو ترجّع الفيديو'
      : 'How far one full-width swipe moves the video';
  String get swipeSeekAuto => _ar ? 'حسب طول الفيديو' : 'By video length';
  String get swipeSeekCustom => _ar ? 'تخصيص' : 'Custom';
  String get swipeSeekCustomBody => _ar
      ? 'كام ثانية تتقدّم أو ترجع لما تسحب بعرض الشاشة كلها؟'
      : 'How many seconds should a full-width swipe move?';
  String get swipeSeekInvalid =>
      _ar ? 'اكتب رقم من 1 لـ 3600' : 'Enter a number from 1 to 3600';
  String get secondsUnit => _ar ? 'ثانية' : 'seconds';

  /// How far a full swipe moves: seconds or minutes, spelled out.
  String swipeSeekOption(int seconds) {
    if (seconds <= 0) return swipeSeekAuto;
    // Whole minutes read as minutes; anything else stays in seconds.
    if (seconds < 60 || seconds % 60 != 0) {
      return _ar ? '$seconds ثانية' : '$seconds s';
    }
    final minutes = seconds ~/ 60;
    if (!_ar) return '$minutes min';
    if (minutes == 1) return 'دقيقة';
    if (minutes == 2) return 'دقيقتين';
    return '$minutes دقايق';
  }

  // The More menu's sections and tiles.
  String get sectionPlayback => _ar ? 'التشغيل' : 'Playback';
  String get sectionMarks => _ar ? 'العلامات' : 'Marks';
  String get sectionVideo => _ar ? 'الفيديو' : 'Video';
  String get switchOn => _ar ? 'شغّال' : 'On';
  String get switchOff => _ar ? 'مقفول' : 'Off';
  String get saveMomentShort => _ar ? 'احفظ لحظة' : 'Save moment';
  String momentsShort(int count) =>
      _ar ? 'الفهرس ($count)' : 'Moments ($count)';
  String get tileFavorite => _ar ? 'المفضلة' : 'Favourite';
  String get tilePlaylist => _ar ? 'لقائمة' : 'Playlist';
  String get tileMove => _ar ? 'نقل' : 'Move';
  String get tileRename => _ar ? 'تسمية' : 'Rename';
  String get tileHide => _ar ? 'إخفاء' : 'Hide';
  String get tileUnhide => _ar ? 'إظهار' : 'Unhide';
  String get tileInfo => _ar ? 'معلومات' : 'Info';
  String get tilePin => _ar ? 'تثبيت' : 'Pin';
  String get tileRemoveFromList => _ar ? 'شيل من القائمة' : 'Remove';
  String get tileMark => _ar ? 'علامة' : 'Mark';
  String get tileMarked => _ar ? 'شيل العلامة' : 'Unmark';

  // ------------------------------------------------ custom play sessions
  String get planTitle => _ar ? 'تشغيل مخصص' : 'Custom play';
  String get planOrderHint => _ar
      ? 'هيشتغلوا بالترتيب ده — اسحب عشان ترتّب'
      : 'They play in this order — drag to rearrange';
  String get planEmpty => _ar
      ? 'دوس على اللي عايزه يشتغل من تحت'
      : 'Tap what you want to play below';
  String get planRest =>
      _ar ? 'الباقي — دوس عشان تضيف' : 'The rest — tap to add';
  String get planClear => _ar ? 'مسح الاختيار' : 'Clear';
  String get planRemove => _ar ? 'شيل' : 'Remove';
  String get planStartEmpty =>
      _ar ? 'اختار حاجة الأول' : 'Choose something first';
  String planStart(String count, int plays) =>
      _ar ? 'ابدأ · $count · $plays مرة' : 'Start · $count · $plays plays';
  String planLast(String count, int plays) => _ar
      ? 'آخر جلسة: $count · $plays مرة'
      : 'Last time: $count · $plays plays';
  String get continueLastVideo =>
      _ar ? 'كمّل آخر فيديو' : 'Continue last video';
  String get continueLastSong => _ar ? 'كمّل آخر أغنية' : 'Continue last song';
  String get quickMenuTip => _ar
      ? 'اضغط مطوّل على الرئيسية أو الموسيقى للاختصارات'
      : 'Hold Home or Music for shortcuts';
}
