import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:main_video/core/l10n/app_localizations.dart';
import 'package:main_video/core/services/recent_searches_service.dart';
import 'package:main_video/data/local/app_database.dart';
import 'package:main_video/ui/common/app_search_bar.dart';

// Tests for search enhancements: debouncing and recent searches panel.
// - TextNormalizer + highlight spans: covered in text_normalizer_test.dart
// - RecentSearchesService CRUD: covered in recent_searches_service_test.dart
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('search_enhancements_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(AppDatabase.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Search Debouncing in AppSearchBar', () {
    testWidgets('debounces rapid keystrokes to a single call after 300 ms',
        (tester) async {
      int changeCount = 0;
      String currentQuery = '';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppSearchBar(
              isOpen: true,
              hint: 'Search...',
              onChanged: (q) {
                changeCount++;
                currentQuery = q;
              },
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Type three characters in quick succession
      await tester.enterText(textField, 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(changeCount, 0, reason: 'No dispatch yet during debounce window');

      await tester.enterText(textField, 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      expect(changeCount, 0, reason: 'Still within debounce window');

      await tester.enterText(textField, 'abc');
      await tester.pump(const Duration(milliseconds: 100));
      expect(changeCount, 0, reason: 'Still within debounce window');

      // Let debounce fire
      await tester.pump(const Duration(milliseconds: 400));
      expect(changeCount, 1, reason: 'Exactly one dispatch after debounce');
      expect(currentQuery, 'abc');
    });

    testWidgets('onSubmitted bypasses debounce immediately', (tester) async {
      int changeCount = 0;
      String currentQuery = '';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppSearchBar(
              isOpen: true,
              hint: 'Search...',
              onChanged: (q) {
                changeCount++;
                currentQuery = q;
              },
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'direct');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(changeCount, 1, reason: 'Immediate dispatch on search key');
      expect(currentQuery, 'direct');
    });
  });

  group('Recent Searches panel in AppSearchBar', () {
    const testKey = 'testRecentSearchPanelKey';

    testWidgets('recent chips are visible when field is focused and empty',
        (tester) async {
      await tester.runAsync(() async {
        await RecentSearchesService.addRecent(testKey, 'old query');
        await RecentSearchesService.addRecent(testKey, 'new query'); // newest first
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppSearchBar(
              isOpen: true,
              hint: 'Search...',
              recentStorageKey: testKey,
              onChanged: (_) {},
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both chips should be visible (field is autofocused because isOpen=true)
      expect(find.text('new query'), findsAtLeastNWidgets(1));
      expect(find.text('old query'), findsAtLeastNWidgets(1));
    });

    testWidgets('panel is hidden when field has text', (tester) async {
      await tester.runAsync(() async {
        await RecentSearchesService.addRecent(testKey, 'some query');
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppSearchBar(
              isOpen: true,
              hint: 'Search...',
              recentStorageKey: testKey,
              onChanged: (_) {},
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially chip is visible
      expect(find.text('some query'), findsAtLeastNWidgets(1));

      // Type something — panel must disappear
      await tester.enterText(find.byType(TextField), 'typing');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('some query'), findsNothing,
          reason: 'Panel hidden while typing');
    });
  });
}
