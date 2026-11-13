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
import '../../../state/settings_controller.dart';
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
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
        child: isSunset
            ? _buildSunsetLayout(context)
            : _buildClassicLayout(context),
      ),
    );
  }

  /// Glass / Solid: classic layout matching the original design.
  /// - Portrait: [4 shortcuts left] + [SeekBar right] in one Row
  /// - Landscape: [4 shortcuts full row] above, [SeekBar full width] below
  Widget _buildClassicLayout(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        return Column(
          children: [
            const SizedBox(height: AppTheme.space8),
            const _TopBar(),
            const Expanded(child: Center(child: _Transport())),
            const _AbBanner(),
            if (isPortrait) ...[
              // Portrait: shortcuts above, seekbar full width below
              const Align(
                alignment: Alignment.centerLeft,
                child: _Shortcuts(),
              ),
              const SizedBox(height: 6),
              const _SeekBar(),
            ] else ...[
              // Landscape: shortcuts on left, seekbar on right
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Shortcuts(),
                  SizedBox(width: 8),
                  Expanded(child: _SeekBar()),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.space12),
          ],
        );
      },
    );
  }

  /// Sunset: modern bare layout.
  /// - Top: [Minimize] | title | [Queue][More]
  /// - Bottom: shortcuts right-aligned above seekbar (portrait) / side-by-side (landscape)
  Widget _buildSunsetLayout(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        return Column(
          children: [
            const SizedBox(height: AppTheme.space8),
            const _TopBar(),
            const Expanded(child: Center(child: _Transport())),
            const _AbBanner(),
            if (isPortrait) ...[
              const Align(
                alignment: Alignment.centerRight,
                child: _Shortcuts(),
              ),
              const SizedBox(height: 6),
              const _SeekBar(),
            ] else ...[
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _SeekBar()),
                  SizedBox(width: 8),
                  _Shortcuts(),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.space12),
          ],
        );
      },
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
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;
    final (title, queueTitle, index, total) = context
        .select<PlaybackController, (String, String, int, int)>(
          (p) => (
            p.currentOrNull?.displayName ?? '',
            p.queueTitle,
            p.index + 1,
            p.queue.length,
          ),
        );
    final shadows = _readableOnVideo();

    if (isSunset) {
      // Sunset: [Minimize LEFT] | title | [Queue + More RIGHT]
      return Row(
        children: [
          _PlayerGlyphButton(
            icon: AppIcons.keyboard_arrow_down_rounded,
            size: 46,
            iconSize: 32,
            tooltip: context.s.minimise,
            onTap: () => context.read<PlayerMorph>().release(minimise: true),
          ),
          const SizedBox(width: AppTheme.space8),
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
                  Text(
                    '$queueTitle  ·  $index / $total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                      shadows: shadows,
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

    // Glass / Solid: [More + Queue LEFT] | title (right-aligned) | [Minimize RIGHT]
    return Row(
      children: [
        _TopActions(playback: playback),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: shadows,
                ),
              ),
              if (queueTitle.isNotEmpty)
                Text(
                  '$queueTitle  ·  $index / $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                    shadows: shadows,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        const _SleepChip(),
        GlassCircleButton(
          icon: AppIcons.keyboard_arrow_down_rounded,
          size: 46,
          iconSize: 30,
          tooltip: context.s.minimise,
          onTap: () => context.read<PlayerMorph>().release(minimise: true),
        ),
      ],
    );
  }
}

/// The queue and the More menu — in ONE glass pill for Glass/Solid, bare glyphs for Sunset.
class _TopActions extends StatelessWidget {
  const _TopActions({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;
    final optionsActive = context.select<PlaybackController, bool>(
      (p) =>
          p.speed != 1.0 ||
          p.shuffle ||
          p.loopMode != LoopMode.off ||
          p.pointA != null ||
          p.sleepEndsAt != null,
    );

    if (isSunset) {
      // Sunset: bare glyph buttons (More first, then Queue)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayerGlyphButton(
            icon: AppIcons.more_vert_rounded,
            size: 44,
            iconSize: 24,
            tooltip: context.s.more,
            iconColor: optionsActive ? theme.colorScheme.primary : Colors.white,
            onTap: () => showPlayerOptionsSheet(context),
          ),
          _PlayerGlyphButton(
            icon: AppIcons.playlist_play_rounded,
            size: 44,
            iconSize: 28,
            tooltip: context.s.playingQueue,
            onTap: () => showQueueSheet(context),
          ),
        ],
      );
    }

    // Glass / Solid: ONE glass pill with [⋮ More] and [☰ Queue] inside
    return GlassPanel(
      radius: AppTheme.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => showPlayerOptionsSheet(context),
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: context.s.more,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      AppIcons.more_vert_rounded,
                      size: 22,
                      color: optionsActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => showQueueSheet(context),
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: context.s.playingQueue,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      AppIcons.playlist_play_rounded,
                      size: 24,
                      color: theme.colorScheme.onSurface,
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

/// Lock, picture-in-picture, display mode and rotation.
/// Glass/Solid: glass circle buttons. Sunset: pure glyph buttons.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final theme = Theme.of(context);
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;
    final (pipEnabled, forced, fit) = context
        .select<PlaybackController, (bool, Orientation?, VideoFit)>(
          (p) => (p.settings.pipEnabled, p.forcedOrientation, p.videoFit),
        );

    // For Sunset: bare glyph button helper.
    Widget glyphBtn({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      bool active = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _PlayerGlyphButton(
        icon: icon,
        size: 44,
        iconSize: 26,
        tooltip: tooltip,
        iconColor: active ? theme.colorScheme.primary : Colors.white,
        onTap: () { Haptics.light(); onTap(); },
      ),
    );

    // For Glass/Solid: GlassCircleButton with PlayerGlyph icon inside.
    Widget glassBtn({
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
        iconColor: active ? theme.colorScheme.primary : null,
        onTap: () { Haptics.light(); onTap(); },
        child: PlayerGlyph(
          glyph,
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          size: 22,
        ),
      ),
    );

    // Laid out left to right in every language, like the transport above.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSunset)
            glyphBtn(
              icon: AppIcons.lock_rounded,
              tooltip: context.s.lock,
              onTap: playback.toggleLock,
            )
          else
            glassBtn(
              glyph: PlayerGlyphKind.lock,
              icon: AppIcons.lock_rounded,
              tooltip: context.s.lock,
              onTap: playback.toggleLock,
            ),
          if (pipEnabled)
            if (isSunset)
              glyphBtn(
                icon: AppIcons.picture_in_picture_alt_rounded,
                tooltip: context.s.pictureInPicture,
                onTap: playback.enterPip,
              )
            else
              glassBtn(
                glyph: PlayerGlyphKind.pictureInPicture,
                icon: AppIcons.picture_in_picture_alt_rounded,
                tooltip: context.s.pictureInPicture,
                onTap: playback.enterPip,
              ),
          if (isSunset)
            glyphBtn(
              icon: AppIcons.fit_screen_rounded,
              tooltip: '${context.s.displayMode} · ${fit.label(context.s)}',
              active: fit != VideoFit.fit,
              onTap: () {
                playback.cycleVideoFit();
                playback.flashLabel(playback.videoFit.label(context.s));
              },
            )
          else
            glassBtn(
              glyph: PlayerGlyphKind.displayMode,
              icon: AppIcons.fit_screen_rounded,
              tooltip: '${context.s.displayMode} · ${fit.label(context.s)}',
              active: fit != VideoFit.fit,
              onTap: () {
                playback.cycleVideoFit();
                playback.flashLabel(playback.videoFit.label(context.s));
              },
            ),
          if (isSunset)
            glyphBtn(
              icon: AppIcons.screen_rotation_rounded,
              tooltip: switch (forced) {
                null => context.s.rotationAuto,
                Orientation.landscape => context.s.rotationLandscape,
                Orientation.portrait => context.s.rotationPortrait,
              },
              active: forced != null,
              onTap: playback.cycleOrientation,
            )
          else
            glassBtn(
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
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;

    // Transport controls keep their conventional order even in Arabic, the
    // way every media player does — rewind on the left, forward on the right.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sunset: bare triangle glyph. Glass/Solid: original glass circle.
          if (isSunset)
            _PlayerGlyphButton(
              icon: null,
              size: 68,
              iconSize: 46,
              tooltip: context.s.previous,
              onTap: playback.previous,
              glyph: PlayerGlyphKind.skipPrevious,
            )
          else
            GlassCircleButton(
              icon: AppIcons.skip_previous_rounded,
              size: 60,
              iconSize: 32,
              tooltip: context.s.previous,
              onTap: playback.previous,
            ),
          const SizedBox(width: AppTheme.space32),
          const _PlayPauseButton(),
          const SizedBox(width: AppTheme.space32),
          if (isSunset)
            _PlayerGlyphButton(
              icon: null,
              size: 68,
              iconSize: 46,
              tooltip: context.s.next,
              onTap: hasNext ? playback.next : null,
              glyph: PlayerGlyphKind.skipNext,
            )
          else
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
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);

    if (controller == null) {
      // Loading state — glass circle with spinner for Glass/Solid, bare for Sunset.
      if (isSunset) {
        return SizedBox(
          width: 84,
          height: 84,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
      return GlassCircleButton(
        icon: AppIcons.play_arrow_rounded,
        size: 84,
        iconSize: 46,
        tooltip: context.s.play,
        onTap: null,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final buffering = value.isBuffering && !value.isPlaying;

        // Sunset: bare glyph buttons.
        if (isSunset) {
          if (buffering) {
            return SizedBox(
              width: 84,
              height: 84,
              child: Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          return _PlayerGlyphButton(
            icon: value.isPlaying
                ? AppIcons.pause_rounded
                : AppIcons.play_arrow_rounded,
            size: 84,
            iconSize: 64,
            tooltip: value.isPlaying ? context.s.pause : context.s.play,
            onTap: playback.togglePlay,
          );
        }

        // Glass / Solid: original GlassCircleButton.
        if (buffering) {
          return GlassCircleButton(
            icon: AppIcons.play_arrow_rounded,
            size: 84,
            iconSize: 46,
            tooltip: context.s.play,
            onTap: null,
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        }
        return GlassCircleButton(
          icon: value.isPlaying
              ? AppIcons.pause_rounded
              : AppIcons.play_arrow_rounded,
          size: 84,
          iconSize: 46,
          tooltip: value.isPlaying ? context.s.pause : context.s.play,
          iconColor: theme.colorScheme.onSurface,
          onTap: playback.togglePlay,
        );
      },
    );
  }
}

/// A pure borderless icon button with crisp drop shadow for clear contrast on video.
class _PlayerGlyphButton extends StatelessWidget {
  const _PlayerGlyphButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 48,
    this.iconSize = 28,
    this.iconColor,
    this.glyph,
  });

  final IconData? icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  /// When set, renders a custom [PlayerGlyph] instead of a Material icon.
  final PlayerGlyphKind? glyph;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.35);

    final child = glyph != null
        ? PlayerGlyph(glyph!, color: effectiveColor, size: iconSize)
        : Icon(icon, size: iconSize, color: effectiveColor);

    return PressScale(
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2,
          containedInkWell: false,
          highlightColor: Colors.transparent,
          splashColor: Colors.white24,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      ),
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
    final style = context.watch<SettingsController>().appStyle;
    final isSunset = style == AppStyle.sunset;
    final controller = context
        .select<PlaybackController, VideoPlayerController?>((p) => p.player);

    if (controller == null) return const SizedBox(height: 52);

    final timeStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.88),
      fontSize: 13,
      fontWeight: FontWeight.w600,
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
          final remaining = total - position;

          // ── Sunset theme: bare Column layout over the video ────────────────
          if (isSunset) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: dragging ? 5 : 4,
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.14),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Text(Fmt.duration(position), style: timeStyle),
                        const Spacer(),
                        Text(
                          '-${Fmt.duration(remaining.isNegative ? Duration.zero : remaining)}',
                          style: timeStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Glass & Solid themes: original GlassPanel + Row layout ─────────
          return GlassPanel(
            radius: AppTheme.pillRadius,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Directionality(
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
            ),
          );
        },
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
          child: _PlayerGlyphButton(
            icon: AppIcons.lock_rounded,
            size: 54,
            iconSize: 32,
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

