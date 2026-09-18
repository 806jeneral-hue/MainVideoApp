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
import '../../common/glass.dart';
import 'playback_sheets.dart';
import 'player_glyphs.dart';
import '../../../core/theme/app_icons.dart';
import '../../../state/bookmark_controller.dart';
import '../../../data/models/bookmark.dart';

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
        padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
        child: Column(
          children: [
            SizedBox(height: AppTheme.space8),
            _TopBar(),
            Expanded(child: Center(child: _Transport())),
            _AbBanner(),
            _SeekBar(),
            SizedBox(height: 10),
            _Shortcuts(),
            SizedBox(height: AppTheme.space12),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- top bar
/// One row: minimise, what is playing right beside it, then the actions pill
/// with everything else behind its More button.
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
    // The player is always black behind the video, so its title is light in
    // both themes.
    final shadows = _readableOnVideo();

    return Row(
      children: [
        // Chevron down rather than a cross: this minimises into the mini
        // player, it does not stop the video.
        GlassCircleButton(
          icon: AppIcons.keyboard_arrow_down_rounded,
          size: 46,
          iconSize: 30,
          tooltip: context.s.minimise,
          // Shrinks onto the mini player the same way the swipe does.
          onTap: () => context.read<PlayerMorph>().release(minimise: true),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: shadows,
                ),
              ),
              if (queueTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$queueTitle  ·  $index / $total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                      shadows: shadows,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        const _SleepChip(),
        _TopActions(playback: playback),
      ],
    );
  }
}

/// The queue and the More menu, in one glass pill beside the title. Lock,
/// picture-in-picture, display mode and rotation sit under the seek bar.
class _TopActions extends StatelessWidget {
  const _TopActions({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final optionsActive = context.select<PlaybackController, bool>(
      // Lit while anything behind More is changed from its default.
      (p) =>
          p.speed != 1.0 ||
          p.shuffle ||
          p.loopMode != LoopMode.off ||
          p.pointA != null ||
          p.sleepEndsAt != null,
    );

    return GlassPanel(
      radius: BorderRadius.circular(AppTheme.radiusSheet),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassBarIcon(
            icon: AppIcons.playlist_play_rounded,
            tooltip: context.s.playingQueue,
            onTap: () => showQueueSheet(context),
          ),
          GlassBarIcon(
            icon: AppIcons.more_vert_rounded,
            tooltip: context.s.more,
            active: optionsActive,
            onTap: () => showPlayerOptionsSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Lock, picture-in-picture, display mode and rotation, each in its own glass
/// circle along the bottom right, under the seek bar.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final theme = Theme.of(context);
    final (pipEnabled, forced, fit) = context
        .select<PlaybackController, (bool, Orientation?, VideoFit)>(
          (p) => (p.settings.pipEnabled, p.forcedOrientation, p.videoFit),
        );

    Widget button({
      required PlayerGlyphKind glyph,
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      bool active = false,
    }) => Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GlassCircleButton(
        icon: icon,
        size: 42,
        tooltip: tooltip,
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: PlayerGlyph(
          glyph,
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );

    // Laid out left to right in every language, like the transport above.
    return Align(
      alignment: Alignment.centerRight,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              glyph: PlayerGlyphKind.lock,
              icon: AppIcons.lock_rounded,
              tooltip: context.s.lock,
              onTap: playback.toggleLock,
            ),
            if (pipEnabled)
              button(
                glyph: PlayerGlyphKind.pictureInPicture,
                icon: AppIcons.picture_in_picture_alt_rounded,
                tooltip: context.s.pictureInPicture,
                onTap: playback.enterPip,
              ),
            button(
              glyph: PlayerGlyphKind.displayMode,
              icon: AppIcons.fit_screen_rounded,
              tooltip: '${context.s.displayMode} · ${fit.label(context.s)}',
              active: fit != VideoFit.fit,
              onTap: () {
                playback.cycleVideoFit();
                // Names the new mode, since the icon alone does not say it.
                playback.flashLabel(playback.videoFit.label(context.s));
              },
            ),
            button(
              glyph: PlayerGlyphKind.rotate,
              icon: AppIcons.screen_rotation_rounded,
              tooltip: switch (forced) {
                null => context.s.rotationAuto,
                Orientation.landscape => context.s.rotationLandscape,
                Orientation.portrait => context.s.rotationPortrait,
              },
              active: forced != null,
              onTap: playback.cycleOrientation,
            ),
          ],
        ),
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
            Icon(AppIcons.bedtime_rounded, size: 14, color: context.accent),
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
            icon: AppIcons.skip_previous_rounded,
            size: 60,
            iconSize: 32,
            tooltip: context.s.previous,
            // Always available: with nothing before it, it restarts the video.
            onTap: playback.previous,
          ),
          const SizedBox(width: AppTheme.space32),
          const _PlayPauseButton(),
          const SizedBox(width: AppTheme.space32),
          GlassCircleButton(
            icon: AppIcons.skip_next_rounded,
            size: 60,
            iconSize: 32,
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
        icon: AppIcons.play_arrow_rounded,
        size: 84,
        tooltip: context.s.play,
        onTap: null,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: theme.colorScheme.onSurface,
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
              ? AppIcons.pause_rounded
              : AppIcons.play_arrow_rounded,
          size: 84,
          iconSize: 46,
          tooltip: value.isPlaying ? context.s.pause : context.s.play,
          iconColor: theme.colorScheme.onSurface,
          onTap: playback.togglePlay,
          child: buffering
              ? SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: theme.colorScheme.onSurface,
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

    if (controller == null) return const SizedBox(height: 52);

    final timeStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // The glass is built once, outside the builders: only the row inside it
    // changes as the video plays.
    return GlassPanel(
      radius: AppTheme.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ValueListenableBuilder<VideoPlayerValue>(
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

            // Elapsed on the left, time remaining on the right.
            final remaining = total - position;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  const SizedBox(width: 6),
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Slider(
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
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _MarksOnTrack(totalMs: maxMs),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '-${Fmt.duration(remaining.isNegative ? Duration.zero : remaining)}',
                    style: timeStyle,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The saved moments of this video, as small dots on the seek bar, and the
/// list's stop mark, as a taller accent tick, when it is on this video.
class _MarksOnTrack extends StatelessWidget {
  const _MarksOnTrack({required this.totalMs});

  final double totalMs;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final id = context.select<PlaybackController, String?>(
      (p) => p.currentOrNull?.id,
    );
    if (id == null || totalMs <= 1) return const SizedBox.shrink();
    final moments = context.select<BookmarkController, List<Moment>>(
      (b) => b.momentsFor(id),
    );
    final stop = context.select<BookmarkController, int?>((b) {
      final marker = b.markerFor(playback.collection);
      return marker?.videoId == id ? marker!.positionMs : null;
    });
    if (moments.isEmpty && stop == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return CustomPaint(
      painter: _MarksPainter(
        fractions: [for (final m in moments) m.ms / totalMs],
        stop: stop == null ? null : stop / totalMs,
        dot: theme.colorScheme.onSurface,
        accent: theme.colorScheme.primary,
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  const _MarksPainter({
    required this.fractions,
    required this.stop,
    required this.dot,
    required this.accent,
  });

  final List<double> fractions;
  final double? stop;
  final Color dot;
  final Color accent;

  /// The slider's track is inset by its overlay radius on both sides.
  static const double _inset = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - _inset * 2;
    if (width <= 0) return;
    final y = size.height / 2;
    final ring = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final fill = Paint()..color = dot;
    for (final f in fractions) {
      final x = _inset + width * f.clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), 3.4, ring);
      canvas.drawCircle(Offset(x, y), 2.4, fill);
    }
    final s = stop;
    if (s != null) {
      final x = _inset + width * s.clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 4, height: 14),
          const Radius.circular(2),
        ),
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.stop != stop ||
      old.dot != dot ||
      old.accent != accent ||
      old.fractions.length != fractions.length ||
      !Iterable<int>.generate(
        fractions.length,
      ).every((i) => old.fractions[i] == fractions[i]);
}

/// Text that sits straight on the frame carries a soft dark shadow, so it stays
/// readable over a bright scene.
List<Shadow> _readableOnVideo() => [
  Shadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 8),
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
            icon: AppIcons.lock_rounded,
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
