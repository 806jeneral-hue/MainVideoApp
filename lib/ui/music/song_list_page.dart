import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/song.dart';
import '../../state/music_controller.dart';
import '../common/bottom_fade.dart';
import '../common/empty_state.dart';
import '../common/glass.dart';
import '../player/mini_player.dart';
import 'music_actions.dart';
import 'widgets/album_art.dart';
import 'widgets/music_tiles.dart';
import 'widgets/song_sliver.dart';
import '../../core/theme/app_icons.dart';

enum _Kind { album, artist, folder, playlist, favorites, recent }

/// One list of songs opened from the Music tab: an album, an artist, a
/// folder, a playlist, the favourites or the recently played.
///
/// It reads its songs from the library on every build, so favouriting,
/// removing from a playlist or a rescan shows up straight away.
class SongListPage extends StatelessWidget {
  const SongListPage._(this._kind, [this._key = '']);

  factory SongListPage.album(String albumKey) =>
      SongListPage._(_Kind.album, albumKey);
  factory SongListPage.artist(String name) =>
      SongListPage._(_Kind.artist, name);
  factory SongListPage.folder(String path) =>
      SongListPage._(_Kind.folder, path);
  factory SongListPage.playlist(String id) =>
      SongListPage._(_Kind.playlist, id);
  factory SongListPage.favorites() => const SongListPage._(_Kind.favorites);
  factory SongListPage.recent() => const SongListPage._(_Kind.recent);

  final _Kind _kind;
  final String _key;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final s = context.s;

    // What this page is showing, worked out from the live library.
    late final String title;
    late final List<Song> songs;
    Song? cover;
    IconData icon = AppIcons.music_note_rounded;
    String? detail;
    List<Album> albums = const [];
    MusicPlaylist? playlist;
    var numbered = false;
    var emptyTitle = s.noSongsFound;
    String? emptyBody;

    switch (_kind) {
      case _Kind.album:
        final album = music.albumByKey(_key);
        title = (album?.name.isEmpty ?? true) ? s.unknownAlbum : album!.name;
        songs = album?.songs ?? const [];
        cover = album?.cover;
        detail = album?.artist;
        numbered = true;
      case _Kind.artist:
        final artist = music.artistByName(_key);
        title = _key.isEmpty ? s.unknownArtist : _key;
        songs = artist?.songs ?? const [];
        albums = artist?.albums ?? const [];
        cover = songs.isEmpty ? null : songs.first;
        icon = AppIcons.person_rounded;
        if (artist != null) detail = s.albumCount(artist.albums.length);
      case _Kind.folder:
        final folder = music.folderByPath(_key);
        title = folder?.name ?? '';
        songs = folder?.songs ?? const [];
        icon = AppIcons.folder_rounded;
      case _Kind.playlist:
        playlist = music.playlistById(_key);
        title = playlist?.name ?? '';
        songs = playlist == null ? const [] : music.songsIn(playlist);
        cover = songs.isEmpty ? null : songs.first;
        icon = AppIcons.queue_music_rounded;
        emptyTitle = s.emptyMusicPlaylist;
        emptyBody = s.emptyMusicPlaylistBody;
      case _Kind.favorites:
        title = s.favoriteSongs;
        songs = music.favoriteSongs;
        icon = AppIcons.favorite_rounded;
        emptyTitle = s.noFavoriteSongs;
        emptyBody = s.noFavoriteSongsBody;
      case _Kind.recent:
        title = s.recentlyPlayedSongs;
        songs = music.recentlyPlayed;
        icon = AppIcons.history_rounded;
        emptyTitle = s.nothingPlayedYet;
        emptyBody = s.nothingPlayedYetBody;
    }

    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);
    final subtitle = [
      if (detail != null && detail.isNotEmpty) detail,
      s.songCount(songs.length),
      if (totalMs > 0) Fmt.durationMs(totalMs),
    ].join('  ·  ');

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        actions: [
          if (playlist != null)
            HeaderAction(
              tooltip: s.more,
              icon: const Icon(AppIcons.more_vert_rounded),
              onPressed: () => showMusicPlaylistActions(
                context,
                playlist!,
                onDeleted: () {
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ),
          const SizedBox(width: AppTheme.pageMargin),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: MiniPlayer(aboveNavigation: false),
      ),
      body: BottomFade(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                cover: _kind == _Kind.favorites || _kind == _Kind.recent
                    ? null
                    : cover,
                icon: icon,
                title: title,
                subtitle: subtitle,
                round: _kind == _Kind.artist,
              ),
            ),
            if (songs.isNotEmpty)
              SliverToBoxAdapter(
                child: PlayShuffleRow(
                  onPlay: () =>
                      playSongs(context, songs, shuffle: false, title: title),
                  onShuffle: () =>
                      playSongs(context, songs, shuffle: true, title: title),
                ),
              ),
            if (albums.length > 1)
              SliverToBoxAdapter(child: _AlbumStrip(albums: albums)),
            if (songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: icon,
                  title: emptyTitle,
                  message: emptyBody,
                ),
              )
            else
              SongSliver(
                songs: songs,
                title: title,
                playlistId: playlist?.id,
                numbered: numbered,
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: listBottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big cover, the name and the counts at the top of the page.
class _Header extends StatelessWidget {
  const _Header({
    required this.cover,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.round,
  });

  final Song? cover;
  final IconData icon;
  final String title;
  final String subtitle;

  /// Artists get a round picture, albums and playlists a square one.
  final bool round;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 176.0;
    final radius = BorderRadius.circular(round ? size / 2 : 28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        AppTheme.space20,
      ),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: context.floatingShadow,
            ),
            child: cover != null
                ? AlbumArt(song: cover!, size: size, radius: radius)
                : ClipRRect(
                    borderRadius: radius,
                    child: MusicIconTile(icon: icon, size: size),
                  ),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: context.muted),
          ),
        ],
      ),
    );
  }
}

/// An artist's albums, as a row of covers above their songs.
class _AlbumStrip extends StatelessWidget {
  const _AlbumStrip({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: SizedBox(
        height: 196,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageMargin),
          itemCount: albums.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppTheme.space12),
          itemBuilder: (context, index) => SizedBox(
            width: 140,
            child: AlbumCard(
              album: albums[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SongListPage.album(albums[index].key),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
