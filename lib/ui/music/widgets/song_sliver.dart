import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/song.dart';
import '../../../state/playback_controller.dart';
import '../music_actions.dart';
import 'music_tiles.dart';
import '../../common/emerge.dart';

/// A fixed-height list of songs. Only the rows whose "playing" mark changes
/// rebuild when the track changes.
class SongSliver extends StatelessWidget {
  const SongSliver({
    super.key,
    required this.songs,
    required this.title,
    this.playlistId,
    this.numbered = false,
  });

  final List<Song> songs;

  /// Shown as where playback came from.
  final String title;
  final String? playlistId;

  /// Track numbers instead of covers, for an album.
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final currentId = context.select<PlaybackController, String?>(
      (p) => p.currentOrNull?.id,
    );

    return SliverFixedExtentList(
      itemExtent: kSongTileExtent,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          return EmergeFromBottom(
            child: SongTile(
              song: song,
              isCurrent: song.id == currentId,
              leadingNumber: numbered ? index + 1 : null,
              onTap: () =>
                  playSongs(context, songs, index: index, title: title),
              onMore: () => showSongActions(
                context,
                song,
                playlistId: playlistId,
                queueTitle: title,
              ),
            ),
          );
        },
        childCount: songs.length,
        addRepaintBoundaries: false,
      ),
    );
  }
}

/// A small count or heading above a list.
class MusicListLabel extends StatelessWidget {
  const MusicListLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin + 4,
        AppTheme.space4,
        AppTheme.pageMargin + 4,
        AppTheme.space12,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
