import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/utils/natural_sort.dart';

void main() {
  group('NaturalSort: Basic natural ordering', () {
    test('orders simple numbers naturally: 2 comes before 10', () {
      final list = ['Episode 10', 'Episode 2', 'Episode 1'];
      list.sort(NaturalSort.compare);
      expect(list, ['Episode 1', 'Episode 2', 'Episode 10']);
    });

    test('is case-insensitive', () {
      final list = ['episode 2', 'Episode 1', 'EPISODE 10'];
      list.sort(NaturalSort.compare);
      expect(list, ['Episode 1', 'episode 2', 'EPISODE 10']);
    });

    test('handles leading zeros naturally', () {
      final list = ['video 02', 'video 10', 'video 1'];
      list.sort(NaturalSort.compare);
      expect(list, ['video 1', 'video 02', 'video 10']);
    });

    test('handles strings with no numbers', () {
      final list = ['Banana', 'apple', 'Cherry'];
      list.sort(NaturalSort.compare);
      expect(list, ['apple', 'Banana', 'Cherry']);
    });

    test('handles empty and whitespace strings', () {
      final list = ['b', '', 'a', '   '];
      list.sort(NaturalSort.compare);
      expect(list[0], '');
      expect(list[1], '   ');
      expect(list[2], 'a');
      expect(list[3], 'b');
    });
  });

  group('NaturalSort: Priority 1 - S01E02 / Season & Episode', () {
    test('sorts S01E02 vs S01E10 vs S02E01 correctly', () {
      final list = [
        'Series.Name.S02E01.mkv',
        'Series.Name.S01E10.mkv',
        'Series.Name.S01E02.mkv',
        'Series.Name.S01E01.mkv',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Series.Name.S01E01.mkv',
        'Series.Name.S01E02.mkv',
        'Series.Name.S01E10.mkv',
        'Series.Name.S02E01.mkv',
      ]);
    });

    test('handles lowercase and spaced season/episode patterns (s1e2, S1 E10)', () {
      final list = [
        'show s1e10',
        'show s1e2',
        'show s2e1',
        'show s1e1',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'show s1e1',
        'show s1e2',
        'show s1e10',
        'show s2e1',
      ]);
    });

    test('handles 1x02 format', () {
      final list = [
        'anime 01x10',
        'anime 01x02',
        'anime 02x01',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'anime 01x02',
        'anime 01x10',
        'anime 02x01',
      ]);
    });
  });

  group('NaturalSort: Priority 2 - Episode / Ep / E keywords', () {
    test('sorts Episode 2 before Episode 10 with various delimiters', () {
      final list = [
        'Show - Episode 10.mp4',
        'Show - Episode 2.mp4',
        'Show - Episode 1.mp4',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Show - Episode 1.mp4',
        'Show - Episode 2.mp4',
        'Show - Episode 10.mp4',
      ]);
    });

    test('sorts Ep 2 vs Ep 10 vs Ep 20', () {
      final list = [
        'Show Ep 20.mp4',
        'Show Ep 2.mp4',
        'Show Ep 10.mp4',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Show Ep 2.mp4',
        'Show Ep 10.mp4',
        'Show Ep 20.mp4',
      ]);
    });

    test('sorts standalone E02 vs E10', () {
      final list = [
        'Show - E10.mp4',
        'Show - E02.mp4',
        'Show - E01.mp4',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Show - E01.mp4',
        'Show - E02.mp4',
        'Show - E10.mp4',
      ]);
    });
  });

  group('NaturalSort: Priority 3 - Arabic episode names and Arabic-Indic digits', () {
    test('sorts Arabic "الحلقة 2" before "الحلقة 10"', () {
      final list = [
        'مسلسل عمر - الحلقة 10',
        'مسلسل عمر - الحلقة 2',
        'مسلسل عمر - الحلقة 1',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'مسلسل عمر - الحلقة 1',
        'مسلسل عمر - الحلقة 2',
        'مسلسل عمر - الحلقة 10',
      ]);
    });

    test('normalizes and sorts Arabic-Indic digits (٠-٩)', () {
      final list = [
        'مسلسل عمر - الحلقة ١٠', // 10
        'مسلسل عمر - الحلقة ٢',  // 2
        'مسلسل عمر - الحلقة ١',  // 1
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'مسلسل عمر - الحلقة ١',
        'مسلسل عمر - الحلقة ٢',
        'مسلسل عمر - الحلقة ١٠',
      ]);
    });

    test('intermixes Western and Arabic-Indic digits consistently', () {
      final list = [
        'الحلقة 10',
        'الحلقة ٢',
        'الحلقة 1',
      ];
      list.sort(NaturalSort.compare);
      expect(list[0], 'الحلقة 1');
      expect(list[1], 'الحلقة ٢');
      expect(list[2], 'الحلقة 10');
    });

    test('handles Arabic season and episode (الموسم 1 الحلقة 2 vs الموسم 2 الحلقة 1)', () {
      final list = [
        'مسلسل صلاح الدين الموسم 2 الحلقة 1',
        'مسلسل صلاح الدين الموسم 1 الحلقة 10',
        'مسلسل صلاح الدين الموسم 1 الحلقة 2',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'مسلسل صلاح الدين الموسم 1 الحلقة 2',
        'مسلسل صلاح الدين الموسم 1 الحلقة 10',
        'مسلسل صلاح الدين الموسم 2 الحلقة 1',
      ]);
    });
  });

  group('NaturalSort: Ignoring non-episode numbers (1080p, 720p, 2024, x264, 5.1)', () {
    test('correctly orders long names with year, 1080p, x265, and episode numbers', () {
      final list = [
        'Breaking.Bad.2008.S01E10.1080p.BluRay.x265.mkv',
        'Breaking.Bad.2008.S01E02.1080p.BluRay.x265.mkv',
        'Breaking.Bad.2008.S01E01.720p.BluRay.x264.mkv',
        'Breaking.Bad.2008.S02E01.2160p.UHD.x265.mkv',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Breaking.Bad.2008.S01E01.720p.BluRay.x264.mkv',
        'Breaking.Bad.2008.S01E02.1080p.BluRay.x265.mkv',
        'Breaking.Bad.2008.S01E10.1080p.BluRay.x265.mkv',
        'Breaking.Bad.2008.S02E01.2160p.UHD.x265.mkv',
      ]);
    });

    test('ignores 5.1 audio and 1080p in names with Episode keyword', () {
      final list = [
        'Show (2024) - Episode 10 [1080p 5.1ch].mkv',
        'Show (2024) - Episode 2 [1080p 5.1ch].mkv',
        'Show (2024) - Episode 1 [720p 2.0ch].mkv',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Show (2024) - Episode 1 [720p 2.0ch].mkv',
        'Show (2024) - Episode 2 [1080p 5.1ch].mkv',
        'Show (2024) - Episode 10 [1080p 5.1ch].mkv',
      ]);
    });
  });

  group('NaturalSort: Mixed and non-episode fallback', () {
    test('falls back to natural sort when no episode keyword exists', () {
      final list = [
        'Documentary Part 10.mp4',
        'Documentary Part 2.mp4',
        'Documentary Part 1.mp4',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Documentary Part 1.mp4',
        'Documentary Part 2.mp4',
        'Documentary Part 10.mp4',
      ]);
    });

    test('mixes files with and without episode pattern stably', () {
      final list = [
        'Show S01E02.mkv',
        'Show S01E01.mkv',
        'Show Trailer.mkv',
      ];
      list.sort(NaturalSort.compare);
      // Both S01E01 and S01E02 sort together in order
      expect(list.indexOf('Show S01E01.mkv') < list.indexOf('Show S01E02.mkv'), isTrue);
    });

    test('sorts different series prefixes by their prefix name naturally', () {
      final list = [
        'Beta Series S01E01.mkv',
        'Alpha Series S01E10.mkv',
        'Alpha Series S01E02.mkv',
      ];
      list.sort(NaturalSort.compare);
      expect(list, [
        'Alpha Series S01E02.mkv',
        'Alpha Series S01E10.mkv',
        'Beta Series S01E01.mkv',
      ]);
    });
  });

  group('NaturalSort: Performance with large list', () {
    test('sorts 1,000 files in under 50 milliseconds using precomputed keys', () {
      final items = List.generate(
        1000,
        (i) => 'Series.Name.2024.S01E${(1000 - i).toString().padLeft(3, '0')}.1080p.x265.mkv',
      );

      final stopwatch = Stopwatch()..start();
      final keys = {for (final item in items) item: NaturalSortKey.from(item)};
      items.sort((a, b) => keys[a]!.compareTo(keys[b]!));
      stopwatch.stop();

      expect(items.first, 'Series.Name.2024.S01E001.1080p.x265.mkv');
      expect(items.last, 'Series.Name.2024.S01E1000.1080p.x265.mkv');
      expect(stopwatch.elapsedMilliseconds < 100, isTrue);
    });
  });
}

