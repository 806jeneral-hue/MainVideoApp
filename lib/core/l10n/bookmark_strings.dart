import 'strings.dart';

/// Strings for stop markers and saved moments, in both languages.
extension BookmarkStrings on Strings {
  bool get _ar => this is StringsAr;

  String get markStop =>
      _ar ? 'علّم كآخر فيديو وقفت عنده' : 'Mark where I stopped';
  String get markStopHere => _ar ? 'علّم هنا' : 'Mark this spot';
  String get markStopHereBody => _ar
      ? 'آخر نقطة وقفت عندها في القائمة دي'
      : 'Where you stopped in this list';
  String get clearStop => _ar ? 'شيل العلامة' : 'Remove the mark';
  String markedAt(String time) => _ar ? 'علامة عند $time' : 'Marked at $time';
  String stopMarked(String time) =>
      _ar ? 'اتعلّم عند $time' : 'Marked at $time';
  String get continueFromMark => _ar ? 'كمّل من العلامة' : 'Continue from mark';

  String get addMoment => _ar ? 'احفظ اللحظة دي' : 'Save this moment';
  String get addMomentBody =>
      _ar ? 'تضاف لفهرس لحظات الفيديو' : 'Added to this video’s moments';
  String momentSaved(String time) =>
      _ar ? 'اتحفظت لحظة عند $time' : 'Moment saved at $time';
  String get momentExists =>
      _ar ? 'اللحظة دي محفوظة قبل كده' : 'That moment is already saved';
  String get momentNote => _ar ? 'ملاحظة' : 'Note';
  String get momentNoteHint => _ar
      ? 'اكتب ملاحظة للحظة دي (اختياري)'
      : 'A note for this moment (optional)';
  String momentAt(String time) => _ar ? 'لحظة عند $time' : 'Moment at $time';
  String get editNote => _ar ? 'تعديل الملاحظة' : 'Edit note';
  String get momentsIndex => _ar ? 'فهرس اللحظات' : 'Saved moments';
  String get momentsEmpty => _ar
      ? 'لسه ما حفظتش لحظات في الفيديو ده'
      : 'No moments saved in this video yet';
  String momentLabel(int number) => _ar ? 'لحظة $number' : 'Moment $number';
  String momentsCount(int count) =>
      _ar ? (count == 0 ? 'فاضي' : '$count') : (count == 0 ? 'None' : '$count');
}
