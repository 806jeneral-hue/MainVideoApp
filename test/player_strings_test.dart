import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';

void main() {
  group('Swipe seek speed labels', () {
    test('Arabic spells out seconds and minutes', () {
      const ar = StringsAr();
      expect(ar.swipeSeekOption(0), 'حسب طول الفيديو');
      expect(ar.swipeSeekOption(30), '30 ثانية');
      expect(ar.swipeSeekOption(60), 'دقيقة');
      expect(ar.swipeSeekOption(120), 'دقيقتين');
      expect(ar.swipeSeekOption(300), '5 دقايق');
      // Typed-in amounts that are not whole minutes stay in seconds.
      expect(ar.swipeSeekOption(90), '90 ثانية');
      expect(ar.swipeSeekOption(15), '15 ثانية');
    });

    test('English uses short units', () {
      const en = StringsEn();
      expect(en.swipeSeekOption(0), 'By video length');
      expect(en.swipeSeekOption(30), '30 s');
      expect(en.swipeSeekOption(600), '10 min');
    });
  });
}
