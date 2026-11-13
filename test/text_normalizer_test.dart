import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/core/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer.normalize', () {
    test('removes Arabic diacritics and tatweel', () {
      expect(TextNormalizer.normalize('سَـلاَمٌ'), 'سلام');
      expect(TextNormalizer.normalize('مُحَمَّدْ'), 'محمد');
      expect(TextNormalizer.normalize('الْحَمْدُ لِلَّـهِ'), 'الحمد لله');
    });

    test('normalizes Alef variants to bare Alef', () {
      expect(TextNormalizer.normalize('أحمد'), 'احمد');
      expect(TextNormalizer.normalize('إسلام'), 'اسلام');
      expect(TextNormalizer.normalize('آدم'), 'ادم');
      expect(TextNormalizer.normalize('ٱلرحمن'), 'الرحمن');
    });

    test('normalizes Yaa variants and Alef Maksura', () {
      expect(TextNormalizer.normalize('موسى'), 'موسي');
      expect(TextNormalizer.normalize('على'), 'علي');
      expect(TextNormalizer.normalize('علي'), 'علي');
    });

    test('normalizes Taa Marbuta to Haa', () {
      expect(TextNormalizer.normalize('فاطمة'), 'فاطمه');
      expect(TextNormalizer.normalize('حياة'), 'حياه');
    });

    test('normalizes Arabic-Indic digits to ASCII 0-9', () {
      expect(TextNormalizer.normalize('فيديو ١٢٣'), 'فيديو 123');
      expect(TextNormalizer.normalize('حلقة ٠٤'), 'حلقه 04');
    });

    test('collapses whitespace and converts English to lowercase', () {
      expect(TextNormalizer.normalize('  Hello   WORLD  '), 'hello world');
      expect(TextNormalizer.normalize('فيديو    رقم   1  '), 'فيديو رقم 1');
    });
  });

  group('TextNormalizer.findMatchRanges', () {
    test('matches without diacritics', () {
      const orig = 'سَلاَمٌ عَلَيْكُمْ';
      // Query without diacritics
      final ranges = TextNormalizer.findMatchRanges(orig, 'سلام');
      expect(ranges.length, 1);
      // 'سَلاَمٌ' spans indices 0..6 in original text
      expect(ranges.first.start, 0);
      expect(orig.substring(ranges.first.start, ranges.first.end), 'سَلاَمٌ');
    });

    test('matches across Alef variants', () {
      const orig = 'أحمد وإسلام';
      final ranges = TextNormalizer.findMatchRanges(orig, 'احمد');
      expect(ranges.length, 1);
      expect(orig.substring(ranges.first.start, ranges.first.end), 'أحمد');
    });

    test('matches across Yaa and Alef Maksura', () {
      const orig = 'ذهب إلى موسى';
      final ranges = TextNormalizer.findMatchRanges(orig, 'موسي');
      expect(ranges.length, 1);
      expect(orig.substring(ranges.first.start, ranges.first.end), 'موسى');
    });

    test('matches across digits', () {
      const orig = 'الحلقة ١٢';
      final ranges = TextNormalizer.findMatchRanges(orig, '12');
      expect(ranges.length, 1);
      expect(orig.substring(ranges.first.start, ranges.first.end), '١٢');
    });

    test('matches English case-insensitively', () {
      const orig = 'My Cool Song.mp4';
      final ranges = TextNormalizer.findMatchRanges(orig, 'cool');
      expect(ranges.length, 1);
      expect(orig.substring(ranges.first.start, ranges.first.end), 'Cool');
    });
  });

  group('TextNormalizer.buildSpan', () {
    test('creates styled spans correctly', () {
      const orig = 'Hello World';
      final span = TextNormalizer.buildSpan(
        text: orig,
        query: 'world',
        style: const TextStyle(color: Colors.black),
        highlightStyle: const TextStyle(color: Colors.red),
      );

      expect(span.children, isNotNull);
      expect(span.children!.length, 2);
      expect((span.children![0] as TextSpan).text, 'Hello ');
      expect((span.children![1] as TextSpan).text, 'World');
      expect((span.children![1] as TextSpan).style?.color, Colors.red);
    });
  });
}
