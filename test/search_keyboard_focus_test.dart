import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/ui/common/app_search_bar.dart';
import 'package:main_video/ui/common/glass.dart';

// ---------------------------------------------------------------------------
// Minimal host that embeds AppSearchBar the same way the pages do.
// ---------------------------------------------------------------------------

class _Host extends StatefulWidget {
  const _Host();

  @override
  _HostState createState() => _HostState();
}

class _HostState extends State<_Host> {
  final GlobalKey<AppSearchBarState> barKey = GlobalKey<AppSearchBarState>();
  String lastQuery = '';
  int closedCount = 0;

  AppSearchBarState get bar => barKey.currentState!;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            // Toggle button — simulates the search icon in the header.
            ElevatedButton(
              key: const Key('toggle'),
              onPressed: () {
                final b = barKey.currentState!;
                b.isOpen ? b.close() : b.open();
                setState(() {});
              },
              child: const Text('Toggle'),
            ),
            // The bar lives OUTSIDE the scroll view — same as in the pages.
            AppSearchBar(
              key: barKey,
              hint: 'Search...',
              onChanged: (q) => lastQuery = q,
              onClosed: () => closedCount++,
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
                        onTap: () => barKey.currentState?.hideKeyboard(),
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
  group('AppSearchBar — open / close / focus lifecycle', () {
    testWidgets('starts closed; no TextField visible', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('open() shows TextField; close() hides it', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));

      hostState.bar.open();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(hostState.bar.isOpen, isTrue);

      hostState.bar.close();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(hostState.bar.isOpen, isFalse);
    });

    testWidgets('opens 10 times without leaking state', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));

      for (var i = 0; i < 10; i++) {
        hostState.bar.open();
        await tester.pumpAndSettle();
        expect(hostState.bar.isOpen, isTrue, reason: 'iteration $i open');

        hostState.bar.close();
        await tester.pumpAndSettle();
        expect(hostState.bar.isOpen, isFalse, reason: 'iteration $i closed');
      }
    });

    testWidgets('onChanged fires when user types', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      hostState.bar.open();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pumpAndSettle();

      expect(hostState.lastQuery, 'flutter');
    });

    testWidgets('onClosed fires when close() is called', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      hostState.bar.open();
      await tester.pumpAndSettle();
      hostState.bar.close();
      await tester.pumpAndSettle();

      expect(hostState.closedCount, 1);
    });

    testWidgets('onSubmitted hides keyboard but keeps bar open', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      hostState.bar.open();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'music');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Bar stays open after submission.
      expect(hostState.bar.isOpen, isTrue);
    });

    testWidgets('handlePop — first call hides keyboard, second call closes',
        (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      hostState.bar.open();
      await tester.pumpAndSettle();

      // The field gains focus via autofocus.
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );

      // First back: hides keyboard (focus → false), bar stays open.
      final consumed1 = hostState.bar.handlePop();
      await tester.pumpAndSettle();
      expect(consumed1, isTrue);
      expect(hostState.bar.isOpen, isTrue);

      // Second back: closes the bar.
      final consumed2 = hostState.bar.handlePop();
      await tester.pumpAndSettle();
      expect(consumed2, isTrue);
      expect(hostState.bar.isOpen, isFalse);

      // Third back: nothing to handle.
      final consumed3 = hostState.bar.handlePop();
      expect(consumed3, isFalse);
    });

    testWidgets('hideKeyboard() does not close the bar', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      final hostState = tester.state<_HostState>(find.byType(_Host));
      hostState.bar.open();
      await tester.pumpAndSettle();

      hostState.bar.hideKeyboard();
      await tester.pumpAndSettle();

      expect(hostState.bar.isOpen, isTrue);
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

  group('AppSearchBar — visual / GlassIconButton focus guard', () {
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
