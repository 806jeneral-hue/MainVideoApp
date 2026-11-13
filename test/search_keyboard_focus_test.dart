import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/ui/common/app_search_bar.dart';
import 'package:main_video/ui/common/glass.dart';
import 'package:main_video/ui/common/tab_header.dart';

// ---------------------------------------------------------------------------
// Minimal host that embeds AppSearchBar with TabHeader the same way HomePage does.
// ---------------------------------------------------------------------------

class _Host extends StatefulWidget {
  const _Host();

  @override
  _HostState createState() => _HostState();
}

class _HostState extends State<_Host> {
  final GlobalKey<AppSearchBarState> barKey = GlobalKey<AppSearchBarState>();
  bool isSearchOpen = false;
  String lastQuery = '';
  int closedCount = 0;

  AppSearchBarState? get bar => barKey.currentState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            TabHeader(
              title: 'Library',
              searchOpen: isSearchOpen,
              searchBarSlot: AppSearchBar(
                key: barKey,
                isOpen: isSearchOpen,
                hint: 'Search...',
                onChanged: (q) => lastQuery = q,
                onClosed: () {
                  closedCount++;
                  setState(() => isSearchOpen = false);
                },
              ),
              onToggleSearch: () {
                setState(() => isSearchOpen = !isSearchOpen);
              },
              onSortAndLayout: null,
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ListTile(
                        key: Key('item_$index'),
                        title: Text('Item $index'),
                        onTap: () {
                          barKey.currentState?.hideKeyboard();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text('Player $index')),
                                body: const Center(child: Text('Playing')),
                              ),
                            ),
                          );
                        },
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
    );
  }
}

// ---------------------------------------------------------------------------

void main() {
  Finder findSearchButton() => find.byType(GlassIconButton).at(1);

  group('AppSearchBar — open / close / focus lifecycle', () {
    testWidgets('starts closed; no TextField visible', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      final hostState = tester.state<_HostState>(find.byType(_Host));
      expect(hostState.isSearchOpen, isFalse);
    });

    testWidgets('toggling search shows TextField and changes icon in sync', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));

      // Tap search icon button (index 1 after SettingsButton) to open
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      expect(hostState.isSearchOpen, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      // Verify the header button now has close tooltip / searchOpen true
      final header = tester.widget<TabHeader>(find.byType(TabHeader));
      expect(header.searchOpen, isTrue);

      // Tap header button again to close
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      expect(hostState.isSearchOpen, isFalse);
      expect(find.byType(TextField), findsNothing);

      final headerClosed = tester.widget<TabHeader>(find.byType(TabHeader));
      expect(headerClosed.searchOpen, isFalse);
    });

    testWidgets('open search, open player route, pop player: search & icon stay in exact sync', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));

      // 1. Open search
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();
      expect(hostState.isSearchOpen, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      // 2. Tap an item to open the player
      await tester.tap(find.byKey(const Key('item_0')));
      await tester.pumpAndSettle();
      expect(find.text('Player 0'), findsOneWidget);

      // 3. Close the player route to return to the list
      final navigator = Navigator.of(tester.element(find.text('Playing')));
      navigator.pop();
      await tester.pumpAndSettle();

      // 4. Verify search and icon match 100% after returning
      expect(find.text('Player 0'), findsNothing);
      expect(hostState.isSearchOpen, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      final header = tester.widget<TabHeader>(find.byType(TabHeader));
      expect(header.searchOpen, isTrue); // Icon is 'X' matching visible field!

      // 5. Tapping 'X' button closes search properly
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      expect(hostState.isSearchOpen, isFalse);
      expect(find.byType(TextField), findsNothing);
      final headerAfterClose = tester.widget<TabHeader>(find.byType(TabHeader));
      expect(headerAfterClose.searchOpen, isFalse);
    });

    testWidgets('onChanged fires when user types', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'flutter');
      // Advance by debounce duration (300 ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(hostState.lastQuery, 'flutter');
    });

    testWidgets('onSubmitted hides keyboard but keeps bar open', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'music');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(hostState.isSearchOpen, isTrue);
    });

    testWidgets('handlePop — first call hides keyboard, second call closes search and resets icon',
        (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );

      // First back: hides keyboard only
      final consumed1 = hostState.bar!.handlePop();
      await tester.pumpAndSettle();
      expect(consumed1, isTrue);
      expect(hostState.isSearchOpen, isTrue);

      // Second back: closes search
      final consumed2 = hostState.bar!.handlePop();
      await tester.pumpAndSettle();
      expect(consumed2, isTrue);
      expect(hostState.isSearchOpen, isFalse);
      expect(hostState.closedCount, 1);

      // Header is also closed
      final header = tester.widget<TabHeader>(find.byType(TabHeader));
      expect(header.searchOpen, isFalse);

      // Third back: unhandled
      final consumed3 = hostState.bar?.handlePop() ?? false;
      expect(consumed3, isFalse);
    });

    testWidgets('hideKeyboard() does not close the bar', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      await tester.tap(findSearchButton());
      await tester.pumpAndSettle();

      hostState.bar!.hideKeyboard();
      await tester.pumpAndSettle();

      expect(hostState.isSearchOpen, isTrue);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CustomScrollView has onDrag keyboardDismissBehavior',
        (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final scrollView = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });
  });

  group('TabHeader & GlassIconButton visual tests', () {
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
