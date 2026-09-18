import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/song.dart';
import '../../../state/playback_controller.dart';
import '../music_actions.dart';
import 'music_tiles.dart';
import '../../common/emerge.dart';
import '../song_selection.dart';

/// A fixed-height list of songs. Only the rows whose "playing" mark changes
/// rebuild when the track changes.
class SongSliver extends StatelessWidget {
  const SongSliver({
    super.key,
    required this.songs,
    required this.title,
    this.playlistId,
    this.numbered = false,
    this.selection,
  });

  final List<Song> songs;

  /// Shown as where playback came from.
  final String title;
  final String? playlistId;

  /// Track numbers instead of covers, for an album.
  final bool numbered;

  /// Set on pages that can tick several songs at once.
  final SongSelection? selection;

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
          final picking = selection?.active ?? false;
          return EmergeFromBottom(
            child: SongTile(
              song: song,
              isCurrent: song.id == currentId,
              leadingNumber: numbered ? index + 1 : null,
              selectionMode: picking,
              selected: selection?.contains(song.id) ?? false,
              onLongPress: selection == null
                  ? null
                  : () => selection!.toggle(song.id),
              onTap: picking
                  ? () => selection!.toggle(song.id)
                  : () => playSongs(context, songs, index: index, title: title),
              onMore: () => showSongActions(
                context,
                song,
                playlistId: playlistId,
                queueTitle: title,
                onSelect: selection == null
                    ? null
                    : () => selection!.toggle(song.id),
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
