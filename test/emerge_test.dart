import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/ui/common/emerge.dart';
import 'package:main_video/ui/common/tab_scroll.dart';

void main() {
  group('EmergeFromBottom.computeMetrics unit tests', () {
    const double line = 2000.0;
    const double itemHeight = 100.0;

    test('row entirely above the bar line is at full opacity and full scale', () {
      // globalTop = 1800, bottom = 1900, line = 2000 (100 px above line)
      final m = EmergeFromBottom.computeMetrics(
        globalTop: 1800.0,
        itemHeight: itemHeight,
        line: line,
      );

      expect(m.visibleFraction, 1.0);
      expect(m.t, 0.0);
      expect(m.alpha, 255);
      expect(m.scale, 1.0);
    });

    test('row mostly above the bar line stays at full opacity and scale', () {
      // 60% of the row is above the line (globalTop = 1940, bottom = 2040)
      final m60 = EmergeFromBottom.computeMetrics(
        globalTop: 1940.0,
        itemHeight: itemHeight,
        line: line,
      );
      expect(m60.visibleFraction, 0.60);
      expect(m60.t, 0.0);
      expect(m60.alpha, 255);
      expect(m60.scale, 1.0);

      // 50% of the row is above the line (globalTop = 1950, bottom = 2050)
      final m50 = EmergeFromBottom.computeMetrics(
        globalTop: 1950.0,
        itemHeight: itemHeight,
        line: line,
      );
      expect(m50.visibleFraction, 0.50);
      expect(m50.t, 0.0);
      expect(m50.alpha, 255);
      expect(m50.scale, 1.0);

      // Exactly at the threshold (35% visible)
      final m35 = EmergeFromBottom.computeMetrics(
        globalTop: 1965.0,
        itemHeight: itemHeight,
        line: line,
      );
      expect(m35.visibleFraction, closeTo(0.35, 1e-6));
      expect(m35.t, 0.0);
      expect(m35.alpha, 255);
      expect(m35.scale, 1.0);
    });

    test('row fully or nearly fully behind the bar is hidden (alpha = 0)', () {
      // globalTop exactly at line (0% visible above line)
      final m0 = EmergeFromBottom.computeMetrics(
        globalTop: 2000.0,
        itemHeight: itemHeight,
        line: line,
      );
      expect(m0.visibleFraction, 0.0);
      expect(m0.t, 1.0);
      expect(m0.alpha, 0);
      expect(m0.scale, EmergeFromBottom.minScale);

      // globalTop past line (sunk below the bar line)
      final mPast = EmergeFromBottom.computeMetrics(
        globalTop: 2050.0,
        itemHeight: itemHeight,
        line: line,
      );
      expect(mPast.visibleFraction, 0.0);
      expect(mPast.t, 1.0);
      expect(mPast.alpha, 0);
      expect(mPast.scale, EmergeFromBottom.minScale);
    });

    test('values are strictly monotonic and continuous with no jumps', () {
      int previousAlpha = 256;
      double previousScale = 1.01;

      // Sample 100 points from visibleFraction 0.40 down to -0.05
      for (double frac = 0.40; frac >= -0.05; frac -= 0.005) {
        final top = line - frac * itemHeight;
        final m = EmergeFromBottom.computeMetrics(
          globalTop: top,
          itemHeight: itemHeight,
          line: line,
        );

        // Alpha is always in valid byte range
        expect(m.alpha, inInclusiveRange(0, 255));
        // Scale is always in [_minScale, 1.0]
        expect(m.scale, inInclusiveRange(EmergeFromBottom.minScale, 1.0));

        // Monotonicity: as fraction decreases, alpha and scale never increase
        expect(m.alpha, lessThanOrEqualTo(previousAlpha));
        expect(m.scale, lessThanOrEqualTo(previousScale));

        // Continuity check: consecutive steps (step size 0.005) must not have big jumps
        if (frac <= EmergeFromBottom.fadeStartVisibleFraction && frac >= 0.0) {
          final alphaDelta = (previousAlpha - m.alpha).abs();
          // With 100 steps over 0.35 range, max alpha delta per 0.005 step should be small (< 25)
          expect(alphaDelta, lessThan(25),
              reason: 'Alpha jumped too abruptly at frac=$frac');
        }

        previousAlpha = m.alpha;
        previousScale = m.scale;
      }
    });

    test('handles zero or negative itemHeight gracefully', () {
      final mZero = EmergeFromBottom.computeMetrics(
        globalTop: 2000.0,
        itemHeight: 0.0,
        line: line,
      );
      expect(mZero.alpha, 255);
      expect(mZero.scale, 1.0);

      final mNeg = EmergeFromBottom.computeMetrics(
        globalTop: 2000.0,
        itemHeight: -10.0,
        line: line,
      );
      expect(mNeg.alpha, 255);
      expect(mNeg.scale, 1.0);
    });
  });

  group('EmergeFromBottom widget tests', () {
    testWidgets('non-tab context does not apply emerge box effect',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmergeFromBottom(
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      // In non-tab context, EmergeFromBottom does not wrap child in RepaintBoundary
      final emergeBoundaries = find.descendant(
        of: find.byType(EmergeFromBottom),
        matching: find.byType(RepaintBoundary),
      );
      expect(emergeBoundaries, findsNothing);
    });

    testWidgets('tab context applies RepaintBoundary and emerge box',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabScroll(
              controller: controller,
              child: const EmergeFromBottom(
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      // In tab context, child inside EmergeFromBottom is wrapped in RepaintBoundary
      final emergeBoundaries = find.descendant(
        of: find.byType(EmergeFromBottom),
        matching: find.byType(RepaintBoundary),
      );
      expect(emergeBoundaries, findsOneWidget);
    });
  });
}
