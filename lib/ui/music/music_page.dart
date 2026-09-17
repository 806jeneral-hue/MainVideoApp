import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playable.dart';
import '../../data/models/song.dart';
import '../../state/music_controller.dart';
import '../../state/playback_controller.dart';
import '../common/bottom_fade.dart';
import '../common/empty_state.dart';
import '../common/glass.dart';
import '../common/tab_header.dart';
import '../common/tab_scroll.dart';
import 'music_actions.dart';
import 'music_section_page.dart';
import 'now_playing_page.dart';
import 'song_list_page.dart';
import 'widgets/album_art.dart';
import 'widgets/music_tiles.dart';
import 'widgets/song_sliver.dart';
import '../../core/theme/app_icons.dart';
import '../common/app_icon.dart';

/// The Music tab: a library home rather than one long list.
///
/// At the top, what is playing or what played last, ready to pick up. Under it
/// a tile for each part of the library — each opens as its own page — and
/// rows of covers for the songs played and added most recently. Search in the
/// header covers songs, albums and artists at once.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _ownScrollController = ScrollController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Reading the library waits for the tab to actually be opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MusicController>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ownScrollController.dispose();
    super.dispose();
  }

  void _toggleSearch(MusicController music) {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      music.clearQuery();
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final s = context.s;
    final scrollController = TabScroll.maybeOf(context) ?? _ownScrollController;

    final header = TabHeader(
      title: s.music,
      searching: _searching,
      searchController: _searchController,
      searchHint: s.searchMusic,
      onQueryChanged: music.setQuery,
      onToggleSearch: () => _toggleSearch(music),
      // Sorting belongs to the song list itself, not to the library home.
      onSortAndLayout: null,
    );

    if (music.status != MusicStatus.ready) {
      return Scaffold(
        body: Column(
          children: [
            header,
            Expanded(child: _StatusView(status: music.status)),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: context.accent,
        onRefresh: music.refresh,
        child: BottomFade(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: header),
              if (music.query.isNotEmpty)
                ..._searchSlivers(context, music)
              else if (music.allSongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: AppIcons.library_music_outlined,
                    title: s.noSongsFound,
                    message: s.noSongsFoundBody,
                  ),
                )
              else
                ..._librarySlivers(context, music),
              SliverToBoxAdapter(
                child: SizedBox(height: listBottomInset(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- library
  List<Widget> _librarySlivers(BuildContext context, MusicController music) {
    final s = context.s;
    final recent = music.recentlyPlayed;
    final added = _recentlyAdded(music.allSongs);

    return [
      const SliverToBoxAdapter(child: _ListeningCard()),
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space16)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageMargin),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
            mainAxisSpacing: AppTheme.space12,
            crossAxisSpacing: AppTheme.space12,
            mainAxisExtent: _LibraryTile.heightFor(context),
          ),
          delegate: SliverChildListDelegate([
            _LibraryTile(
              icon: AppIcons.music_note_rounded,
              title: s.songs,
              count: '${music.allSongs.length}',
              onTap: () => MusicSectionPage.open(context, MusicSection.songs),
            ),
            _LibraryTile(
              icon: AppIcons.album_rounded,
              title: s.albums,
              count: '${music.albums.length}',
              onTap: () => MusicSectionPage.open(context, MusicSection.albums),
            ),
            _LibraryTile(
              icon: AppIcons.mic_rounded,
              title: s.artists,
              count: '${music.artists.length}',
              onTap: () => MusicSectionPage.open(context, MusicSection.artists),
            ),
            _LibraryTile(
              icon: AppIcons.folder_rounded,
              title: s.musicFolders,
              count: '${music.folders.length}',
              onTap: () => MusicSectionPage.open(context, MusicSection.folders),
            ),
            _LibraryTile(
              icon: AppIcons.queue_music_rounded,
              title: s.musicPlaylists,
              count: '${music.playlists.length}',
              onTap: () =>
                  MusicSectionPage.open(context, MusicSection.playlists),
            ),
            _LibraryTile(
              icon: AppIcons.favorite_rounded,
              title: s.favoriteSongs,
              count: '${music.favoriteSongs.length}',
              onTap: () => _open(SongListPage.favorites()),
            ),
          ]),
        ),
      ),
      if (recent.isNotEmpty)
        SliverToBoxAdapter(
          child: _CoverRow(
            title: s.recentlyPlayedSongs,
            songs: recent.take(15).toList(),
            onSeeAll: () => _open(SongListPage.recent()),
          ),
        ),
      if (added.isNotEmpty)
        SliverToBoxAdapter(
          child: _CoverRow(title: s.recentlyAddedSongs, songs: added),
        ),
    ];
  }

  static List<Song> _recentlyAdded(List<Song> songs) =>
      (List<Song>.from(songs)
            ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded)))
          .take(15)
          .toList(growable: false);

  // ------------------------------------------------------------------ search
  List<Widget> _searchSlivers(BuildContext context, MusicController music) {
    final s = context.s;
    final results = music.results;

    if (results.songs.isEmpty &&
        results.albums.isEmpty &&
        results.artists.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: AppIcons.search_off_rounded,
            title: s.nothingFound,
            message: s.noMusicMatches(music.query),
          ),
        ),
      ];
    }

    return [
      if (results.artists.isNotEmpty) ...[
        SliverToBoxAdapter(child: MusicListLabel(text: s.artists)),
        SliverList.builder(
          itemCount: results.artists.length.clamp(0, 5),
          itemBuilder: (context, index) {
            final artist = results.artists[index];
            return MusicCollectionTile(
              leading: AlbumArt(
                song: artist.songs.first,
                size: 52,
                radius: BorderRadius.circular(26),
              ),
              title: artist.name,
              subtitle: s.songCount(artist.songs.length),
              onTap: () => _open(SongListPage.artist(artist.name)),
            );
          },
        ),
      ],
      if (results.albums.isNotEmpty) ...[
        SliverToBoxAdapter(child: MusicListLabel(text: s.albums)),
        SliverList.builder(
          itemCount: results.albums.length.clamp(0, 5),
          itemBuilder: (context, index) {
            final album = results.albums[index];
            return MusicCollectionTile(
              leading: AlbumArt(
                song: album.cover,
                size: 52,
                radius: BorderRadius.circular(12),
              ),
              title: album.name.isEmpty ? s.unknownAlbum : album.name,
              subtitle: album.artist.isEmpty
                  ? s.songCount(album.songs.length)
                  : album.artist,
              onTap: () => _open(SongListPage.album(album.key)),
            );
          },
        ),
      ],
      if (results.songs.isNotEmpty) ...[
        SliverToBoxAdapter(child: MusicListLabel(text: s.songs)),
        SongSliver(songs: results.songs, title: s.songs),
      ],
    ];
  }
}

/// What is playing now — or what played last, or a shuffle of everything
/// when nothing has played yet — as one big card to pick up from.
class _ListeningCard extends StatelessWidget {
  const _ListeningCard();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final music = context.watch<MusicController>();
    final (current, controller) = context
        .select<PlaybackController, (Playable?, VideoPlayerController?)>(
          (p) => (p.currentOrNull, p.player),
        );

    final playingSong = current is Song ? current : null;
    final lastSong = music.recentlyPlayed.isEmpty
        ? null
        : music.recentlyPlayed.first;
    final song = playingSong ?? lastSong;

    final label = playingSong != null
        ? s.nowPlaying
        : (song != null ? s.continueListening : s.shuffleAllSongs);

    void onTap() {
      if (playingSong != null) {
        openNowPlaying(context);
      } else if (song != null) {
        playSongs(
          context,
          music.recentlyPlayed,
          index: 0,
          shuffle: false,
          title: s.recentlyPlayedSongs,
        );
      } else {
        playSongs(context, music.allSongs, shuffle: true, title: s.songs);
      }
    }

    Widget playButton(bool playing) => Material(
      color: theme.colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: playingSong != null
            ? context.read<PlaybackController>().togglePlay
            : onTap,
        child: SizedBox.square(
          dimension: 50,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: AppIcon(
              playing
                  ? AppIcons.pause_rounded
                  : (song == null
                        ? AppIcons.shuffle_rounded
                        : AppIcons.play_arrow_rounded),
              key: ValueKey('$playing-${song == null}'),
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageMargin),
      child: PressScale(
        scale: 0.97,
        child: GlassSurface(
          floating: true,
          selected: playingSong != null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppTheme.cardRadius,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space12),
                child: Row(
                  children: [
                    if (song != null)
                      AlbumArt(
                        song: song,
                        size: 68,
                        radius: BorderRadius.circular(16),
                      )
                    else
                      const MusicIconTile(
                        icon: AppIcons.shuffle_rounded,
                        size: 68,
                      ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: context.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song?.title ?? s.songCount(music.allSongs.length),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (song != null)
                            Text(
                              song.artist.isEmpty
                                  ? s.unknownArtist
                                  : song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    if (playingSong != null && controller != null)
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) =>
                            playButton(value.isPlaying),
                      )
                    else
                      playButton(false),
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

/// A glass tile for one part of the library.
class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String count;
  final VoidCallback onTap;

  static const double _icon = 44;
  static const double _padding = 14;

  /// Tall enough for the icon or the two lines of text, whichever is taller,
  /// at the user's font size.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = scaler.scale(15) * 1.35 + 2 + scaler.scale(12.5) * 1.35;
    return (text > _icon ? text : _icon) + _padding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressScale(
      scale: 0.96,
      child: GlassSurface(
        radius: BorderRadius.circular(22),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Row(
                children: [
                  MusicIconTile(icon: icon, size: _icon),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.muted,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
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

/// A heading and a row of covers; a cover plays the row from that song.
class _CoverRow extends StatelessWidget {
  const _CoverRow({required this.title, required this.songs, this.onSeeAll});

  final String title;
  final List<Song> songs;
  final VoidCallback? onSeeAll;

  static const double _cover = 116;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    final currentId = context.select<PlaybackController, String?>(
      (p) => p.currentOrNull?.id,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight =
        _cover + 8 + scaler.scale(13.5) * 1.35 + scaler.scale(12) * 1.35 + 4;

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTheme.pageMargin + 4,
              0,
              AppTheme.pageMargin - 4,
              AppTheme.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(onPressed: onSeeAll, child: Text(s.seeAll)),
              ],
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pageMargin,
              ),
              itemCount: songs.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppTheme.space12),
              itemBuilder: (context, index) {
                final song = songs[index];
                final playing = song.id == currentId;
                return SizedBox(
                  width: _cover,
                  child: PressScale(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => playSongs(
                        context,
                        songs,
                        index: index,
                        shuffle: false,
                        title: title,
                      ),
                      onLongPress: () =>
                          showSongActions(context, song, queueTitle: title),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              AlbumArt(
                                song: song,
                                size: _cover,
                                radius: BorderRadius.circular(18),
                              ),
                              if (playing)
                                PositionedDirectional(
                                  end: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      AppIcons.graphic_eq_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: playing ? context.accent : null,
                            ),
                          ),
                          Text(
                            song.artist.isEmpty ? s.unknownArtist : song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.35,
                              color: context.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Waiting for permission or reading the library.
class _StatusView extends StatelessWidget {
  const _StatusView({required this.status});

  final MusicStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final music = context.read<MusicController>();

    switch (status) {
      case MusicStatus.needsPermission:
      case MusicStatus.permanentlyDenied:
        final permanent = status == MusicStatus.permanentlyDenied;
        return Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: AppIcons.library_music_outlined,
              title: s.musicPermissionTitle,
              message: s.musicPermissionBody,
              action: FilledButton(
                onPressed: permanent ? openAppSettings : music.requestAccess,
                child: Text(permanent ? s.openSettings : s.allowAccess),
              ),
            ),
          ),
        );
      case MusicStatus.idle:
      case MusicStatus.loading:
      case MusicStatus.ready:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: context.accent),
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                s.scanningMusic,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.muted),
              ),
            ],
          ),
        );
    }
  }
}
