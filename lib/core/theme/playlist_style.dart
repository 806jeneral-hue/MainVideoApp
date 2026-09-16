import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The icons and colours a playlist can be given so it is recognisable at a
/// glance in the Folders screen.
///
/// Both are stored as short stable keys / ARGB ints rather than as Flutter
/// objects, so the choice survives restarts.
class PlaylistStyle {
  const PlaylistStyle._();

  static const Map<String, IconData> icons = {
    'playlist': Icons.queue_music_rounded,
    'star': Icons.star_rounded,
    'movie': Icons.movie_creation_rounded,
    'camera': Icons.videocam_rounded,
    'music': Icons.music_note_rounded,
    'school': Icons.school_rounded,
    'work': Icons.work_rounded,
    'sports': Icons.sports_soccer_rounded,
    'travel': Icons.flight_rounded,
    'family': Icons.family_restroom_rounded,
    'game': Icons.sports_esports_rounded,
    'bookmark': Icons.bookmark_rounded,
  };

  /// Warm, calm palette in keeping with the app's visual direction.
  static const List<Color> colors = [
    AppTheme.accent, // default palette seed
    Color(0xFFE5B14C),
    Color(0xFF7FA98B),
    Color(0xFF6C93BF),
    Color(0xFF9B7EBD),
    Color(0xFFD2748C),
    Color(0xFFC9705A),
    Color(0xFF8A8F98),
  ];

  static IconData iconFor(String? key) =>
      icons[key] ?? Icons.queue_music_rounded;

  static Color colorFor(int? value, {Color fallback = AppTheme.accent}) =>
      value == null ? fallback : Color(value);
}
