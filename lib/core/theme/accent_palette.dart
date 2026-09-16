import 'package:flutter/material.dart';

/// One accent the user can pick, in the three shades the app needs.
class AccentOption {
  const AccentOption({
    required this.key,
    required this.onLight,
    required this.onDark,
    required this.washLight,
    required this.washDark,
  });

  final String key;

  /// Deep enough to read as text and icons on a white card.
  final Color onLight;

  /// Light enough to read on a dark surface, and on top of video.
  final Color onDark;

  /// The pastel wash behind a selected pill or navigation item.
  final Color washLight;
  final Color washDark;

  /// What the swatch in the picker shows.
  Color swatch(Brightness brightness) =>
      brightness == Brightness.dark ? onDark : onLight;
}

/// The accents offered in Settings. All muted rather than saturated, so the
/// app keeps its calm feel whichever one is chosen.
class AccentPalette {
  const AccentPalette._();

  static const String defaultKey = 'sage';

  static const List<AccentOption> options = [
    AccentOption(
      key: 'sage',
      onLight: Color(0xFF34795C),
      onDark: Color(0xFF8ACBA8),
      washLight: Color(0xFFDCEBE1),
      washDark: Color(0xFF23392E),
    ),
    AccentOption(
      key: 'terracotta',
      onLight: Color(0xFFB2593B),
      onDark: Color(0xFFE9A184),
      washLight: Color(0xFFF6E2DA),
      washDark: Color(0xFF3B2720),
    ),
    AccentOption(
      key: 'indigo',
      onLight: Color(0xFF42589E),
      onDark: Color(0xFF9FB0E8),
      washLight: Color(0xFFE0E4F4),
      washDark: Color(0xFF232941),
    ),
    AccentOption(
      key: 'plum',
      onLight: Color(0xFF8A4A72),
      onDark: Color(0xFFDDA3C6),
      washLight: Color(0xFFF2E1EC),
      washDark: Color(0xFF382334),
    ),
    AccentOption(
      key: 'teal',
      onLight: Color(0xFF1F7079),
      onDark: Color(0xFF86C9D0),
      washLight: Color(0xFFD9EBEE),
      washDark: Color(0xFF1C363A),
    ),
    AccentOption(
      key: 'amber',
      onLight: Color(0xFF946318),
      onDark: Color(0xFFE6BC72),
      washLight: Color(0xFFF7EBD6),
      washDark: Color(0xFF3A2E1A),
    ),
    AccentOption(
      key: 'rose',
      onLight: Color(0xFFAE4A5C),
      onDark: Color(0xFFE9A0AC),
      washLight: Color(0xFFF7E0E4),
      washDark: Color(0xFF3B2328),
    ),
    AccentOption(
      key: 'slate',
      onLight: Color(0xFF4E5C68),
      onDark: Color(0xFFA9B7C4),
      washLight: Color(0xFFE3E8ED),
      washDark: Color(0xFF272E35),
    ),
  ];

  static AccentOption byKey(String? key) =>
      options.firstWhere((o) => o.key == key, orElse: () => options.first);
}
