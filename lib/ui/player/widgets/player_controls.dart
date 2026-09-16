import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/enums.dart';
import '../../../state/playback_controller.dart';
import '../player_page.dart';
import 'glass.dart';
import 'playback_sheets.dart';

/// The control overlay: a glass top bar, the transport in the middle, the
/// scrubber, and a floating panel holding the six playback toggles.
///
/// Everything is built from [GlassPanel], which takes its colours from the
/// theme — so the player is the same design system as the library screens in
/// both light and dark, and the frame stays visible behind the controls
/// instead of being covered by solid bars.
///
/// Every piece below subscribes only to what it actually shows. Watching the
/// whole controller here would rebuild the entire overlay on every position
/// tick and every frame of a drag.
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final locked = context.select<PlaybackController, bool>((p) => p.locked);

    return ValueListenableBuilder<bool>(
      valueListenable: playback.controlsVisible,
      builder: (context, visible, child) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
      child: RepaintBoundary(
        child: locked ? const _LockedOverlay() : const _FullControls(),
      ),
    );
  }
}

class _FullControls extends StatelessWidget {
  const _FullControls();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            SizedBox(height: 8),
            _TopBar(),
            Expanded(child: Center(child: _Transport())),
            _AbBanner(),
            _SeekBar(),
            SizedBox(height: 10),
            _TogglePanel(),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- top bar
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = context.read<PlaybackController>();
    final (title, queueTitle, index, total) = context
        .select<PlaybackController, (String, String, int, int)>(
          (p) => (
            p.currentOrNull?.displayName ?? '',
            p.queueTitle,
            p.index + 1,
            p.queue.length,
          ),
        );

    return Row(
      children: [
        // Chevron down rather than an arrow: this minimises into the mini
        // player, it does not leave the video behind.
        GlassCircleButton(
          icon: Icons.keyboard_arrow_down_rounded,
          size: 44,
          iconSize: 26,
          tooltip: context.s.minimise,
          onTap: () => closePlayer(context, stopPlayback: false),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: GlassPanel(
            radius: BorderRadius.circular(AppTheme.radiusSheet),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                if (queueTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$queueTitle  ·  $index / $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const _SleepChip(),
        _TopActions(playback: playback),
      ],
    );
  }
}

/// Playlist, rotation, picture-in-picture and the display mode, gathered into
/// one glass pill so four controls read as a single component.
class _TopActions extends StatelessWidget {
  const _TopActions({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final (pipEnabled, forced, fit) = context
        .select<PlaybackController, (bool, Orientation?, VideoFit)>(
          (p) => (p.settings.pipEnabled, p.forcedOrientation, p.videoFit),
        );

    return GlassPanel(
      radius: BorderRadius.circular(AppTheme.radiusSheet),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassBarIcon(
            icon: Icons.playlist_play_rounded,
            tooltip: context.s.playingQueue,
            onTap: () => showQueueSheet(context),
          ),
          GlassBarIcon(
            icon: switch (fit) {
              VideoFit.fit => Icons.fit_screen_rounded,
              VideoFit.fill => Icons.crop_free_rounded,
            },
            tooltip: '${context.s.displayMode} · ${fit.label(context.s)}',
            active: fit != VideoFit.fit,
            onTap: () {
              Haptics.light();
              playback.cycleVideoFit();
            },
          ),
          GlassBarIcon(
            icon: switch (forced) {
              null => Icons.screen_rotation_rounded,
              Orientation.landscape => Icons.stay_current_landscape_rounded,
              Orientation.portrait => Icons.stay_current_portrait_rounded,
            },
            tooltip: switch (forced) {
              null => context.s.rotationAuto,
              Orientation.landscape => context.s.rotationLandscape,
              Orientation.portrait => context.s.rotationPortrait,
            },
            active: forced != null,
            onTap: () {
              Haptics.light();
              playback.cycleOrientation();
            },
          ),
          if (pipEnabled)
            GlassBarIcon(
              icon: Icons.picture_in_picture_alt_rounded,
              tooltip: context.s.pictureInPicture,
              onTap: playback.enterPip,
            ),
        ],
      ),
    );
  }
}

/// Only shown while a sleep timer is counting down.
class _SleepChip extends StatelessWidget {
  const _SleepChip();

  @override
  Widget build(BuildContext context) {
    final remaining = context.select<PlaybackController, Duration?>(
      (p) => p.sleepRemaining,
    );
    if (remaining == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassPanel(
        radius: AppTheme.pillRadius,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_rounded, size: 14, color: context.accent),
            const SizedBox(width: 5),
            Text(
              Fmt.duration(remaining),
              style: TextStyle(
                color: context.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- transport
class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final hasNext = context.select<PlaybackController, bool>((p) => p.hasNext);

    // Transport controls keep their conventional order even in Arabic, the
    // way every media player does — rewind on the left, forward on the right.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCircleButton(
            icon: Icons.skip_previous_rounded,
            size: 52,
            iconSize: 26,
            tooltip: context.s.previous,
            // Always available: with nothing before it, it restarts the video.
            onTap: playback.previous,
          ),
          const SizedBox(width: 22),
          const _PlayPauseButton(),
          const SizedBox(width: 22),
          GlassCircleButton(
            icon: Icons.skip_next_rounded,
            size: 52,
            iconSize: 26,
            tooltip: context.s.next,
            onTap: hasNext ? playback.next : null,
          ),
        ],
      ),
    );
  }
}

/// Reads the player's own value rather than a notification, so the icon can
/// never disagree with what the video is actually doing.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = context.read<PlaybackController>();
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);

    if (controller == null) {
      return GlassCircleButton(
        icon: Icons.play_arrow_rounded,
        size: 68,
        tooltip: context.s.play,
        tint: theme.colorScheme.primary,
        onTap: null,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final buffering = value.isBuffering && !value.isPlaying;
        return GlassCircleButton(
          icon: value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 68,
          iconSize: 34,
          tooltip: value.isPlaying ? context.s.pause : context.s.play,
          tint: theme.colorScheme.primary,
          iconColor: theme.colorScheme.onPrimary,
          onTap: playback.togglePlay,
          child: buffering
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ----------------------------------------------------------------- scrubber
/// Follows the player's value and the scrub notifier directly, so dragging it
/// repaints one row instead of the whole overlay.
class _SeekBar extends StatelessWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = context.read<PlaybackController>();
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);

    if (controller == null) return const SizedBox(height: 40);

    final timeStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      shadows: _readableOnVideo(theme),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => ValueListenableBuilder<Duration?>(
        valueListenable: playback.scrubPosition,
        builder: (context, scrub, _) {
          final total = value.duration;
          final position = scrub ?? value.position;
          final maxMs = total.inMilliseconds <= 0
              ? 1.0
              : total.inMilliseconds.toDouble();
          final valueMs = position.inMilliseconds
              .clamp(0, maxMs.round())
              .toDouble();
          final dragging = scrub != null;

          // Elapsed on the left, total on the right, as on every player.
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Text(Fmt.duration(position), style: timeStyle),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: dragging ? 5 : 4,
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.24),
                      thumbColor: theme.colorScheme.primary,
                      overlayColor: theme.colorScheme.primary.withValues(
                        alpha: 0.14,
                      ),
                      // The thumb grows while it is being dragged.
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: dragging ? 9 : 6,
                        elevation: 2,
                        pressedElevation: 3,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: valueMs,
                      max: maxMs,
                      onChangeStart: (v) => playback.beginScrub(
                        Duration(milliseconds: v.round()),
                      ),
                      onChanged: (v) => playback.updateScrub(
                        Duration(milliseconds: v.round()),
                      ),
                      onChangeEnd: (_) => playback.endScrub(),
                    ),
                  ),
                ),
                Text(Fmt.duration(total), style: timeStyle),
                const SizedBox(width: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The scrubber's times sit on the frame rather than on a panel, so they carry
/// a soft shadow to stay readable over a bright scene.
List<Shadow> _readableOnVideo(ThemeData theme) => [
  Shadow(
    color: theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.75),
    blurRadius: 8,
  ),
];

class _AbBanner extends StatelessWidget {
  const _AbBanner();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final (a, b) = context.select<PlaybackController, (Duration?, Duration?)>(
      (p) => (p.pointA, p.pointB),
    );
    if (a == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        radius: AppTheme.pillRadius,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                b == null
                    ? context.s.abPointSet(Fmt.duration(a))
                    : context.s.abLooping(Fmt.duration(a), Fmt.duration(b)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: playback.clearAb,
              style: TextButton.styleFrom(
                foregroundColor: context.muted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                context.s.clear,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ toggle panel
/// The six playback toggles in one floating glass panel, each with its label.
class _TogglePanel extends StatelessWidget {
  const _TogglePanel();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final (speed, shuffle, loopMode, abStarted, sleeping) = context
        .select<PlaybackController, (double, bool, LoopMode, bool, bool)>(
          (p) => (
            p.speed,
            p.shuffle,
            p.loopMode,
            p.pointA != null,
            p.sleepEndsAt != null,
          ),
        );
    final settings = playback.settings;

    final items = <Widget>[
      _Toggle(
        icon: Icons.lock_outline_rounded,
        label: context.s.lock,
        onTap: () {
          Haptics.light();
          playback.toggleLock();
        },
      ),
      _Toggle(
        icon: Icons.speed_rounded,
        label: Fmt.speed(speed),
        active: speed != 1.0,
        onTap: () => showSpeedSheet(context),
      ),
      if (settings.abRepeatEnabled)
        _Toggle(
          icon: Icons.repeat_one_on_rounded,
          label: context.s.abRepeat,
          active: abStarted,
          onTap: () {
            Haptics.light();
            playback.markAbPoint();
          },
        ),
      _Toggle(
        icon: Icons.shuffle_rounded,
        label: context.s.shuffle,
        active: shuffle,
        onTap: () {
          Haptics.light();
          playback.toggleShuffle();
        },
      ),
      _Toggle(
        icon: switch (loopMode) {
          LoopMode.one => Icons.repeat_one_rounded,
          _ => Icons.repeat_rounded,
        },
        label: switch (loopMode) {
          LoopMode.off => context.s.repeat,
          LoopMode.all => context.s.repeatAll,
          LoopMode.one => context.s.repeatOne,
        },
        active: loopMode != LoopMode.off,
        onTap: () {
          Haptics.light();
          playback.cycleLoopMode();
        },
      ),
      if (settings.sleepTimerEnabled)
        _Toggle(
          icon: Icons.bedtime_outlined,
          label: context.s.sleep,
          active: sleeping,
          onTap: () => showSleepTimerSheet(context),
        ),
    ];

    return GlassPanel(
      radius: BorderRadius.circular(26),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1) const _ToggleDivider(),
          ],
        ],
      ),
    );
  }
}

class _ToggleDivider extends StatelessWidget {
  const _ToggleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : context.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusThumb),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? theme.colorScheme.primary : context.muted,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppTheme.pageMargin),
          child: GlassCircleButton(
            icon: Icons.lock_rounded,
            size: 52,
            iconSize: 23,
            tooltip: context.s.lock,
            iconColor: Theme.of(context).colorScheme.primary,
            onTap: () {
              Haptics.light();
              playback.toggleLock();
            },
          ),
        ),
      ),
    );
  }
}
