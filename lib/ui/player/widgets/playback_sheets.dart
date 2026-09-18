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

const List<double> kSpeedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
const List<int> kSleepMinutes = [15, 30, 45, 60];

/// Everything that used to sit on the control bar but is not needed at a
/// glance: speed, A-B repeat, shuffle and the sleep timer.
///
/// Each row shows its current state, so the bar itself no longer has to.
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
          // Everything the library's own menu offers for this video, so the
          // player does not have to be left to reach it.
          final playable = player.current;
          final video = playable is Video ? playable : null;
          final library = context.read<LibraryController>();

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetTitle(s.more),
                _OptionRow(
                  icon: AppIcons.lock_outline_rounded,
                  title: s.lock,
                  value: '',
                  onTap: () {
                    Navigator.pop(context);
                    player.toggleLock();
                  },
                ),
                _OptionRow(
                  icon: AppIcons.speed_rounded,
                  title: s.playbackSpeed,
                  value: Fmt.speed(player.speed),
                  active: player.speed != 1.0,
                  onTap: () {
                    Navigator.pop(context);
                    showSpeedSheet(context);
                  },
                ),
                _OptionRow(
                  icon: switch (player.loopMode) {
                    LoopMode.one => AppIcons.repeat_one_rounded,
                    _ => AppIcons.repeat_rounded,
                  },
                  title: s.repeat,
                  value: player.loopMode.label(s),
                  active: player.loopMode != LoopMode.off,
                  onTap: player.cycleLoopMode,
                ),
                _OptionRow(
                  icon: AppIcons.shuffle_rounded,
                  title: s.shuffle,
                  value: player.shuffle ? s.repeatAll : s.repeatOff,
                  active: player.shuffle,
                  onTap: player.toggleShuffle,
                  trailing: Switch.adaptive(
                    value: player.shuffle,
                    onChanged: (_) => player.toggleShuffle(),
                  ),
                ),
                if (settings.abRepeatEnabled)
                  _OptionRow(
                    icon: AppIcons.repeat_one_on_rounded,
                    title: s.abRepeat,
                    value: player.pointA == null
                        ? s.repeatOff
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
                  _OptionRow(
                    icon: AppIcons.bedtime_outlined,
                    title: s.sleepTimer,
                    value: sleeping == null
                        ? s.repeatOff
                        : Fmt.duration(sleeping),
                    active: sleeping != null,
                    onTap: () {
                      Navigator.pop(context);
                      showSleepTimerSheet(context);
                    },
                  ),
                if (video != null) ...[
                  const SizedBox(height: 6),
                  _OptionRow(
                    icon: library.isFavorite(video.id)
                        ? AppIcons.favorite
                        : AppIcons.favorite_border,
                    title: library.isFavorite(video.id)
                        ? s.removeFromFavorites
                        : s.addToFavorites,
                    value: '',
                    active: library.isFavorite(video.id),
                    onTap: () => library.toggleFavorite(video.id),
                  ),
                  _OptionRow(
                    icon: AppIcons.playlist_add_rounded,
                    title: s.addToPlaylist,
                    value: '',
                    onTap: () async {
                      Navigator.pop(context);
                      await showAddToPlaylistSheet(context, [video.id]);
                    },
                  ),
                  _OptionRow(
                    icon: AppIcons.drive_file_move_outline,
                    title: s.moveTo,
                    value: '',
                    onTap: () async {
                      Navigator.pop(context);
                      await showMoveToSheet(context, [video]);
                    },
                  ),
                  _OptionRow(
                    icon: AppIcons.drive_file_rename_outline_rounded,
                    title: s.rename,
                    value: '',
                    onTap: () async {
                      Navigator.pop(context);
                      await promptRenameVideo(context, library, video);
                    },
                  ),
                  _OptionRow(
                    icon: library.isVideoHidden(video.id)
                        ? AppIcons.visibility_rounded
                        : AppIcons.visibility_off_outlined,
                    title: library.isVideoHidden(video.id)
                        ? s.unhideVideo
                        : s.hideVideo,
                    value: '',
                    active: library.isVideoHidden(video.id),
                    onTap: () => library.toggleVideoHidden(video.id),
                  ),
                  _OptionRow(
                    icon: AppIcons.info_outline_rounded,
                    title: s.videoInfo,
                    value: '',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VideoInfoPage(video: video),
                        ),
                      );
                    },
                  ),
                  _OptionRow(
                    icon: AppIcons.delete_outline_rounded,
                    title: s.deleteFromDevice,
                    value: '',
                    destructive: true,
                    onTap: () async {
                      Navigator.pop(context);
                      // Leave the player first: the file is about to go.
                      closePlayer(context, stopPlayback: true);
                      await confirmDeleteVideo(context, library, video);
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.active = false,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool active;

  /// Deleting: the row is tinted the warning colour.
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent
        : (active ? context.accent : context.muted);

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
                        trailing: isCurrent
                            ? Icon(
                                AppIcons.equalizer_rounded,
                                color: context.accent,
                                size: 18,
                              )
                            : null,
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
