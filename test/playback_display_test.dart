import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/data/models/enums.dart';
import 'package:main_video/state/playback_controller.dart';

void main() {
  group('ZoomState', () {
    test('starts un-zoomed', () {
      expect(ZoomState.none.scale, 1);
      expect(ZoomState.none.offset, Offset.zero);
      expect(ZoomState.none.isZoomed, isFalse);
    });

    test('counts as zoomed only above 1', () {
      const at1 = ZoomState(scale: 1, offset: Offset.zero);
      const above = ZoomState(scale: 1.01, offset: Offset.zero);
      expect(at1.isZoomed, isFalse);
      expect(above.isZoomed, isTrue);
    });

    test('keeps the pan it was given', () {
      const state = ZoomState(scale: 2, offset: Offset(12, -8));
      expect(state.offset, const Offset(12, -8));
    });
  });

  group('VideoFit', () {
    test('has a name in both languages', () {
      const en = StringsEn();
      const ar = StringsAr();
      for (final fit in VideoFit.values) {
        expect(fit.label(en), isNotEmpty);
        expect(fit.label(ar), isNotEmpty);
      }
      expect(VideoFit.fit.label(en), isNot(VideoFit.fill.label(en)));
    });
  });

  group('LoopMode', () {
    test('has a name in both languages', () {
      const en = StringsEn();
      const ar = StringsAr();
      for (final mode in LoopMode.values) {
        expect(mode.label(en), isNotEmpty);
        expect(mode.label(ar), isNotEmpty);
      }
    });
  });
}
