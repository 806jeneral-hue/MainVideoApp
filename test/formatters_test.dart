import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/strings.dart';
import 'package:main_video/core/utils/formatters.dart';

void main() {
  group('Fmt.duration', () {
    test('drops the hour part for short videos', () {
      expect(Fmt.duration(const Duration(minutes: 2, seconds: 3)), '2:03');
      expect(Fmt.duration(const Duration(seconds: 9)), '0:09');
    });

    test('pads minutes once hours appear', () {
      expect(
        Fmt.duration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('never renders a negative position', () {
      expect(Fmt.duration(const Duration(seconds: -5)), '0:00');
    });
  });

  group('Fmt.fileSize', () {
    test('steps through the units', () {
      expect(Fmt.fileSize(0), '0 B');
      expect(Fmt.fileSize(512), '512 B');
      expect(Fmt.fileSize(1536), '1.5 KB');
      expect(Fmt.fileSize(5 * 1024 * 1024), '5.0 MB');
    });

    test('drops the decimal for large values in a unit', () {
      expect(Fmt.fileSize(700 * 1024 * 1024), '700 MB');
    });
  });

  group('Fmt.speed', () {
    test('trims trailing zeros', () {
      expect(Fmt.speed(1.0), '1x');
      expect(Fmt.speed(1.5), '1.5x');
      expect(Fmt.speed(0.25), '0.25x');
    });
  });

  group('Fmt.relativeDate', () {
    const s = StringsEn();
    test('names the last few days', () {
      final now = DateTime.now();
      expect(Fmt.relativeDate(now, s), 'Today');
      expect(
        Fmt.relativeDate(now.subtract(const Duration(days: 1)), s),
        'Yesterday',
      );
      expect(
        Fmt.relativeDate(now.subtract(const Duration(days: 3)), s),
        '3 days ago',
      );
    });

    test('falls back to a full date beyond a week', () {
      expect(Fmt.relativeDate(DateTime(2025, 3, 12), s), '12 Mar 2025');
    });
  });
}
