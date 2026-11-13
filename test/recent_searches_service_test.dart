import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:main_video/core/services/recent_searches_service.dart';
import 'package:main_video/data/local/app_database.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recent_searches_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(AppDatabase.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RecentSearchesService', () {
    const key = 'testRecentKey';

    test('addRecent inserts newest first and deduplicates', () async {
      await RecentSearchesService.addRecent(key, 'query 1');
      await RecentSearchesService.addRecent(key, 'query 2');
      await RecentSearchesService.addRecent(key, 'query 1');

      final list = RecentSearchesService.getRecent(key);
      expect(list, ['query 1', 'query 2']);
    });

    test('caps at 10 items', () async {
      for (int i = 1; i <= 15; i++) {
        await RecentSearchesService.addRecent(key, 'query $i');
      }

      final list = RecentSearchesService.getRecent(key);
      expect(list.length, 10);
      expect(list.first, 'query 15');
      expect(list.last, 'query 6');
    });

    test('removeRecent removes target item case-insensitively', () async {
      await RecentSearchesService.addRecent(key, 'Video One');
      await RecentSearchesService.addRecent(key, 'Video Two');

      await RecentSearchesService.removeRecent(key, 'video one');
      final list = RecentSearchesService.getRecent(key);
      expect(list, ['Video Two']);
    });

    test('clearRecent empties the list', () async {
      await RecentSearchesService.addRecent(key, 'Item 1');
      await RecentSearchesService.addRecent(key, 'Item 2');
      await RecentSearchesService.clearRecent(key);

      expect(RecentSearchesService.getRecent(key), isEmpty);
    });
  });
}

