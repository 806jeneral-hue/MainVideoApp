import '../l10n/strings.dart';

/// Small formatting helpers shared by the whole UI.
///
/// Anything with words in it takes the active [Strings] so it follows the
/// interface language; the purely numeric helpers do not need it.
class Fmt {
  const Fmt._();

  /// `1:02:03` for long videos, `2:03` for short ones.
  static String duration(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  static String durationMs(int ms) => duration(Duration(milliseconds: ms));

  /// `1.4 GB`, `320 MB`, `18 KB`.
  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final decimals = unit == 0 || size >= 100 ? 0 : 1;
    return '${size.toStringAsFixed(decimals)} ${units[unit]}';
  }

  /// `12 Mar 2025`
  static String date(DateTime d, Strings s) =>
      '${d.day} ${s.months[d.month - 1]} ${d.year}';

  /// `12 Mar 2025, 21:04`
  static String dateTime(DateTime d, Strings s) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${date(d, s)}, $hh:$mm';
  }

  /// `Today`, `Yesterday`, `3 days ago`, then falls back to a date.
  static String relativeDate(DateTime d, Strings s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final days = today.difference(that).inDays;
    if (days <= 0) return s.today;
    if (days == 1) return s.yesterday;
    if (days < 7) return s.daysAgo(days);
    return date(d, s);
  }

  /// `1.5x`, `2x` — trailing `.0` trimmed.
  static String speed(double value) {
    final text = value.toStringAsFixed(2);
    return '${text.replaceAll(RegExp(r'\.?0+$'), '')}x';
  }
}
