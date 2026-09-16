import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/strings.dart';

/// Guards against a language that is missing or malformed. Every string is
/// declared abstract, so a missing translation cannot compile — these checks
/// cover the things the compiler cannot see: empty values, placeholders that
/// were dropped, and plural forms.
void main() {
  const languages = <String, Strings>{'en': StringsEn(), 'ar': StringsAr()};

  group('every language', () {
    for (final entry in languages.entries) {
      final code = entry.key;
      final s = entry.value;

      test('$code has no empty strings', () {
        for (final value in [
          s.languageName,
          s.appTitle,
          s.cancel,
          s.save,
          s.delete,
          s.navHome,
          s.navFolders,
          s.navFavorites,
          s.navMore,
          s.searchVideos,
          s.sortBy,
          s.settings,
          s.language,
          s.playAll,
          s.lock,
          s.shuffle,
          s.repeat,
          s.sleep,
          s.aboutBody,
        ]) {
          expect(value.trim(), isNotEmpty);
        }
      });

      test('$code keeps the values inside its placeholders', () {
        expect(s.matchingQuery('5', 'trip'), contains('trip'));
        expect(s.matchingQuery('5', 'trip'), contains('5'));
        expect(s.addedTo('Holiday'), contains('Holiday'));
        expect(s.movedToPlaylist('Holiday'), contains('Holiday'));
        expect(s.deleteVideoBody('clip.mp4'), contains('clip.mp4'));
        expect(s.version('1.0.0'), contains('1.0.0'));
        expect(s.partialDelete(2, 3), contains('2'));
        expect(s.partialDelete(2, 3), contains('3'));
        expect(s.scanningSome(2, 9), contains('9'));
        expect(s.minutesOption(30), contains('30'));
        expect(s.secondsOption(15), contains('15'));
      });

      test('$code counts videos without losing the number', () {
        for (final n in [0, 1, 2, 5, 11, 143]) {
          final text = s.videoCount(n);
          expect(text.trim(), isNotEmpty, reason: 'count $n');
          if (n > 2) expect(text, contains('$n'), reason: 'count $n');
        }
      });

      test('$code has twelve month names', () {
        expect(s.months, hasLength(12));
        for (final month in s.months) {
          expect(month.trim(), isNotEmpty);
        }
      });
    }
  });

  test('the two languages are actually different', () {
    expect(const StringsEn().navHome, isNot(const StringsAr().navHome));
    expect(const StringsEn().settings, isNot(const StringsAr().settings));
  });
}
