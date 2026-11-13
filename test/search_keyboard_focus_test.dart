import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/ui/common/glass.dart';
import 'package:main_video/ui/common/search_focus.dart';
import 'package:main_video/ui/common/tab_header.dart';

class TestSearchHostWidget extends StatefulWidget {
  const TestSearchHostWidget({super.key});

  @override
  TestSearchHostWidgetState createState() => TestSearchHostWidgetState();
}

class TestSearchHostWidgetState extends State<TestSearchHostWidget>
    with SearchFocusState<TestSearchHostWidget> {
  int clearCallCount = 0;
  String submittedQuery = '';

  void onClear() {
    clearCallCount++;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PopScope(
          canPop: !isSearching && searchController.text.isEmpty && !searchFocusNode.hasFocus,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            handleSearchPop(onClear: onClear);
          },
          child: Column(
            children: [
              TabHeader(
                title: 'Library',
                searching: isSearching,
                searchController: searchController,
                searchFocusNode: searchFocusNode,
                searchHint: 'Search...',
                onQueryChanged: (_) {},
                onToggleSearch: () => toggleSearch(onClear: onClear),
                onSortAndLayout: null,
                onSearchSubmitted: (q) => submittedQuery = q,
              ),
              Expanded(
                child: CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ListTile(
                          title: Text('Item $index'),
                          onTap: () => hideKeyboard(),
                        ),
                        childCount: 50,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('SearchFocusState Lifecycle & Repetitive Toggle', () {
    testWidgets('Tapping search button opens keyboard and stays open; repeating 10 times maintains stability', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final state = key.currentState!;
      expect(state.isSearching, isFalse);
      expect(state.searchFocusNode.hasFocus, isFalse);

      // Repeat open / close 10 times to verify no state leaks or oscillating loops
      for (int i = 0; i < 10; i++) {
        // Tap to open search
        state.toggleSearch(onClear: state.onClear);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // allow AnimatedSize to finish

        expect(state.isSearching, isTrue, reason: 'Iteration $i: isSearching should be true');
        expect(state.searchFocusNode.hasFocus, isTrue, reason: 'Iteration $i: FocusNode should have focus');

        // Tap to close search
        state.toggleSearch(onClear: state.onClear);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(state.isSearching, isFalse, reason: 'Iteration $i: isSearching should be false');
        expect(state.searchFocusNode.hasFocus, isFalse, reason: 'Iteration $i: FocusNode should lose focus');
        expect(state.searchController.text, isEmpty);
      }

      expect(state.clearCallCount, 10);
    });
  });

  group('Keyboard Action Search & Submission', () {
    testWidgets('Pressing Search (onSubmitted) hides the keyboard while keeping text and results', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final state = key.currentState!;

      // Open search
      state.toggleSearch(onClear: state.onClear);
      await tester.pumpAndSettle();

      // Enter query
      state.searchController.text = 'flutter';
      expect(state.searchFocusNode.hasFocus, isTrue);

      // Submit search via TextField action
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Keyboard should be dismissed (unfocused), but search and query remain
      expect(state.searchFocusNode.hasFocus, isFalse);
      expect(state.isSearching, isTrue);
      expect(state.searchController.text, 'flutter');
      expect(state.submittedQuery, 'flutter');
    });

    testWidgets('Tapping the search field again restores keyboard focus', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final state = key.currentState!;
      state.toggleSearch(onClear: state.onClear);
      await tester.pumpAndSettle();

      // Hide keyboard
      state.hideKeyboard();
      await tester.pumpAndSettle();
      expect(state.searchFocusNode.hasFocus, isFalse);

      // Tap on TextField
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(state.searchFocusNode.hasFocus, isTrue);
    });
  });

  group('Scroll & Play Keyboard Dismissal', () {
    testWidgets('Tapping a result list item calls hideKeyboard to dismiss keyboard', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final state = key.currentState!;
      state.toggleSearch(onClear: state.onClear);
      await tester.pumpAndSettle();
      expect(state.searchFocusNode.hasFocus, isTrue);

      // Tap on a list item
      await tester.tap(find.text('Item 0'));
      await tester.pumpAndSettle();

      expect(state.searchFocusNode.hasFocus, isFalse);
      expect(state.isSearching, isTrue); // search remains open
    });

    testWidgets('CustomScrollView has onDrag keyboardDismissBehavior', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final scrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(scrollView.keyboardDismissBehavior, ScrollViewKeyboardDismissBehavior.onDrag);
    });
  });

  group('Two-Stage Back Button Behavior', () {
    testWidgets('First back press hides keyboard, second back press closes search', (tester) async {
      final key = GlobalKey<TestSearchHostWidgetState>();
      await tester.pumpWidget(TestSearchHostWidget(key: key));
      await tester.pumpAndSettle();

      final state = key.currentState!;

      // 1. Open search and type query
      state.toggleSearch(onClear: state.onClear);
      await tester.pumpAndSettle();
      state.searchController.text = 'music';
      expect(state.searchFocusNode.hasFocus, isTrue);
      expect(state.isSearching, isTrue);

      // 2. First back button press: should hide keyboard only
      final handledFirst = state.handleSearchPop(onClear: state.onClear);
      await tester.pumpAndSettle();

      expect(handledFirst, isTrue);
      expect(state.searchFocusNode.hasFocus, isFalse); // keyboard hidden
      expect(state.isSearching, isTrue); // search still open!
      expect(state.searchController.text, 'music'); // query preserved!

      // 3. Second back button press: should close search
      final handledSecond = state.handleSearchPop(onClear: state.onClear);
      await tester.pumpAndSettle();

      expect(handledSecond, isTrue);
      expect(state.isSearching, isFalse); // search closed!
      expect(state.searchController.text, isEmpty); // query cleared!

      // 4. Third back press: neither focused nor searching -> not handled (allows page pop)
      final handledThird = state.handleSearchPop(onClear: state.onClear);
      expect(handledThird, isFalse);
    });
  });

  group('GlassIconButton Focus Guard', () {
    testWidgets('GlassIconButton has canRequestFocus: false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassIconButton(
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: () {},
            ),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.canRequestFocus, isFalse);
    });
  });
}

