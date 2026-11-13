import 'package:flutter/material.dart';

/// Pure Dart utility for Arabic and multilingual text normalization,
/// matching, and substring highlight range mapping.
class TextNormalizer {
  const TextNormalizer._();

  /// Normalizes [input] for search matching:
  /// - Case-insensitive (lowercase)
  /// - Strips Arabic diacritics (tashkeel / harakat)
  /// - Strips tatweel (kashida)
  /// - Unifies Alef variants (أ, إ, آ, ٱ -> ا)
  /// - Unifies Yaa / Alef Maksura (ى, ی -> ي)
  /// - Unifies Taa Marbuta (ة -> ه)
  /// - Unifies Arabic-Indic digits (٠-٩, ۰-۹ -> 0-9)
  /// - Collapses multiple spaces and trims
  static String normalize(String input) {
    if (input.isEmpty) return '';
    return NormalizedText.from(input).normalized;
  }

  /// Finds all match ranges of [query] within [originalText] in original
  /// text coordinate space, correctly accounting for stripped diacritics,
  /// tatweel, and letter normalization.
  static List<TextRange> findMatchRanges(String originalText, String query) {
    if (originalText.isEmpty || query.isEmpty) return const [];

    final normQuery = normalize(query);
    if (normQuery.isEmpty) return const [];

    final normText = NormalizedText.from(originalText);
    if (normText.normalized.isEmpty) return const [];

    final qLen = normQuery.length;
    final ranges = <TextRange>[];

    int startIndex = 0;
    while (true) {
      final matchIndex = normText.normalized.indexOf(normQuery, startIndex);
      if (matchIndex == -1) break;

      final normEnd = matchIndex + qLen;
      final origStart = normText.originalIndices[matchIndex];

      int origEnd;
      if (normEnd < normText.originalIndices.length) {
        origEnd = normText.originalIndices[normEnd];
      } else {
        // Reached end of normalized text: map to end of original text,
        // but exclude trailing whitespace.
        final lastMappedOrig = normText.originalIndices[normEnd - 1];
        origEnd = lastMappedOrig + 1;
        while (origEnd < originalText.length) {
          final c = originalText.codeUnitAt(origEnd);
          if (_isDiacriticOrTatweel(c)) {
            origEnd++;
          } else {
            break;
          }
        }
      }

      ranges.add(TextRange(start: origStart, end: origEnd));
      startIndex = matchIndex + qLen;
    }

    return ranges;
  }

  /// Builds a [TextSpan] representing [text] where all occurrences of
  /// [query] are styled with [highlightStyle], while remaining text uses [style].
  static TextSpan buildSpan({
    required String text,
    required String query,
    required TextStyle? style,
    required TextStyle? highlightStyle,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: style);
    }
    if (query.trim().isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final ranges = findMatchRanges(text, query);
    if (ranges.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <TextSpan>[];
    int current = 0;

    for (final range in ranges) {
      if (range.start > current) {
        spans.add(TextSpan(
          text: text.substring(current, range.start),
          style: style,
        ));
      }
      if (range.end > range.start && range.end <= text.length) {
        spans.add(TextSpan(
          text: text.substring(range.start, range.end),
          style: highlightStyle,
        ));
        current = range.end;
      }
    }

    if (current < text.length) {
      spans.add(TextSpan(
        text: text.substring(current),
        style: style,
      ));
    }

    return TextSpan(children: spans, style: style);
  }
}

/// A pre-computed normalized representation of a string along with
/// index mappings to original character offsets.
class NormalizedText {
  NormalizedText._(this.original, this.normalized, this.originalIndices);

  final String original;
  final String normalized;

  /// For each character in [normalized], the corresponding character
  /// offset in [original].
  final List<int> originalIndices;

  factory NormalizedText.from(String original) {
    if (original.isEmpty) {
      return NormalizedText._('', '', const []);
    }

    final normBuffer = StringBuffer();
    final origIndices = <int>[];
    bool inWhitespace = false;
    final len = original.length;

    for (int i = 0; i < len; i++) {
      final code = original.codeUnitAt(i);

      // 1. Skip Arabic diacritics and tatweel
      if (_isDiacriticOrTatweel(code)) {
        continue;
      }

      // 2. Whitespace collapsing
      if (_isWhitespace(code)) {
        if (!inWhitespace && normBuffer.isNotEmpty) {
          // Collapse consecutive whitespace to a single space
          normBuffer.write(' ');
          origIndices.add(i);
          inWhitespace = true;
        }
        continue;
      }
      inWhitespace = false;

      // 3. Digits normalization (Arabic-Indic and Eastern Arabic-Indic to ASCII 0-9)
      if (code >= 0x0660 && code <= 0x0669) {
        normBuffer.writeCharCode(code - 0x0660 + 0x0030);
        origIndices.add(i);
        continue;
      }
      if (code >= 0x06F0 && code <= 0x06F9) {
        normBuffer.writeCharCode(code - 0x06F0 + 0x0030);
        origIndices.add(i);
        continue;
      }

      // 4. Arabic letter normalizations
      // Alef variants: أ (0623), إ (0625), آ (0622), ٱ (0671) -> ا (0627)
      if (code == 0x0622 || code == 0x0623 || code == 0x0625 || code == 0x0671) {
        normBuffer.writeCharCode(0x0627);
        origIndices.add(i);
        continue;
      }

      // Yaa variants: ى (0649 - Alef Maksura), ی (06CC - Persian Yeh) -> ي (064A)
      if (code == 0x0649 || code == 0x06CC) {
        normBuffer.writeCharCode(0x064A);
        origIndices.add(i);
        continue;
      }

      // Taa Marbuta: ة (0629) -> ه (0647)
      if (code == 0x0629) {
        normBuffer.writeCharCode(0x0647);
        origIndices.add(i);
        continue;
      }

      // 5. General ASCII / Latin lowercase & other characters
      final char = String.fromCharCode(code).toLowerCase();
      for (int cIdx = 0; cIdx < char.length; cIdx++) {
        normBuffer.writeCharCode(char.codeUnitAt(cIdx));
        origIndices.add(i);
      }
    }

    // Trim trailing space if any
    String normStr = normBuffer.toString();
    if (normStr.endsWith(' ') && origIndices.isNotEmpty) {
      normStr = normStr.substring(0, normStr.length - 1);
      origIndices.removeLast();
    }

    return NormalizedText._(original, normStr, origIndices);
  }
}

bool _isDiacriticOrTatweel(int code) {
  // Tatweel / Kashida
  if (code == 0x0640) return true;

  // Arabic Tashkeel / Harakat (Fathatan through Sukun)
  if (code >= 0x064B && code <= 0x065F) return true;

  // Superscript Alef / Dagger Alef
  if (code == 0x0670) return true;

  // Quranic annotation signs
  if (code >= 0x0610 && code <= 0x061A) return true;
  if (code >= 0x06D6 && code <= 0x06ED) return true;

  return false;
}

bool _isWhitespace(int code) {
  return code == 0x0020 ||
      code == 0x0009 ||
      code == 0x000A ||
      code == 0x000D ||
      code == 0x00A0 ||
      code == 0x2000 ||
      code == 0x2001 ||
      code == 0x2002 ||
      code == 0x2003 ||
      code == 0x200B ||
      code == 0x3000;
}

/// A widget that renders [text] with substring matches of [query] highlighted.
///
/// Designed to preserve line height and avoid layout shifts by sharing
/// the exact typography of [style] while applying [highlightStyle] or
/// an accent tint with bold weight.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final theme = Theme.of(context);
    final effectiveHighlight = highlightStyle ??
        (style ?? const TextStyle()).copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        );

    final span = TextNormalizer.buildSpan(
      text: text,
      query: query,
      style: style,
      highlightStyle: effectiveHighlight,
    );

    return Text.rich(
      span,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

