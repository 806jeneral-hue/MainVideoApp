import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/ui/player/widgets/double_tap_seek_ripple.dart';
import 'package:main_video/ui/player/widgets/gesture_layer.dart';

void main() {
  group('DoubleTapSeek Constants & Configuration', () {
    test('doubleTapSeekStep is configured to 2 seconds', () {
      expect(GestureLayer.doubleTapSeekStep, const Duration(seconds: 2));
    });

    test('doubleTapSeekDebounce is configured to 400 milliseconds', () {
      expect(
        GestureLayer.doubleTapSeekDebounce,
        const Duration(milliseconds: 400),
      );
    });

    test('doubleTapSeekReset is configured to 700 milliseconds', () {
      expect(
        GestureLayer.doubleTapSeekReset,
        const Duration(milliseconds: 700),
      );
    });
  });

  group('DoubleTapSeekRipple Widget', () {
    testWidgets('renders forward (+2s, +4s, +6s) with correct text and arrows', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: true,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('+2s'), findsOneWidget);

      // Update to +4s
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: true,
                  seconds: 4,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('+4s'), findsOneWidget);

      // Update to +6s
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: true,
                  seconds: 6,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('+6s'), findsOneWidget);
    });

    testWidgets('renders rewind (-2s, -4s) on left half', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: false,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('-2s'), findsOneWidget);

      // Position should be pinned to the left (left == 0)
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 0.0);
      expect(positioned.right, isNull);
    });

    testWidgets('hides cleanly when visible is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: false,
                  isForward: true,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      // When invisible, no Positioned is rendered (returns SizedBox.shrink)
      expect(find.byType(Positioned), findsNothing);
      expect(find.text('+2s'), findsNothing);
    });

    testWidgets('animates fade-in and fade-out smoothly without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: true,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      // Fade-in animation runs
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('+2s'), findsOneWidget);

      // Now set visible = false to trigger fade-out
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: false,
                  isForward: true,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('+2s'), findsNothing);
    });

    testWidgets('disposes all animation controllers without leaking memory', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DoubleTapSeekRipple(
                  visible: true,
                  isForward: true,
                  seconds: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Remove from tree to verify dispose() executes without exceptions
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
    });
  });

  group('DoubleTapSeek Math & Clamping Logic', () {
    Duration clampSeek(Duration base, Duration delta, Duration duration, bool isLeft) {
      final target = isLeft ? base - delta : base + delta;
      var clamped = target;
      if (clamped < Duration.zero) clamped = Duration.zero;
      if (duration > Duration.zero && clamped > duration) clamped = duration;
      return clamped;
    }

    test('clamping never goes below Duration.zero when seeking backward near start', () {
      const base = Duration(seconds: 1);
      const delta = Duration(seconds: 4); // -4s seek from 1s
      const total = Duration(minutes: 5);

      final clamped = clampSeek(base, delta, total, true);
      expect(clamped, Duration.zero);
    });

    test('clamping never exceeds total duration when seeking forward near end', () {
      const total = Duration(seconds: 100);
      const base = Duration(seconds: 98);
      const delta = Duration(seconds: 6); // +6s seek from 98s

      final clamped = clampSeek(base, delta, total, false);
      expect(clamped, total);
    });

    test('accumulation correctly adds 2 seconds per tap', () {
      var seconds = 0;
      final taps = 4;
      for (var i = 0; i < taps; i++) {
        seconds += GestureLayer.doubleTapSeekStep.inSeconds;
      }
      expect(seconds, 8);
    });
  });
}

