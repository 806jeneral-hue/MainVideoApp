import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/data/models/collection_prefs.dart';
import 'package:main_video/core/l10n/enum_labels.dart';
import 'package:main_video/core/l10n/strings.dart';
import 'package:main_video/data/models/enums.dart';

void main() {
  group('CollectionKey', () {
    test('gives each list a distinct key', () {
      expect(CollectionKey.home.value, isNot(CollectionKey.favorites.value));
      expect(
        CollectionKey.folder('/a').value,
        isNot(CollectionKey.folder('/b').value),
      );
      expect(
        CollectionKey.playlist('p1').value,
        isNot(CollectionKey.folder('p1').value),
      );
    });

    test('is equal by value, so it works as a map key', () {
      expect(CollectionKey.folder('/a'), CollectionKey.folder('/a'));
      expect(
        {CollectionKey.folder('/a').value: 1}[CollectionKey.folder('/a').value],
        1,
      );
    });
  });

  group('CollectionPrefs', () {
    test('defaults to newest first', () {
      const prefs = CollectionPrefs();
      expect(prefs.sortField, SortField.dateAdded);
      expect(prefs.descending, isTrue);
      expect(prefs.isManual, isFalse);
    });

    test('survives a round trip through storage', () {
      const prefs = CollectionPrefs(
        sortField: SortField.manual,
        descending: false,
        manualOrder: ['b.mp4', 'a.mp4'],
      );
      final restored = CollectionPrefs.fromMap(prefs.toMap());
      expect(restored.sortField, SortField.manual);
      expect(restored.descending, isFalse);
      expect(restored.manualOrder, ['b.mp4', 'a.mp4']);
      expect(restored.isManual, isTrue);
    });

    test('falls back sensibly on a malformed record', () {
      final restored = CollectionPrefs.fromMap({'sortField': 'nonsense'});
      expect(restored.sortField, SortField.dateAdded);
      expect(restored.manualOrder, isEmpty);
    });
  });

  group('SortField', () {
    test('only a custom order has no direction', () {
      expect(SortField.manual.hasDirection, isFalse);
      for (final field in SortField.values.where(
        (f) => f != SortField.manual,
      )) {
        expect(field.hasDirection, isTrue, reason: field.name);
      }
    });

    test('every option has a label in every language', () {
      for (final s in const [StringsEn(), StringsAr()]) {
        for (final field in SortField.values) {
          expect(field.label(s), isNotEmpty, reason: field.name);
        }
        for (final mode in LoopMode.values) {
          expect(mode.label(s), isNotEmpty, reason: mode.name);
        }
      }
    });
  });
}
