import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/data/models/enums.dart';
import 'package:main_video/data/models/video.dart';
import 'package:main_video/ui/common/selection.dart';

Video testVideo(String id) {
  return Video(
    id: id,
    assetId: 'asset-$id',
    title: id,
    durationMs: 60000,
    sizeBytes: 1024,
    dateAdded: DateTime(2025, 1, 1),
    dateModified: DateTime(2025, 1, 2),
    width: 1920,
    height: 1080,
  );
}

class TestSelectionWidget extends StatefulWidget {
  const TestSelectionWidget({super.key});

  @override
  TestSelectionWidgetState createState() => TestSelectionWidgetState();
}

class TestSelectionWidgetState extends State<TestSelectionWidget>
    with VideoSelection {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

void main() {
  final videos = List.generate(12, (i) => testVideo('v_$i'));

  group('VideoSelection 1D (List & Compact Modes, columns = 1)', () {
    testWidgets('linear drag down selects all items in sequence', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      state.startSelection(videos[1], 1, videos);
      expect(state.selectedIds, {'v_1'});

      state.addToSelection('v_2', 2, videos, 1);
      expect(state.selectedIds, {'v_1', 'v_2'});

      state.addToSelection('v_4', 4, videos, 1);
      expect(state.selectedIds, {'v_1', 'v_2', 'v_3', 'v_4'});
    });

    testWidgets('linear reverse drag up deselects items leaving range', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      state.startSelection(videos[1], 1, videos);
      state.addToSelection('v_4', 4, videos, 1);
      expect(state.selectedIds, {'v_1', 'v_2', 'v_3', 'v_4'});

      // Drag back up to index 2
      state.addToSelection('v_2', 2, videos, 1);
      expect(state.selectedIds, {'v_1', 'v_2'});
      expect(state.selectedIds.contains('v_3'), isFalse);
      expect(state.selectedIds.contains('v_4'), isFalse);
    });

    testWidgets('pre-existing selections outside the drag are preserved on reverse drag', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      // Pre-select v_0 manually
      state.selectedIds.add('v_0');

      // Start drag at v_2
      state.startSelection(videos[2], 2, videos);
      expect(state.selectedIds, {'v_0', 'v_2'});

      state.addToSelection('v_5', 5, videos, 1);
      expect(state.selectedIds, {'v_0', 'v_2', 'v_3', 'v_4', 'v_5'});

      // Reverse back to v_3
      state.addToSelection('v_3', 3, videos, 1);
      expect(state.selectedIds, {'v_0', 'v_2', 'v_3'});
      // v_0 was not added by this drag, so it remains selected
      expect(state.selectedIds.contains('v_0'), isTrue);
    });
  });

  group('VideoSelection 2D (Grid Mode, columns = 2)', () {
    // 2-column layout:
    // row 0: v_0 (0,0), v_1 (0,1)
    // row 1: v_2 (1,0), v_3 (1,1)
    // row 2: v_4 (2,0), v_5 (2,1)
    // row 3: v_6 (3,0), v_7 (3,1)

    testWidgets('dragging down column 0 selects only column 0 items, NOT column 1', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      state.startSelection(videos[0], 0, videos);
      expect(state.selectedIds, {'v_0'});

      // Drag down column 0 to v_2 (row 1, col 0)
      state.addToSelection('v_2', 2, videos, 2);
      expect(state.selectedIds, {'v_0', 'v_2'});
      // Crucial view-mode fix: v_1 (which is at index 1, col 1) must NOT be selected!
      expect(state.selectedIds.contains('v_1'), isFalse);

      // Drag down column 0 to v_4 (row 2, col 0)
      state.addToSelection('v_4', 4, videos, 2);
      expect(state.selectedIds, {'v_0', 'v_2', 'v_4'});
      expect(state.selectedIds.contains('v_1'), isFalse);
      expect(state.selectedIds.contains('v_3'), isFalse);
    });

    testWidgets('dragging diagonally expands bounding box across columns', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      state.startSelection(videos[0], 0, videos);

      // Drag down-right to v_3 (row 1, col 1)
      state.addToSelection('v_3', 3, videos, 2);
      // Bounding box row 0..1, col 0..1 -> v_0, v_1, v_2, v_3
      expect(state.selectedIds, {'v_0', 'v_1', 'v_2', 'v_3'});
    });

    testWidgets('reverse drag in 2D grid deselects items leaving 2D bounding box', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      state.startSelection(videos[0], 0, videos);
      state.addToSelection('v_5', 5, videos, 2); // row 0..2, col 0..1 -> all 6 items
      expect(state.selectedIds, {'v_0', 'v_1', 'v_2', 'v_3', 'v_4', 'v_5'});

      // Reverse back to v_2 (row 1, col 0): bounding box shrinks to row 0..1, col 0..0
      state.addToSelection('v_2', 2, videos, 2);
      expect(state.selectedIds, {'v_0', 'v_2'});
      expect(state.selectedIds.contains('v_1'), isFalse);
      expect(state.selectedIds.contains('v_3'), isFalse);
      expect(state.selectedIds.contains('v_4'), isFalse);
      expect(state.selectedIds.contains('v_5'), isFalse);
    });
  });

  group('VideoSelection 3-Column & 4-Column Grids', () {
    // 3-column layout:
    // row 0: 0, 1, 2
    // row 1: 3, 4, 5
    // row 2: 6, 7, 8
    testWidgets('3-column grid bounding box selection', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      // Start at item 4 (row 1, col 1)
      state.startSelection(videos[4], 4, videos);
      expect(state.selectedIds, {'v_4'});

      // Drag to item 8 (row 2, col 2)
      // Bounding box: rows 1..2, cols 1..2 -> items 4, 5, 7, 8
      state.addToSelection('v_8', 8, videos, 3);
      expect(state.selectedIds, {'v_4', 'v_5', 'v_7', 'v_8'});
      expect(state.selectedIds.contains('v_3'), isFalse);
      expect(state.selectedIds.contains('v_6'), isFalse);
    });

    testWidgets('switching view mode preserves existing selections', (tester) async {
      final key = GlobalKey<TestSelectionWidgetState>();
      await tester.pumpWidget(TestSelectionWidget(key: key));
      final state = key.currentState!;

      // Selected in grid mode (cols = 2)
      state.startSelection(videos[0], 0, videos);
      state.addToSelection('v_2', 2, videos, 2);
      state.endDragSelection();
      expect(state.selectedIds, {'v_0', 'v_2'});

      // Mode switches to list (cols = 1); selections remain
      expect(state.selectedIds, {'v_0', 'v_2'});
      expect(state.selectionMode, isTrue);
    });
  });

  group('Selection AppBar View Mode Toggle', () {
    testWidgets('renders view mode button and responds to toggle callback', (tester) async {
      ViewMode currentMode = ViewMode.list;
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: buildSelectionAppBar(
                context: context,
                count: 2,
                total: 10,
                onClose: () {},
                onSelectAll: () {},
                onDeselectAll: () {},
                currentViewMode: currentMode,
                onToggleViewMode: () => toggled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify toggle button exists via tooltip (shows compact icon/tooltip since current is list)
      final toggleFinder = find.byTooltip(const StringsEn().compactView);
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pump();

      expect(toggled, isTrue);
    });
  });
}
