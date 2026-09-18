import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/models/song.dart';
import '../../data/services/background_audio_service.dart';
import '../../data/services/video_file_service.dart' show FileOpStatus;
import '../../state/music_controller.dart';
import '../../state/playback_controller.dart';
import '../common/app_sheet.dart';
import '../folders/add_to_playlist_sheet.dart' show promptForPlaylistName;
import 'now_playing_page.dart';
import 'song_list_page.dart';
import 'widgets/album_art.dart';
import 'widgets/music_tiles.dart';
import '../common/glass_dialog.dart';
import '../common/glass_controls.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';
import '../common/quick_tiles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../player/widgets/playback_sheets.dart';

/// Plays [songs] starting at [index] and opens the music player over the
/// screen. [shuffle] plays them in a random order starting from a random
/// song, the way a Shuffle button should.
Future<void> playSongs(
  BuildContext context,
  List<Song> songs, {
  int index = 0,
  bool? shuffle,
  String title = '',

  /// A custom session: how many times in a row each song plays, by id.
  Map<String, int>? plays,
}) {
  if (songs.isEmpty) return Future.value();
  _askForNotificationsOnce();
  final start = shuffle == true ? Random().nextInt(songs.length) : index;
  final opening = context.read<PlaybackController>().open(
    queue: songs,
    startIndex: start,
    queueTitle: title,
    shuffle: shuffle,
    plays: plays,
  );
  // The queue is registered synchronously, so the player can open straight
  // away and show the song while it loads.
  openNowPlaying(context);
  return opening;
}

/// Music shows its controls in the notification shade, which Android 13+
/// only allows with permission. It is asked the first time music plays, once —
/// never again on every song.
void _askForNotificationsOnce() {
  final settings = AppDatabase.settings;
  if (settings.get(SettingsKeys.musicAskedNotifications) == true) return;
  settings.put(SettingsKeys.musicAskedNotifications, true);
  BackgroundAudioService.ensureNotificationPermission();
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      glassSnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

/// Everything that can be done with one song.
Future<void> showSongActions(
  BuildContext context,
  Song song, {
  String? playlistId,
  String queueTitle = '',

  /// Starts ticking songs, with this one ticked.
  VoidCallback? onSelect,
}) {
  final music = context.read<MusicController>();
  final playback = context.read<PlaybackController>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final s = context.s;

  void toast(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      glassSnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );

  return showAppSheet<void>(
    context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final artist = song.artist.isEmpty ? s.unknownArtist : song.artist;

      Widget action(IconData icon, String label, VoidCallback onTap) =>
          GlassTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: Icon(icon),
            title: Text(label),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  AlbumArt(song: song, size: 56),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: sheetContext.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            if (onSelect != null)
              action(AppIcons.checklist_rounded, s.select, onSelect),
            action(AppIcons.queue_play_next_rounded, s.playNext, () {
              playback.playNext([song], queueTitle: queueTitle);
              toast(s.willPlayNext);
            }),
            action(AppIcons.add_to_queue_rounded, s.addToQueue, () {
              playback.addToQueue([song], queueTitle: queueTitle);
              toast(s.addedToQueue);
            }),
            ListenableBuilder(
              listenable: music,
              builder: (_, _) {
                final favorite = music.isFavorite(song.id);
                return action(
                  favorite
                      ? AppIcons.favorite_rounded
                      : AppIcons.favorite_border_rounded,
                  favorite ? s.removeFromFavorites : s.addToFavorites,
                  () => music.toggleFavorite(song.id),
                );
              },
            ),
            action(AppIcons.playlist_add_rounded, s.addToMusicPlaylist, () {
              if (context.mounted) {
                showAddToMusicPlaylistSheet(context, [song]);
              }
            }),
            if (playlistId != null)
              action(
                AppIcons.playlist_remove_rounded,
                s.removeFromThisPlaylist,
                () => music.removeFromPlaylist(playlistId, song.id),
              ),
            action(AppIcons.album_outlined, s.goToAlbum, () {
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => SongListPage.album(song.albumKey),
                ),
              );
            }),
            action(AppIcons.person_outline_rounded, s.goToArtist, () {
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => SongListPage.artist(song.artist),
                ),
              );
            }),
            const SizedBox(height: AppTheme.space8),
            GlassTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: Icon(
                AppIcons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                s.deleteSong,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                if (context.mounted) _confirmDelete(context, song);
              },
            ),
            const SizedBox(height: AppTheme.space8),
          ],
        ),
      );
    },
  );
}

/// Asks for a name for a new song playlist.
Future<String?> promptForMusicPlaylistName(BuildContext context) =>
    promptForPlaylistName(
      context,
      title: context.s.newMusicPlaylist,
      actionLabel: context.s.create,
    );

/// Picks a playlist for [songs], or makes a new one for them.
Future<void> showAddToMusicPlaylistSheet(
  BuildContext context,
  List<Song> songs,
) {
  final music = context.read<MusicController>();
  final s = context.s;

  return showAppSheet<void>(
    context,
    builder: (sheetContext) {
      Future<void> addTo(String id, String name) async {
        Navigator.pop(sheetContext);
        await music.addToPlaylist(id, [for (final song in songs) song.id]);
        if (context.mounted) _toast(context, s.addedToPlaylist(name));
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Text(
                s.addToMusicPlaylist,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            GlassTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: const MusicIconTile(
                icon: AppIcons.add_rounded,
                size: 44,
              ),
              title: Text(s.newMusicPlaylist),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await promptForMusicPlaylistName(context);
                if (name == null || name.trim().isEmpty) return;
                final playlist = await music.createPlaylist(name);
                await music.addToPlaylist(playlist.id, [
                  for (final song in songs) song.id,
                ]);
                if (context.mounted) {
                  _toast(context, s.addedToPlaylist(playlist.name));
                }
              },
            ),
            for (final playlist in music.playlists)
              GlassTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                leading: const MusicIconTile(
                  icon: AppIcons.queue_music_rounded,
                  size: 44,
                ),
                title: Text(playlist.name),
                subtitle: Text(s.songCount(playlist.songIds.length)),
                onTap: () => addTo(playlist.id, playlist.name),
              ),
            const SizedBox(height: AppTheme.space8),
          ],
        ),
      );
    },
  );
}

/// How songs are ordered in the Songs section.
Future<void> showMusicSortSheet(BuildContext context) {
  final s = context.s;

  return showAppSheet<void>(
    context,
    builder: (sheetContext) => Consumer<MusicController>(
      builder: (context, music, _) {
        final labels = {
          SongSort.title: s.sortTitle,
          SongSort.artist: s.sortArtist,
          SongSort.album: s.sortAlbum,
          SongSort.dateAdded: s.sortDateAdded,
          SongSort.duration: s.sortDuration,
        };

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassSheetTitle(s.sortBy),
              for (final entry in labels.entries)
                GlassTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                  leading: Icon(
                    AppIcons.sort_rounded,
                    color: music.sort == entry.key ? context.accent : null,
                  ),
                  title: Text(entry.value),
                  selected: music.sort == entry.key,
                  trailing: music.sort == entry.key
                      ? Icon(AppIcons.check_rounded, color: context.accent)
                      : null,
                  onTap: () => music.setSort(entry.key),
                ),
              const SizedBox(height: AppTheme.space12),
              GlassSheetTitle(s.order),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageMargin,
                  AppTheme.space4,
                  AppTheme.pageMargin,
                  AppTheme.space12,
                ),
                child: GlassSegmented<bool>(
                  segments: [
                    GlassSegment(
                      value: false,
                      icon: AppIcons.north_rounded,
                      label: s.ascending,
                    ),
                    GlassSegment(
                      value: true,
                      icon: AppIcons.south_rounded,
                      label: s.descending,
                    ),
                  ],
                  selected: music.descending,
                  onChanged: music.setDescending,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Rename or delete a playlist.
Future<void> showMusicPlaylistActions(
  BuildContext context,
  MusicPlaylist playlist, {
  VoidCallback? onDeleted,
}) {
  final music = context.read<MusicController>();
  final s = context.s;

  return showAppSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: const Icon(AppIcons.edit_outlined),
            title: Text(s.renamePlaylist),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await promptForPlaylistName(
                context,
                initial: playlist.name,
                title: s.renamePlaylist,
                actionLabel: s.rename,
              );
              if (name == null || name.trim().isEmpty) return;
              await music.renamePlaylist(playlist.id, name);
            },
          ),
          GlassTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: Icon(
              AppIcons.delete_outline_rounded,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text(
              s.deletePlaylist,
              style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => GlassDialog(
                  title: Text(s.deletePlaylist),
                  content: Text(s.deletePlaylistBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(s.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(s.delete),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await music.deletePlaylist(playlist.id);
              onDeleted?.call();
            },
          ),
          const SizedBox(height: AppTheme.space8),
        ],
      ),
    ),
  );
}

/// Everything that can be done while a song is playing, laid out like the
/// video player's More menu: playback settings as tiles, the song's own
/// actions as tiles, and delete on its own at the foot.
Future<void> showNowPlayingOptions(BuildContext context, Song song) {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final s = context.s;

  // Leaves the music player for a list page: the song keeps playing in the
  // mini player underneath.
  void openPage(BuildContext sheetContext, Widget page) {
    Navigator.pop(sheetContext);
    rootNavigator
      ..maybePop()
      ..push(MaterialPageRoute<void>(builder: (_) => page));
  }

  return showAppSheet<void>(
    context,
    builder: (sheetContext) => Consumer2<PlaybackController, MusicController>(
      builder: (sheetContext, playback, music, _) {
        final theme = Theme.of(sheetContext);
        final sleeping = playback.sleepRemaining;
        final favorite = music.isFavorite(song.id);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AlbumArt(song: song, size: 52),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            song.artist.isEmpty ? s.unknownArtist : song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: sheetContext.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SheetSectionLabel(s.sectionPlayback),
                TileGrid(
                  tiles: [
                    QuickTile(
                      icon: AppIcons.speed_rounded,
                      label: s.playbackSpeed,
                      value: Fmt.speed(playback.speed),
                      active: playback.speed != 1.0,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showSpeedSheet(context);
                      },
                    ),
                    QuickTile(
                      icon: AppIcons.bedtime_outlined,
                      label: s.sleepTimer,
                      value: sleeping == null ? '—' : Fmt.duration(sleeping),
                      active: sleeping != null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showSleepTimerSheet(context);
                      },
                    ),
                    QuickTile(
                      icon: switch (playback.loopMode) {
                        LoopMode.one => AppIcons.repeat_one_rounded,
                        _ => AppIcons.repeat_rounded,
                      },
                      label: s.repeat,
                      value: playback.loopMode.label(s),
                      active: playback.loopMode != LoopMode.off,
                      onTap: playback.cycleLoopMode,
                    ),
                    QuickTile(
                      icon: AppIcons.shuffle_rounded,
                      label: s.shuffle,
                      value: playback.shuffle ? s.switchOn : s.switchOff,
                      active: playback.shuffle,
                      onTap: playback.toggleShuffle,
                    ),
                    QuickTile(
                      icon: AppIcons.queue_music_rounded,
                      label: s.tileQueue,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showQueueSheet(context);
                      },
                    ),
                  ],
                ),
                SheetSectionLabel(s.sectionSong),
                TileGrid(
                  tiles: [
                    QuickTile(
                      icon: favorite
                          ? AppIcons.favorite_rounded
                          : AppIcons.favorite_border_rounded,
                      label: s.tileFavorite,
                      active: favorite,
                      onTap: () => music.toggleFavorite(song.id),
                    ),
                    QuickTile(
                      icon: AppIcons.playlist_add_rounded,
                      label: s.tilePlaylist,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showAddToMusicPlaylistSheet(context, [song]);
                      },
                    ),
                    QuickTile(
                      icon: AppIcons.album_outlined,
                      label: s.tileAlbum,
                      onTap: () => openPage(
                        sheetContext,
                        SongListPage.album(song.albumKey),
                      ),
                    ),
                    QuickTile(
                      icon: AppIcons.person_outline_rounded,
                      label: s.tileArtist,
                      onTap: () => openPage(
                        sheetContext,
                        SongListPage.artist(song.artist),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DangerRow(
                  label: s.deleteSong,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(context, song);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Asks first, then deletes the song from the device.
Future<void> _confirmDelete(BuildContext context, Song song) async {
  final music = context.read<MusicController>();
  final messenger = ScaffoldMessenger.of(context);
  final s = context.s;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: Text(s.deleteSong),
      content: Text(s.deleteSongBody(song.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final result = await music.deleteSong(song);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      glassSnackBar(
        content: Text(
          result.ok
              ? s.songDeleted
              : switch (result.status) {
                  FileOpStatus.denied => s.permissionDenied,
                  FileOpStatus.notFound => s.fileGone,
                  _ => s.couldNotDelete,
                },
        ),
      ),
    );
}
