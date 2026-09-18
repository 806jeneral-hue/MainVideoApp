import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/app_sheet.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/song.dart';
import '../../../data/models/video.dart';
import '../../../state/library_controller.dart';
import '../../../state/playback_controller.dart';
import '../../folders/add_to_playlist_sheet.dart';
import '../../video/move_to_sheet.dart';
import '../../video/video_actions_sheet.dart';
import '../../video/video_info_page.dart';
import '../player_page.dart';
import '../../common/video_thumbnail.dart';
import '../../music/widgets/album_art.dart';
import '../../common/glass_controls.dart';
import '../../../core/theme/app_icons.dart';
import '../../common/app_icon.dart';
import '../../../state/bookmark_controller.dart';
import '../../common/glass_snack_bar.dart';
import '../../../data/models/bookmark.dart';
import '../../common/glass_dialog.dart';
import '../../common/quick_tiles.dart';

const List<double> kSpeedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
const List<int> kSleepMinutes = [15, 30, 45, 60];

/// The player's More menu, in three short sections so it fits on one screen:
/// playback settings as small tiles showing their state, the marks as one row,
/// and what can be done to the video file as tiles, with delete apart at the
/// foot so it is never hit by mistake.
Future<void> showPlayerOptionsSheet(BuildContext context) {
  final player = context.read<PlaybackController>();

  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: Consumer<PlaybackController>(
        builder: (context, player, _) {
          final s = context.s;
          final settings = player.settings;
          final sleeping = player.sleepRemaining;
          final playable = player.current;
          final video = playable is Video ? playable : null;
          final library = context.watch<LibraryController>();

          final playback = <Widget>[
            QuickTile(
              icon: AppIcons.speed_rounded,
              label: s.playbackSpeed,
              value: Fmt.speed(player.speed),
              active: player.speed != 1.0,
              onTap: () {
                Navigator.pop(context);
                showSpeedSheet(context);
              },
            ),
            QuickTile(
              icon: switch (player.loopMode) {
                LoopMode.one => AppIcons.repeat_one_rounded,
                _ => AppIcons.repeat_rounded,
              },
              label: s.repeat,
              value: player.loopMode.label(s),
              active: player.loopMode != LoopMode.off,
              onTap: player.cycleLoopMode,
            ),
            QuickTile(
              icon: AppIcons.shuffle_rounded,
              label: s.shuffle,
              value: player.shuffle ? s.switchOn : s.switchOff,
              active: player.shuffle,
              onTap: player.toggleShuffle,
            ),
            if (settings.abRepeatEnabled)
              QuickTile(
                icon: AppIcons.repeat_one_on_rounded,
                label: s.abRepeat,
                value: player.pointA == null
                    ? '—'
                    : (player.pointB == null
                          ? Fmt.duration(player.pointA!)
                          : s.abLooping(
                              Fmt.duration(player.pointA!),
                              Fmt.duration(player.pointB!),
                            )),
                active: player.pointA != null,
                onTap: () {
                  player.markAbPoint();
                  Navigator.pop(context);
                },
              ),
            if (settings.sleepTimerEnabled)
              QuickTile(
                icon: AppIcons.bedtime_outlined,
                label: s.sleepTimer,
                value: sleeping == null ? '—' : Fmt.duration(sleeping),
                active: sleeping != null,
                onTap: () {
                  Navigator.pop(context);
                  showSleepTimerSheet(context);
                },
              ),
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetSectionLabel(s.sectionPlayback),
                  TileGrid(tiles: playback),
                  if (video != null) ...[
                    SheetSectionLabel(s.sectionMarks),
                    Row(
                      children: [
                        Expanded(
                          child: PillAction(
                            icon: AppIcons.bookmark_rounded,
                            label: s.markStopHere,
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final at = Fmt.duration(player.position);
                              Navigator.pop(context);
                              await player.markStopHere();
                              messenger.showSnackBar(
                                glassSnackBar(
                                  icon: AppIcons.bookmark_rounded,
                                  content: Text(s.stopMarked(at)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PillAction(
                            icon: AppIcons.add_rounded,
                            label: s.saveMomentShort,
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              final when = player.position;
                              final at = Fmt.duration(when);
                              final note = await askMomentNote(
                                context,
                                title: s.momentAt(at),
                              );
                              if (note == null) return;
                              navigator.pop();
                              final added = await player.addMomentHere(
                                at: when,
                                note: note,
                              );
                              messenger.showSnackBar(
                                glassSnackBar(
                                  icon: AppIcons.bookmark_rounded,
                                  content: Text(
                                    added ? s.momentSaved(at) : s.momentExists,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PillAction(
                            icon: AppIcons.checklist_rounded,
                            label: s.momentsShort(
                              context
                                  .watch<BookmarkController>()
                                  .momentsFor(video.id)
                                  .length,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              showMomentsSheet(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    SheetSectionLabel(s.sectionVideo),
                    TileGrid(
                      tiles: [
                        QuickTile(
                          icon: library.isFavorite(video.id)
                              ? AppIcons.favorite
                              : AppIcons.favorite_border,
                          label: s.tileFavorite,
                          active: library.isFavorite(video.id),
                          onTap: () => library.toggleFavorite(video.id),
                        ),
                        QuickTile(
                          icon: AppIcons.playlist_add_rounded,
                          label: s.tilePlaylist,
                          onTap: () async {
                            Navigator.pop(context);
                            await showAddToPlaylistSheet(context, [video.id]);
                          },
                        ),
                        QuickTile(
                          icon: AppIcons.drive_file_move_outline,
                          label: s.tileMove,
                          onTap: () async {
                            Navigator.pop(context);
                            await showMoveToSheet(context, [video]);
                          },
                        ),
                        QuickTile(
                          icon: AppIcons.drive_file_rename_outline_rounded,
                          label: s.tileRename,
                          onTap: () async {
                            Navigator.pop(context);
                            await promptRenameVideo(context, library, video);
                          },
                        ),
                        QuickTile(
                          icon: library.isVideoHidden(video.id)
                              ? AppIcons.visibility_rounded
                              : AppIcons.visibility_off_outlined,
                          label: library.isVideoHidden(video.id)
                              ? s.tileUnhide
                              : s.tileHide,
                          active: library.isVideoHidden(video.id),
                          onTap: () => library.toggleVideoHidden(video.id),
                        ),
                        QuickTile(
                          icon: AppIcons.info_outline_rounded,
                          label: s.tileInfo,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoInfoPage(video: video),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DangerRow(
                      label: s.deleteFromDevice,
                      onTap: () async {
                        Navigator.pop(context);
                        // Leave the player first: the file is about to go.
                        closePlayer(context, stopPlayback: true);
                        await confirmDeleteVideo(context, library, video);
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Asks for a moment's note. Returns the note — empty is fine — or null when
/// the user backs out.
Future<String?> askMomentNote(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final s = context.s;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: s.momentNoteHint,
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(s.save),
        ),
      ],
    ),
  );
}

/// Every moment saved in the video that is playing: tap one to jump there,
/// or take it off the list.
Future<void> showMomentsSheet(BuildContext context) {
  final player = context.read<PlaybackController>();
  final bookmarks = context.read<BookmarkController>();

  return showAppSheet<void>(
    context,
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: bookmarks),
      ],
      child: Builder(
        builder: (context) {
          final s = context.s;
          final id = context.select<PlaybackController, String?>(
            (p) => p.currentOrNull?.id,
          );
          final moments = id == null
              ? const <Moment>[]
              : context.watch<BookmarkController>().momentsFor(id);

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetTitle(s.momentsIndex),
                if (moments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      s.momentsEmpty,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: context.muted),
                    ),
                  )
                else
                  for (var i = 0; i < moments.length; i++)
                    _OptionRow(
                      icon: AppIcons.bookmark_rounded,
                      // The note names the moment; without one it is numbered.
                      title: moments[i].note.isEmpty
                          ? s.momentLabel(i + 1)
                          : moments[i].note,
                      value: Fmt.duration(moments[i].position),
                      active: true,
                      onTap: () {
                        Navigator.pop(context);
                        player.seekTo(moments[i].position);
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.editNote,
                            icon: Icon(
                              AppIcons.edit_rounded,
                              size: 19,
                              color: context.muted,
                            ),
                            onPressed: () async {
                              final note = await askMomentNote(
                                context,
                                title: s.momentAt(
                                  Fmt.duration(moments[i].position),
                                ),
                                initial: moments[i].note,
                              );
                              if (note == null) return;
                              await bookmarks.setMomentNote(
                                id!,
                                moments[i].ms,
                                note,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: Icon(
                              AppIcons.close_rounded,
                              size: 20,
                              color: context.muted,
                            ),
                            onPressed: () =>
                                bookmarks.removeMoment(id!, moments[i].ms),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// The playing mark, and — in a custom session — how many times the item
/// plays: "×3", or "2/3" on the one playing now.
class _QueueTrailing extends StatelessWidget {
  const _QueueTrailing({
    required this.isCurrent,
    required this.times,
    required this.play,
  });

  final bool isCurrent;
  final int times;
  final int play;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final count = times > 1
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isCurrent ? 0.9 : 0.16),
              borderRadius: AppTheme.pillRadius,
            ),
            child: Text(
              isCurrent ? '$play/$times' : '×$times',
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isCurrent
                    ? Theme.of(context).colorScheme.onPrimary
                    : accent,
              ),
            ),
          )
        : null;
    if (!isCurrent) return count ?? const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?count,
        if (count != null) const SizedBox(width: 8),
        Icon(AppIcons.equalizer_rounded, color: accent, size: 18),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.active = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool active;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.accent : context.muted;

    return GlassTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active
              ? context.accentWash
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppTheme.thumbRadius,
        ),
        child: Icon(icon, size: 21, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: value.isEmpty
          ? null
          : Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
      trailing: trailing,
    );
  }
}

/// Playback speed picker (phase 4).
Future<void> showSpeedSheet(BuildContext context) {
  final player = context.read<PlaybackController>();

  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: Consumer<PlaybackController>(
        builder: (context, player, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetTitle(context.s.playbackSpeed),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final speed in kSpeedOptions)
                      ChoiceChip(
                        label: Text(Fmt.speed(speed)),
                        selected: player.speed == speed,
                        onSelected: (_) => player.setSpeed(speed),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sleep timer with the 15/30/45/60 options from phase 4.
Future<void> showSleepTimerSheet(BuildContext context) {
  final player = context.read<PlaybackController>();

  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: Consumer<PlaybackController>(
        builder: (context, player, _) {
          final remaining = player.sleepRemaining;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetTitle(context.s.sleepTimer),
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: Text(
                      context.s.sleepStopsIn(Fmt.duration(remaining)),
                      style: TextStyle(
                        color: context.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final minutes in kSleepMinutes)
                        ActionChip(
                          label: Text(context.s.minutesOption(minutes)),
                          onPressed: () {
                            player.startSleepTimer(Duration(minutes: minutes));
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                ),
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: TextButton.icon(
                      onPressed: () {
                        player.cancelSleepTimer();
                        Navigator.pop(context);
                      },
                      icon: const AppIcon(AppIcons.close_rounded, size: 18),
                      label: Text(context.s.cancelTimer),
                    ),
                  ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// The list of videos queued behind the one playing.
Future<void> showQueueSheet(BuildContext context) {
  final player = context.read<PlaybackController>();

  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: Consumer<PlaybackController>(
        builder: (context, player, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetTitle(context.s.queueWithCount(player.queue.length)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: player.queue.length,
                    itemBuilder: (context, index) {
                      final item = player.queue[index];
                      final isCurrent = index == player.index;

                      return GlassTile(
                        selected: isCurrent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        leading: switch (item) {
                          Song song => AlbumArt(song: song, size: 46),
                          Video video => VideoThumbnail(
                            video: video,
                            width: 76,
                            height: 46,
                          ),
                          _ => const SizedBox(width: 46),
                        },
                        title: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isCurrent ? context.accent : null,
                          ),
                        ),
                        subtitle: Text(
                          item.isAudio && item.subtitle.isNotEmpty
                              ? '${item.subtitle}  ·  ${Fmt.durationMs(item.durationMs)}'
                              : Fmt.durationMs(item.durationMs),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _QueueTrailing(
                          isCurrent: isCurrent,
                          times: player.playsFor(item),
                          play: player.currentPlay,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          player.playAt(index);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
