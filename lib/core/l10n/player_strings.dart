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
}
