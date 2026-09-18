import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../state/music_controller.dart';
import '../common/bottom_fade.dart';
import '../common/empty_state.dart';
import '../common/fast_scroller.dart';
import '../common/glass.dart';
import '../player/mini_player.dart';
import 'music_actions.dart';
import 'song_list_page.dart';
import 'widgets/album_art.dart';
import 'widgets/music_tiles.dart';
import 'widgets/song_sliver.dart';
import '../../core/theme/app_icons.dart';
import '../common/app_icon.dart';
import '../common/quick_menu.dart';
import '../common/play_menus.dart';
import 'song_picker_page.dart';
import 'song_selection.dart';
import '../common/selection.dart';

enum MusicSection { songs, albums, artists, folders, playlists }

/// One whole section of the music library, opened from a tile on the Music
/// tab: all songs, all albums, all artists, the folders, or the playlists.
class MusicSectionPage extends StatefulWidget {
  const MusicSectionPage({super.key, required this.section});

  final MusicSection section;

  static Future<void> open(BuildContext context, MusicSection section) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MusicSectionPage(section: section),
        ),
      );

  @override
  State<MusicSectionPage> createState() => _MusicSectionPageState();
}

class _MusicSectionPageState extends State<MusicSectionPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final s = context.s;

    final title = switch (widget.section) {
      MusicSection.songs => s.songs,
      MusicSection.albums => s.albums,
      MusicSection.artists => s.artists,
      MusicSection.folders => s.musicFolders,
      MusicSection.playlists => s.musicPlaylists,
    };

    // All songs can be ticked several at a time, like the videos.
    return SongSelectionScope(
      builder: (context, selection) => Scaffold(
        extendBody: true,
        appBar: selection.active
            ? buildSelectionAppBar(
                context: context,
                count: selection.count,
                onClose: selection.clear,
                onSelectAll: () => selection.selectAll([
                  for (final song in music.songs) song.id,
                ]),
              )
            : AppBar(
                title: Text(title),
                actions: [
                  if (widget.section == MusicSection.songs)
                    HeaderAction(
                      tooltip: s.sortBy,
                      icon: const AppIcon(AppIcons.swap_vert_rounded),
                      onPressed: () => showMusicSortSheet(context),
                    ),
                  if (widget.section == MusicSection.playlists)
                    HeaderAction(
                      tooltip: s.newMusicPlaylist,
                      highlighted: true,
                      icon: const AppIcon(AppIcons.add_rounded),
                      onPressed: () => _createPlaylist(music),
                    ),
                  const SizedBox(width: AppTheme.pageMargin),
                ],
              ),
        bottomNavigationBar: selection.active
            ? SongSelectionBar(
                selected: selection.pick(music.songs),
                onDone: selection.clear,
                queueTitle: s.songs,
              )
            : const SafeArea(
                top: false,
                child: MiniPlayer(aboveNavigation: false),
              ),
        body: BottomFade(
          child: FastScroller(
            controller: _scrollController,
            bottomPadding: listBottomInset(context, extra: 0),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.space8),
                ),
                ..._slivers(context, music, selection),
                SliverToBoxAdapter(
                  child: SizedBox(height: listBottomInset(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPlaylist(MusicController music) async {
    final name = await promptForMusicPlaylistName(context);
    if (name == null || name.trim().isEmpty) return;
    final playlist = await music.createPlaylist(name);
    if (!mounted) return;
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) =>
            SongPickerPage(title: context.s.addToPlaylistTitle(playlist.name)),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      await music.addToPlaylist(playlist.id, picked);
    }
    if (mounted) _open(SongListPage.playlist(playlist.id));
  }

  List<Widget> _slivers(
    BuildContext context,
    MusicController music,
    SongSelection selection,
  ) {
    final s = context.s;

    switch (widget.section) {
      case MusicSection.songs:
        final songs = music.songs;
        if (songs.isEmpty) return [_empty(context)];
        return [
          SliverToBoxAdapter(
            child: PlayShuffleRow(
              onPlay: () =>
                  playSongs(context, songs, shuffle: false, title: s.songs),
              onShuffle: () =>
                  playSongs(context, songs, shuffle: true, title: s.songs),
              onPlayLongPress: (anchor) => showQuickMenu(
                context,
                anchor: anchor,
                actions: songPlayActions(
                  context,
                  planKey: 'music:all',
                  songs: songs,
                  title: s.songs,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MusicListLabel(text: s.songCount(songs.length)),
          ),
          SongSliver(songs: songs, title: s.songs, selection: selection),
        ];

      case MusicSection.albums:
        final albums = music.albums;
        if (albums.isEmpty) return [_empty(context)];
        return [
          SliverToBoxAdapter(
            child: MusicListLabel(text: s.albumCount(albums.length)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageMargin,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppTheme.space12,
                crossAxisSpacing: AppTheme.space12,
                mainAxisExtent: _albumCardHeight(context),
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) => AlbumCard(
                album: albums[index],
                onTap: () => _open(SongListPage.album(albums[index].key)),
              ),
            ),
          ),
        ];

      case MusicSection.artists:
        final artists = music.artists;
        if (artists.isEmpty) return [_empty(context)];
        return [
          SliverList.builder(
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return MusicCollectionTile(
                leading: AlbumArt(
                  song: artist.songs.first,
                  size: 52,
                  radius: BorderRadius.circular(26),
                ),
                title: artist.name.isEmpty ? s.unknownArtist : artist.name,
                subtitle:
                    '${s.songCount(artist.songs.length)}  ·  ${s.albumCount(artist.albums.length)}',
                onTap: () => _open(SongListPage.artist(artist.name)),
              );
            },
          ),
        ];

      case MusicSection.folders:
        final folders = music.folders;
        if (folders.isEmpty) return [_empty(context)];
        return [
          SliverList.builder(
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return MusicCollectionTile(
                leading: const MusicIconTile(icon: AppIcons.folder_rounded),
                title: folder.name,
                subtitle: s.songCount(folder.songs.length),
                onTap: () => _open(SongListPage.folder(folder.path)),
              );
            },
          ),
        ];

      case MusicSection.playlists:
        if (music.playlists.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: AppIcons.queue_music_rounded,
                title: s.noMusicPlaylists,
                message: s.noMusicPlaylistsBody,
                action: FilledButton.icon(
                  onPressed: () => _createPlaylist(music),
                  icon: const Icon(AppIcons.add_rounded),
                  label: Text(s.newMusicPlaylist),
                ),
              ),
            ),
          ];
        }
        return [
          SliverList.builder(
            itemCount: music.playlists.length,
            itemBuilder: (context, index) {
              final playlist = music.playlists[index];
              final songs = music.songsIn(playlist);
              return MusicCollectionTile(
                leading: songs.isEmpty
                    ? const MusicIconTile(icon: AppIcons.queue_music_rounded)
                    : AlbumArt(
                        song: songs.first,
                        size: 48,
                        radius: BorderRadius.circular(12),
                      ),
                title: playlist.name,
                subtitle: s.songCount(songs.length),
                onTap: () => _open(SongListPage.playlist(playlist.id)),
                onMore: () => showMusicPlaylistActions(context, playlist),
              );
            },
          ),
        ];
    }
  }

  /// The square cover plus the two lines under it, sized from the real
  /// column width and font scale so cards never leave a gap or overflow.
  double _albumCardHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final usable = width - AppTheme.pageMargin * 2;
    final columns = ((usable + AppTheme.space12) / (220 + AppTheme.space12))
        .ceil()
        .clamp(1, 12);
    final cell = (usable - AppTheme.space12 * (columns - 1)) / columns;
    final scaler = MediaQuery.textScalerOf(context);
    return 8 +
        (cell - 16) +
        8 +
        scaler.scale(14) * 1.4 +
        scaler.scale(12.5) * 1.4 +
        10;
  }

  Widget _empty(BuildContext context) {
    final s = context.s;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyState(
        icon: AppIcons.library_music_outlined,
        title: s.noSongsFound,
        message: s.noSongsFoundBody,
      ),
    );
  }
}
