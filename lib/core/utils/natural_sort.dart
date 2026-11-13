/// Utility for Natural Sort Order with episode number extraction.
///
/// Features:
/// - Natural sort order: digit sequences are compared as numeric values (2 < 10).
/// - Case-insensitive string comparison with deterministic case tie-breaking.
/// - Normalization of Arabic-Indic digits (٠-٩, ۰-۹) to standard ASCII digits.
/// - Episode number extraction in priority order:
///   1. Season & Episode (S01E02, s1e2, 1x02)
///   2. Episode keyword (Episode 2, Ep 2, E02)
///   3. Arabic Episode (الحلقة 2, حلقة 2, الموسم 1 الحلقة 2)
/// - Non-episode metadata filtering (1080p, 720p, 4k, x264, x265, 2024, 5.1).
/// - Precomputable [NaturalSortKey] for O(N) extraction and fast O(N log N) sorting.
class NaturalSort {
  const NaturalSort._();

  /// Compares two strings using natural sort order with episode number extraction.
  static int compare(String a, String b) {
    if (identical(a, b)) return 0;
    final keyA = NaturalSortKey.from(a);
    final keyB = NaturalSortKey.from(b);
    return keyA.compareTo(keyB);
  }

  /// Converts Arabic-Indic digits (٠-٩, ۰-۹) to standard ASCII digits (0-9).
  static String normalizeDigits(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Compares two plain strings using standard natural sort (without episode extraction).
  static int compareNaturalText(String a, String b) {
    if (identical(a, b)) return 0;
    final chunksA = _chunkString(normalizeDigits(a));
    final chunksB = _chunkString(normalizeDigits(b));

    final minLen = chunksA.length < chunksB.length ? chunksA.length : chunksB.length;
    for (var i = 0; i < minLen; i++) {
      final ca = chunksA[i];
      final cb = chunksB[i];

      final isNumA = ca.isNumeric;
      final isNumB = cb.isNumeric;

      if (isNumA && isNumB) {
        final cmp = ca.numberValue.compareTo(cb.numberValue);
        if (cmp != 0) return cmp;
        // Tie breaker for equal numbers with leading zeros (e.g. "2" vs "02")
        final lenCmp = ca.text.length.compareTo(cb.text.length);
        if (lenCmp != 0) return lenCmp;
      } else if (isNumA) {
        // Digits sort before text in natural ASCII order
        return -1;
      } else if (isNumB) {
        return 1;
      } else {
        final cmp = ca.textLower.compareTo(cb.textLower);
        if (cmp != 0) return cmp;
        final caseCmp = ca.text.compareTo(cb.text);
        if (caseCmp != 0) return caseCmp;
      }
    }

    return chunksA.length.compareTo(chunksB.length);
  }

  static final RegExp _chunkRegex = RegExp(r'(\d+|\D+)');

  static List<_SortChunk> _chunkString(String s) {
    if (s.isEmpty) return const [];
    final list = <_SortChunk>[];
    for (final match in _chunkRegex.allMatches(s)) {
      final str = match.group(0)!;
      final isDigit = str.codeUnitAt(0) >= 0x30 && str.codeUnitAt(0) <= 0x39;
      if (isDigit) {
        list.add(_SortChunk.numeric(str));
      } else {
        list.add(_SortChunk.text(str));
      }
    }
    return list;
  }
}

/// Precomputed sort key for a video file name.
/// Precomputing keys avoids re-running regexes on every comparison during sorting.
class NaturalSortKey implements Comparable<NaturalSortKey> {
  NaturalSortKey._({
    required this.rawName,
    required this.normalizedFull,
    required this.seriesPrefix,
    required this.season,
    required this.episode,
  });

  factory NaturalSortKey.from(String name) {
    final normalized = NaturalSort.normalizeDigits(name);
    final episodeInfo = _extractEpisodeInfo(normalized);

    return NaturalSortKey._(
      rawName: name,
      normalizedFull: normalized,
      seriesPrefix: episodeInfo?.seriesPrefix ?? '',
      season: episodeInfo?.season,
      episode: episodeInfo?.episode,
    );
  }

  final String rawName;
  final String normalizedFull;
  final String seriesPrefix;
  final int? season;
  final int? episode;

  bool get hasEpisode => episode != null;

  @override
  int compareTo(NaturalSortKey other) {
    if (identical(this, other)) return 0;

    // 1. Both files have detected episode numbers
    if (hasEpisode && other.hasEpisode) {
      // If both belong to the same series prefix, sort by season and episode
      final prefixCmp = NaturalSort.compareNaturalText(seriesPrefix, other.seriesPrefix);
      if (prefixCmp == 0) {
        final s1 = season ?? 1;
        final s2 = other.season ?? 1;
        if (s1 != s2) return s1.compareTo(s2);

        if (episode != other.episode) {
          return episode!.compareTo(other.episode!);
        }

        // Exact same season and episode: fallback to natural full name
        return NaturalSort.compareNaturalText(normalizedFull, other.normalizedFull);
      }

      // Different series prefixes: sort by series prefix naturally
      return prefixCmp;
    }

    // 2. Only one has an episode number or neither has one:
    // If one has an episode and the other doesn't, check if they share the same prefix
    if (hasEpisode != other.hasEpisode) {
      final prefix = hasEpisode ? seriesPrefix : other.seriesPrefix;
      if (prefix.isNotEmpty) {
        final otherPrefix = other.hasEpisode ? other.seriesPrefix : _cleanPrefix(other.normalizedFull);
        final pCmp = NaturalSort.compareNaturalText(prefix, otherPrefix);
        if (pCmp != 0) {
          return NaturalSort.compareNaturalText(normalizedFull, other.normalizedFull);
        }
      }
    }

    // 3. Fallback: plain Natural Sort on the full name
    return NaturalSort.compareNaturalText(normalizedFull, other.normalizedFull);
  }

  // --------------------------------------------------- Episode Extraction
  static final RegExp _cleanTrim = RegExp(r'^[\s._\-]+|[\s._\-]+$');

  static String _cleanPrefix(String s) {
    var str = s.replaceFirst(_cleanTrim, '');
    // Strip trailing brackets/parentheses e.g. "Show - "
    str = str.replaceAll(RegExp(r'[\s._\-]+$'), '');
    return str;
  }

  // Priority 1: S01E02 / s1e2 / S01.E02 / s01_e02 / S01 - E02
  static final RegExp _p1SeasonEpisode = RegExp(
    r'(?:^|[\s._\-\[\(])[sS](\d{1,4})\s*[\._\-\s]*[eE](\d{1,4})(?:[\s._\-\]\)]|$)',
  );

  // Priority 1 fallback: 01x02 / 1x02
  static final RegExp _p1XFormat = RegExp(
    r'(?:^|[\s._\-\[\(])(\d{1,2})[xX](\d{1,3})(?:[\s._\-\]\)]|$)',
  );

  // Priority 2: Episode 2 / Ep 2 / Ep. 02
  static final RegExp _p2EpisodeWord = RegExp(
    r'(?:^|[\s._\-\[\(])(?:episode|ep)[\s._\-\:]*(\d{1,4})(?:[\s._\-\]\)]|$)',
    caseSensitive: false,
  );

  // Priority 2: Standalone E02 / E2
  static final RegExp _p2StandaloneE = RegExp(
    r'(?:^|[\s._\-\[\(])[eE](\d{1,4})(?:[\s._\-\]\)]|$)',
  );

  // Priority 3: Arabic Episode (الحلقة 2 / حلقة 2)
  static final RegExp _p3ArabicEpisode = RegExp(
    r'(?:الحلقة|حلقة)[\s._\-]*(\d{1,4})',
    caseSensitive: false,
  );

  // Priority 3: Optional Arabic Season (الموسم 2 / الجزء 2)
  static final RegExp _p3ArabicSeason = RegExp(
    r'(?:الموسم|الجزء)[\s._\-]*(\d{1,4})',
    caseSensitive: false,
  );

  static _EpisodeMatch? _extractEpisodeInfo(String normalized) {
    // Priority 1: S01E02 style
    final m1 = _p1SeasonEpisode.firstMatch(normalized);
    if (m1 != null) {
      final s = int.tryParse(m1.group(1)!);
      final e = int.tryParse(m1.group(2)!);
      if (e != null) {
        final prefix = _cleanPrefix(normalized.substring(0, m1.start));
        return _EpisodeMatch(seriesPrefix: prefix, season: s, episode: e);
      }
    }

    // Priority 1 alt: 1x02 style (ensure first number is season <= 50 to avoid resolution e.g. 1920x1080)
    final m1x = _p1XFormat.firstMatch(normalized);
    if (m1x != null) {
      final s = int.tryParse(m1x.group(1)!);
      final e = int.tryParse(m1x.group(2)!);
      if (s != null && s <= 50 && e != null) {
        final prefix = _cleanPrefix(normalized.substring(0, m1x.start));
        return _EpisodeMatch(seriesPrefix: prefix, season: s, episode: e);
      }
    }

    // Priority 2: Episode / Ep keyword
    final m2 = _p2EpisodeWord.firstMatch(normalized);
    if (m2 != null) {
      final e = int.tryParse(m2.group(1)!);
      if (e != null) {
        final prefix = _cleanPrefix(normalized.substring(0, m2.start));
        return _EpisodeMatch(seriesPrefix: prefix, season: null, episode: e);
      }
    }

    // Priority 2 alt: Standalone E02
    final m2e = _p2StandaloneE.firstMatch(normalized);
    if (m2e != null) {
      final e = int.tryParse(m2e.group(1)!);
      if (e != null) {
        final prefix = _cleanPrefix(normalized.substring(0, m2e.start));
        return _EpisodeMatch(seriesPrefix: prefix, season: null, episode: e);
      }
    }

    // Priority 3: Arabic Episode (الحلقة 2)
    final m3 = _p3ArabicEpisode.firstMatch(normalized);
    if (m3 != null) {
      final e = int.tryParse(m3.group(1)!);
      if (e != null) {
        int? s;
        final m3s = _p3ArabicSeason.firstMatch(normalized);
        if (m3s != null) {
          s = int.tryParse(m3s.group(1)!);
        }
        final matchStart = (m3s != null && m3s.start < m3.start) ? m3s.start : m3.start;
        final prefix = _cleanPrefix(normalized.substring(0, matchStart));
        return _EpisodeMatch(seriesPrefix: prefix, season: s, episode: e);
      }
    }

    return null;
  }
}

class _EpisodeMatch {
  const _EpisodeMatch({
    required this.seriesPrefix,
    required this.season,
    required this.episode,
  });

  final String seriesPrefix;
  final int? season;
  final int? episode;
}

class _SortChunk {
  _SortChunk.text(this.text)
      : isNumeric = false,
        textLower = text.toLowerCase(),
        numberValue = BigInt.zero;

  _SortChunk.numeric(this.text)
      : isNumeric = true,
        textLower = '',
        numberValue = BigInt.tryParse(text) ?? BigInt.zero;

  final String text;
  final bool isNumeric;
  final String textLower;
  final BigInt numberValue;
}

