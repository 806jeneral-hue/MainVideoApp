import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_icons.dart';

/// The icons and colours a playlist can be given so it is recognisable at a
/// glance in the Folders screen.
///
/// Both are stored as short stable keys / ARGB ints rather than as Flutter
/// objects, so the choice survives restarts.
class PlaylistStyle {
  const PlaylistStyle._();

  static const Map<String, IconData> icons = {
    'playlist': AppIcons.queue_music_rounded,
    'star': AppIcons.star_rounded,
    'movie': AppIcons.movie_creation_rounded,
    'camera': AppIcons.videocam_rounded,
    'music': AppIcons.music_note_rounded,
    'school': AppIcons.school_rounded,
    'work': AppIcons.work_rounded,
    'sports': AppIcons.sports_soccer_rounded,
    'travel': AppIcons.flight_rounded,
    'family': AppIcons.family_restroom_rounded,
    'game': AppIcons.sports_esports_rounded,
    'bookmark': AppIcons.bookmark_rounded,
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
      icons[key] ?? AppIcons.queue_music_rounded;

  static Color colorFor(int? value, {Color fallback = AppTheme.accent}) =>
      value == null ? fallback : Color(value);
}
