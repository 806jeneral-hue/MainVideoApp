import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/song.dart';
import '../../common/glass.dart';
import 'album_art.dart';
import '../../../core/theme/app_icons.dart';
import '../../common/app_icon.dart';
import '../../common/quick_menu.dart';

/// Height of a [SongTile] including the gap under it, for fixed-extent lists.
const double kSongTileExtent = 76;

/// One song as a glass row: cover, title, artist and length, and the menu.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    required this.onMore,
    this.isCurrent = false,
    this.leadingNumber,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback onMore;

  /// While songs are being ticked, a tap ticks and the menu steps aside.
  final bool selectionMode;
  final bool selected;

  /// Holding a row: starts a selection when the list offers one, otherwise
  /// opens the menu.
  final VoidCallback? onLongPress;

  /// The song playing right now is marked in the accent.
  final bool isCurrent;

  /// Track number instead of the cover, for an album's own list.
  final int? leadingNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.muted;
    final s = context.s;
    final artist = song.artist.isEmpty ? s.unknownArtist : song.artist;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        AppTheme.space8,
      ),
      child: SizedBox(
        height: kSongTileExtent - AppTheme.space8,
        child: GlassSurface(
          radius: BorderRadius.circular(20),
          selected: isCurrent || selected,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress ?? onMore,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 2, 0),
                child: Row(
                  children: [
                    if (selectionMode) ...[
                      Icon(
                        selected
                            ? AppIcons.check_circle_rounded
                            : AppIcons.circle_outlined,
                        color: selected ? context.accent : muted,
                        size: 22,
                      ),
                      const SizedBox(width: AppTheme.space8),
                    ],
                    if (leadingNumber != null)
                      SizedBox(
                        width: 48,
                        child: Center(
                          child: isCurrent
                              ? Icon(
                                  AppIcons.graphic_eq_rounded,
                                  color: context.accent,
                                  size: 22,
                                )
                              : Text(
                                  '$leadingNumber',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: muted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                        ),
                      )
                    else
                      AlbumArt(
                        song: song,
                        size: 48,
                        radius: BorderRadius.circular(12),
                      ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isCurrent ? context.accent : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$artist  ·  ${Fmt.durationMs(song.durationMs)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent && leadingNumber == null)
                      Icon(
                        AppIcons.graphic_eq_rounded,
                        color: context.accent,
                        size: 20,
                      ),
                    if (selectionMode)
                      const SizedBox(width: AppTheme.space12)
                    else
                      IconButton(
                        onPressed: onMore,
                        tooltip: s.more,
                        icon: const Icon(AppIcons.more_vert),
                        color: muted,
                        iconSize: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An album in a grid: its cover large, the name and the artist under it.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    return GlassSurface(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => AlbumArt(
                    song: album.cover,
                    size: constraints.maxWidth,
                    radius: BorderRadius.circular(AppTheme.radiusThumb),
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    album.name.isEmpty ? s.unknownAlbum : album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    album.artist.isEmpty
                        ? s.songCount(album.songs.length)
                        : album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass row for anything that opens a list of songs: an artist, a folder,
/// a playlist.
class MusicCollectionTile extends StatelessWidget {
  const MusicCollectionTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onMore,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        AppTheme.space8,
      ),
      child: GlassSurface(
        radius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMore,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                10,
                10,
                onMore == null ? 16 : 2,
                10,
              ),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onMore != null)
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(AppIcons.more_vert),
                      color: context.muted,
                      iconSize: 20,
                    )
                  else
                    AppIcon(
                      AppIcons.chevron_right_rounded,
                      color: context.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The accent-tinted square used where a list has no cover of its own.
class MusicIconTile extends StatelessWidget {
  const MusicIconTile({super.key, required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Icon(icon, color: accent, size: size * 0.46),
    );
  }
}

/// The two big actions at the top of any list of songs.
class PlayShuffleRow extends StatelessWidget {
  const PlayShuffleRow({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.onPlayLongPress,
  });

  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  /// Holding Play All: its quick menu, from the button's rectangle.
  final void Function(Rect anchor)? onPlayLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        AppTheme.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: PressScale(
              child: Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: onPlay,
                  onLongPress: onPlayLongPress == null
                      ? null
                      : () => onPlayLongPress!(anchorOf(buttonContext)),
                  icon: const AppIcon(AppIcons.play_arrow_rounded),
                  label: Text(s.playAll),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: PressScale(
              child: GlassSurface(
                radius: AppTheme.pillRadius,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onShuffle,
                    borderRadius: AppTheme.pillRadius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.shuffle_rounded,
                            size: 20,
                            color: context.accent,
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Text(
                            s.shuffleAll,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
