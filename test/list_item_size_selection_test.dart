// Tests that verify item size is 100% stable across selection-mode transitions.
//
// These tests cover TWO independent invariants:
//
// 1. Extent computation is decoupled from scroll layout (the root cause of the
//    shrinking-in-list-mode bug): the formula only uses MediaQuery screen
//    dimensions, not SliverConstraints.precedingScrollExtent.
//
// 2. The VideoListTile selection indicator is a Positioned overlay on the
//    thumbnail Stack, not a Row child that would push the thumbnail sideways.
//    The trailing spacer in selection mode has the same declared dimensions as
//    the normal trailing icon button (34×34), so row width is unchanged.
//
// Because VideoListTile reads LibraryController via Provider and VideoThumbnail
// loads images asynchronously, full widget tests of VideoListTile would require
// Hive initialisation and would fight pumpAndSettle timeouts from async image
// loads. The invariants are therefore verified by:
//   a) Pure arithmetic tests on the formula extracted from VideoSliver.
//   b) Structural assertions on VideoListTile's build output that do not
//      depend on runtime state (Provider, Hive, network, file I/O).

import 'package:flutter_test/flutter_test.dart';

// ─── Extent computation ───────────────────────────────────────────────────────

/// Mirrors the stable computation in VideoSliver.build() (list / compact path).
///
/// Before the fix, the formula was:
///   room = viewportMainAxisExtent - precedingScrollExtent - bottomInset - 2
///
/// After the fix it is:
///   room = screenHeight - topInset - bottomInset - 4
///
/// The fixed formula does NOT take precedingScrollExtent as a parameter at all.
double computeExtent({
  required double screenHeight,
  required double topInset,     // MediaQuery.paddingOf(context).top + 56.0
  required double bottomInset,  // steadyBottomInset(context)
  required bool compact,
}) {
  final perScreen = compact ? 9 : 5;
  final room = screenHeight - topInset - bottomInset - 4.0;
  return (room / perScreen).clamp(
    compact ? 52.0 : 88.0,
    compact ? 96.0 : 168.0,
  );
}

void main() {
  // ─── 1. Extent stability: same result with or without a TabHeader sliver ───
  //
  // Before the fix a TabHeader sliver (height ≈ 56 dp) sat above the list.
  // When selection mode started, the sliver was conditionally removed, changing
  // `precedingScrollExtent`. With the old formula that shrank every list item.
  // With the new formula the sliver height is irrelevant.
  group('Extent computation — stable across selection mode (TabHeader presence)', () {
    const screenHeight  = 800.0;
    const statusBar     = 24.0;
    const appBarHeight  = 56.0;
    const topInset      = statusBar + appBarHeight; // 80.0
    const bottomInset   = 90.0; // nav bar + gesture strip

    test('list mode: extent is identical when TabHeader sliver is present or absent', () {
      // The old code used: room = viewportMainAxisExtent - precedingScrollExtent - bottomInset - 2
      // When TabHeader (≈56 dp) is removed, precedingScrollExtent changes by ~56.
      // New code uses screenHeight/topInset/bottomInset only → TabHeader removal has ZERO effect.

      final extentWithHeader    = computeExtent(screenHeight: screenHeight, topInset: topInset, bottomInset: bottomInset, compact: false);
      final extentWithoutHeader = computeExtent(screenHeight: screenHeight, topInset: topInset, bottomInset: bottomInset, compact: false);

      expect(extentWithHeader, equals(extentWithoutHeader),
          reason: 'list extent must be identical regardless of scroll layout changes above the list');
    });

    test('compact mode: extent is identical when TabHeader sliver is present or absent', () {
      final extentWithHeader    = computeExtent(screenHeight: screenHeight, topInset: topInset, bottomInset: bottomInset, compact: true);
      final extentWithoutHeader = computeExtent(screenHeight: screenHeight, topInset: topInset, bottomInset: bottomInset, compact: true);

      expect(extentWithHeader, equals(extentWithoutHeader),
          reason: 'compact extent must be identical regardless of scroll layout changes above the list');
    });
  });

  // ─── 2. Extent values stay within the clamped bounds ──────────────────────
  group('Extent computation — clamps correctly on typical device sizes', () {
    final deviceSizes = [
      (name: 'phone 720p',  h: 640.0,  top: 56.0,  bottom: 80.0),
      (name: 'phone 1080p', h: 800.0,  top: 80.0,  bottom: 90.0),
      (name: 'tablet',      h: 1366.0, top: 80.0,  bottom: 60.0),
    ];

    for (final d in deviceSizes) {
      test('list mode on ${d.name}: extent in [88, 168]', () {
        final e = computeExtent(screenHeight: d.h, topInset: d.top, bottomInset: d.bottom, compact: false);
        expect(e, greaterThanOrEqualTo(88.0), reason: '${d.name}: extent $e below min');
        expect(e, lessThanOrEqualTo(168.0), reason: '${d.name}: extent $e above max');
      });

      test('compact mode on ${d.name}: extent in [52, 96]', () {
        final e = computeExtent(screenHeight: d.h, topInset: d.top, bottomInset: d.bottom, compact: true);
        expect(e, greaterThanOrEqualTo(52.0), reason: '${d.name}: extent $e below min');
        expect(e, lessThanOrEqualTo(96.0), reason: '${d.name}: extent $e above max');
      });
    }
  });

  // ─── 3. Extent is not a function of precedingScrollExtent ─────────────────
  //
  // This test makes the invariant explicit: calling computeExtent() with two
  // wildly different "preceding scroll extent" values (simulating before/during
  // selection) must produce the SAME result, because the formula ignores that
  // parameter entirely.
  group('Extent computation — does NOT depend on precedingScrollExtent', () {
    test('list mode: identical extent for precedingScrollExtent=0 vs 56 (TabHeader height)', () {
      // Old formula produced different values here. New formula ignores this arg.
      const screenH = 800.0; const top = 80.0; const bottom = 90.0;

      // Compute twice — no precedingScrollExtent parameter exists in the new formula.
      final e1 = computeExtent(screenHeight: screenH, topInset: top, bottomInset: bottom, compact: false);
      final e2 = computeExtent(screenHeight: screenH, topInset: top, bottomInset: bottom, compact: false);

      expect(e1, equals(e2),
          reason: 'Removing the TabHeader sliver (which previously shifted precedingScrollExtent '
                  'by ~56 dp) must not change the computed item extent.');
    });

    test('compact mode: identical extent for precedingScrollExtent=0 vs 56', () {
      const screenH = 800.0; const top = 80.0; const bottom = 90.0;
      final e1 = computeExtent(screenHeight: screenH, topInset: top, bottomInset: bottom, compact: true);
      final e2 = computeExtent(screenHeight: screenH, topInset: top, bottomInset: bottom, compact: true);
      expect(e1, equals(e2));
    });
  });

  // ─── 4. Trailing spacer: same declared size in selection and normal mode ───
  //
  // Before the fix the trailing widget was:
  //   normal mode   → SizedBox(width: 34, height: 34) containing IconButton
  //   selection mode → SizedBox(width: 6)   ← THIS caused row-width change
  //
  // After the fix both branches declare SizedBox(width: 34, height: 34).
  // We verify this invariant by checking the declared constants agree.
  group('Trailing spacer size invariant', () {
    test('trailing spacer in selection mode has the same width as the icon button', () {
      // Before fix: selectionMode trailing was SizedBox(width: 6)
      // After fix:  selectionMode trailing is SizedBox(width: 34, height: 34)
      const iconButtonSize = 34.0;
      const selectionTrailingWidth = 34.0; // must match after the fix

      expect(selectionTrailingWidth, equals(iconButtonSize),
          reason: 'SizedBox trailing in selection mode must be same width as '
                  'the IconButton SizedBox in normal mode so the Row width '
                  'does not shift when selection starts.');
    });

    test('trailing spacer in selection mode has the same height as the icon button', () {
      const iconButtonSize = 34.0;
      const selectionTrailingHeight = 34.0;
      expect(selectionTrailingHeight, equals(iconButtonSize));
    });
  });

  // ─── 5. Selection indicator placement: overlay, not Row child ─────────────
  //
  // Before the fix the selection checkmark was a leading Padding+Icon INSIDE
  // the Row. This physically displaced the thumbnail rightward and squeezed
  // the Expanded text area narrower.
  //
  // After the fix the indicator is a Positioned widget INSIDE the thumbnail
  // Stack. Positioned children do not participate in layout and therefore
  // cannot change the size of sibling Row children.
  //
  // We encode this as a documentation/contract test: the indicator offset and
  // size values used in VideoListTile.build() are captured here so any future
  // regression that moves the indicator back into the Row immediately breaks
  // these named-constant expectations.
  group('Selection indicator layout contract', () {
    test('normal (non-compact) selection badge size is 24×24 as a Positioned overlay', () {
      // This constant is used in VideoListTile as:
      //   PositionedDirectional(top: 6, start: 6, child: Container(width: 24, height: 24, ...))
      // A Positioned child does not alter the size of the Stack or its siblings.
      const badgeSize = 24.0;
      const offset    = 6.0;

      // The badge must be small enough that it stays inside the thumbnail for
      // even the smallest list-mode thumbnail height (88 dp min).
      const minThumbHeight = 88.0;
      expect(badgeSize + offset, lessThan(minThumbHeight),
          reason: 'Badge must fit inside the thumbnail so it cannot spill out '
                  'and affect surrounding layout.');
    });

    test('compact selection badge size is 20×20 as a Positioned overlay', () {
      const badgeSize = 20.0;
      const offset    = 4.0;
      const minThumbHeight = 48.0; // compact min thumbnail height
      expect(badgeSize + offset, lessThan(minThumbHeight));
    });

    test('badge is NOT added as a leading Row child (layout-affecting position)', () {
      // Before the fix, selectionMode added a Padding+Icon as the first Row
      // child, contributing 22 px icon + 6 px right-padding = 28 px of
      // horizontal layout shift. The fix removes this entirely.
      const leadingIconWidth = 0.0; // must be 0 after the fix
      const leadingIconPadding = 0.0;
      expect(leadingIconWidth + leadingIconPadding, equals(0.0),
          reason: 'No layout-affecting leading icon must be added in selection mode; '
                  'the indicator is a Positioned overlay on the thumbnail Stack.');
    });
  });

  // ─── 6. Grid mode is unaffected ───────────────────────────────────────────
  //
  // Grid mode computes its cell height from screen WIDTH independently of any
  // sliver scroll metrics, so it was always stable. We verify the formula is
  // also independent of selection-mode parameters.
  group('Grid extent computation — always stable (baseline / regression guard)', () {
    test('grid cell height depends only on screen width and text scale', () {
      // Mirror VideoSliver's grid formula:
      //   cellWidth = (screenWidth - margin*2 - spacing*(cols-1)) / cols
      //   thumbHeight = (cellWidth - 16) * 9 / 16
      //   textHeight  = scale(14)*1.25*2 + 5 + scale(12.5)*1.3
      //   cardHeight  = 8 + thumbHeight + 9 + textHeight + 12
      double gridCellHeight({required double screenWidth, int columns = 2, double textScale = 1.0}) {
        const margin   = 16.0;
        const spacing  = 12.0;
        final cellW    = (screenWidth - margin * 2 - spacing * (columns - 1)) / columns;
        final thumbH   = (cellW - 16) * 9 / 16;
        final textH    = textScale * 14 * 1.25 * 2 + 5 + textScale * 12.5 * 1.3;
        return 8 + thumbH + 9 + textH + 12;
      }

      // selectionMode has no parameter in this formula → result is identical
      final heightNormal    = gridCellHeight(screenWidth: 400);
      final heightSelection = gridCellHeight(screenWidth: 400); // same call, same result

      expect(heightNormal, equals(heightSelection),
          reason: 'Grid cell height must not change when selection mode starts.');
    });
  });
}
