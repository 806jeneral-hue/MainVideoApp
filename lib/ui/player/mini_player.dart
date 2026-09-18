import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/playable.dart';
import '../../data/models/song.dart';
import '../../data/models/video.dart';
import '../../state/playback_controller.dart';
import '../common/glass.dart';
import '../common/video_thumbnail.dart';
import '../music/now_playing_page.dart';
import '../music/widgets/album_art.dart';
import '../shell/app_bottom_nav.dart';
import 'player_page.dart';
import '../../core/theme/app_icons.dart';
import '../common/app_icon.dart';

/// The bar that appears at the bottom of the screen while a video is playing
/// and the full-screen player is not open — above the navigation bar on the
/// main tabs, and at the bottom of a folder or playlist opened from them.
///
/// It keeps the same session alive, so browsing other folders never stops
/// playback — and tapping it goes straight back to full screen.
///
/// While the full-screen player is open the bar keeps its place but is not
/// drawn: the player draws its own copy as it shrinks, and hands over to this
/// one only once it has landed exactly on top of it.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, this.aboveNavigation = true});

  /// Whether the bar sits above the main navigation bar or at the very bottom
  /// of the screen — where the player has to shrink to.
  final bool aboveNavigation;

  static const double height = 72;
  static const double thumbnailWidth = 60;
  static const double thumbnailHeight = 38;
  static const double thumbnailRadius = 10;

  // The layout below is built from these, so the player's target rectangles
  // and the real bar cannot drift apart.
  static const double _bottomGap = AppTheme.space8;
  static const double _thumbnailStart = 10;
  static const double _rowTop = 8;
  static const double _rowBottom = 2;
  static const double _progressHeight = 3;
  static const double _progressBottom = 8;

  /// Where the card sits on a screen of [screen] size.
  static Rect cardRect(
    Size screen, {
    required double bottomInset,
    required bool aboveNavigation,
  }) {
    final bottom =
        screen.height -
        bottomInset -
        (aboveNavigation ? AppBottomNav.outerHeight : 0) -
        _bottomGap;
    return Rect.fromLTRB(
      AppTheme.barMargin,
      bottom - height,
      screen.width - AppTheme.barMargin,
      bottom,
    );
  }

  /// Where the thumbnail sits inside [card].
  static Rect thumbnailRect(Rect card, TextDirection direction) {
    final rowHeight =
        height - _progressHeight - _progressBottom - _rowTop - _rowBottom;
    final top = card.top + _rowTop + (rowHeight - thumbnailHeight) / 2;
    final left = direction == TextDirection.ltr
        ? card.left + _thumbnailStart
        : card.right - _thumbnailStart - thumbnailWidth;
    return Rect.fromLTWH(left, top, thumbnailWidth, thumbnailHeight);
  }

  @override
  Widget build(BuildContext context) {
    final (visible, fullscreen) = context
        .select<PlaybackController, (bool, bool)>(
          (p) => (p.hasSession, p.isFullscreen),
        );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: visible
          ? IgnorePointer(
              ignoring: fullscreen,
              child: Opacity(
                opacity: fullscreen ? 0 : 1,
                child: _MiniPlayerBar(aboveNavigation: aboveNavigation),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({required this.aboveNavigation});

  final bool aboveNavigation;

  @override
  Widget build(BuildContext context) {
    // A song opens the music player; a video grows back into full screen.
    void open() => context.read<PlaybackController>().isAudio
        ? openNowPlaying(context)
        : openPlayerFullscreen(context, aboveNavigation: aboveNavigation);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.barMargin,
        0,
        AppTheme.barMargin,
        MiniPlayer._bottomGap,
      ),
      child: _SwipeUpToOpen(
        onOpen: open,
        child: FrostedBar(
          radius: AppTheme.cardRadius,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: open,
              borderRadius: AppTheme.cardRadius,
              child: const MiniPlayerContent(),
            ),
          ),
        ),
      ),
    );
  }
}

/// What is inside the mini player card: thumbnail, title, the buttons and
/// the progress track.
///
/// The full-screen player shows the same content while it shrinks, so what
/// it turns into is exactly this — with the live video standing in for the
/// thumbnail.
class MiniPlayerContent extends StatelessWidget {
  const MiniPlayerContent({super.key, this.showThumbnail = true});

  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    // Only the things that change between videos are watched here. Play state
    // and position come straight from the player below, so the button can
    // never disagree with what the video is actually doing.
    final (item, queueTitle, controller) = context
        .select<
          PlaybackController,
          (Playable?, String, VideoPlayerController?)
        >((p) => (p.currentOrNull, p.queueTitle, p.player));

    if (item == null) return const SizedBox(height: MiniPlayer.height);
    final radius = BorderRadius.circular(MiniPlayer.thumbnailRadius);
    final theme = Theme.of(context);

    return SizedBox(
      height: MiniPlayer.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              // Balances the progress track below. Directional, so the
              // thumbnail keeps the same inset in Arabic.
              padding: const EdgeInsetsDirectional.fromSTEB(
                MiniPlayer._thumbnailStart,
                MiniPlayer._rowTop,
                2,
                MiniPlayer._rowBottom,
              ),
              child: Row(
                children: [
                  // Keyed by the video so switching tracks rebuilds the
                  // thumbnail instead of holding the previous frame while the
                  // new one decodes.
                  Opacity(
                    opacity: showThumbnail ? 1 : 0,
                    child: switch (item) {
                      // A song shows its cover, square.
                      Song song => AlbumArt(
                        key: ValueKey(song.id),
                        song: song,
                        size: MiniPlayer.thumbnailHeight,
                        radius: radius,
                      ),
                      Video video => VideoThumbnail(
                        key: ValueKey(video.id),
                        video: video,
                        width: MiniPlayer.thumbnailWidth,
                        height: MiniPlayer.thumbnailHeight,
                        borderRadius: radius,
                        showDuration: false,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          switch (item) {
                            Song(:final artist) =>
                              artist.isEmpty ? context.s.unknownArtist : artist,
                            _ =>
                              queueTitle.isEmpty ? item.subtitle : queueTitle,
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _PreviousButton(),
                  _PlayPauseButton(controller: controller),
                  const _NextButton(),
                  _MiniButton(
                    icon: AppIcons.cancel_rounded,
                    tooltip: context.s.done,
                    onPressed: context.read<PlaybackController>().stop,
                  ),
                ],
              ),
            ),
          ),
          // Progress runs along the bottom, inside the card, as a slim rounded
          // track rather than a line cut into its edge.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MiniPlayer._progressBottom,
            ),
            child: ClipRRect(
              borderRadius: AppTheme.pillRadius,
              child: _Progress(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact icon button — four of them have to share the bar with the
/// thumbnail and the title, so they are tighter than a stock IconButton.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      color: color,
      icon: AppIcon(icon),
    );
  }
}

/// Always available: with nothing before it, it restarts the current video —
/// the same as the button in the full-screen player.
class _PreviousButton extends StatelessWidget {
  const _PreviousButton();

  @override
  Widget build(BuildContext context) {
    return _MiniButton(
      icon: AppIcons.skip_previous_rounded,
      tooltip: context.s.previous,
      onPressed: context.read<PlaybackController>().previous,
    );
  }
}

/// Play/pause driven by the player's own value, not by a notification.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    if (controller == null) {
      return const SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller!,
      builder: (context, value, _) => _MiniButton(
        icon: value.isPlaying
            ? AppIcons.pause_rounded
            : AppIcons.play_arrow_rounded,
        tooltip: value.isPlaying ? context.s.pause : context.s.play,
        onPressed: playback.togglePlay,
        color: context.accent,
        size: 25,
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton();

  @override
  Widget build(BuildContext context) {
    final hasNext = context.select<PlaybackController, bool>((p) => p.hasNext);
    return _MiniButton(
      icon: AppIcons.skip_next_rounded,
      tooltip: context.s.next,
      onPressed: hasNext ? context.read<PlaybackController>().next : null,
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.colorScheme.onSurface.withValues(alpha: 0.12);

    if (controller == null) {
      return LinearProgressIndicator(
        value: 0,
        minHeight: MiniPlayer._progressHeight,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation<Color>(context.accent),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller!,
      builder: (context, value, _) {
        final total = value.duration.inMilliseconds;
        final progress = total <= 0
            ? 0.0
            : (value.position.inMilliseconds / total).clamp(0.0, 1.0);
        return LinearProgressIndicator(
          value: progress,
          minHeight: MiniPlayer._progressHeight,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(context.accent),
        );
      },
    );
  }
}

/// Swiping the mini player up opens the full-screen player.
///
/// The card lifts a little with the finger so the gesture visibly does
/// something, and it opens as soon as the swipe is far or fast enough — no
/// need to let go first. Taps and the buttons inside are unaffected.
class _SwipeUpToOpen extends StatefulWidget {
  const _SwipeUpToOpen({required this.onOpen, required this.child});

  final VoidCallback onOpen;
  final Widget child;

  @override
  State<_SwipeUpToOpen> createState() => _SwipeUpToOpenState();
}

class _SwipeUpToOpenState extends State<_SwipeUpToOpen> {
  /// Upward travel that opens the player.
  static const double _openDistance = 36;

  /// An upward flick opens it even if it did not travel that far.
  static const double _openVelocity = 400;

  final ValueNotifier<double> _lift = ValueNotifier<double>(0);
  double _travel = 0;
  bool _opened = false;

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  void _open() {
    if (_opened) return;
    _opened = true;
    _lift.value = 0;
    Haptics.light();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (_) {
        _travel = 0;
        _opened = false;
      },
      onVerticalDragUpdate: (details) {
        if (_opened) return;
        _travel += details.delta.dy;
        final up = (-_travel).clamp(0.0, _openDistance);
        _lift.value = up * 0.5;
        if (up >= _openDistance) _open();
      },
      onVerticalDragEnd: (details) {
        if (!_opened && details.velocity.pixelsPerSecond.dy < -_openVelocity) {
          _open();
        }
        _lift.value = 0;
      },
      onVerticalDragCancel: () => _lift.value = 0,
      child: ValueListenableBuilder<double>(
        valueListenable: _lift,
        child: widget.child,
        builder: (context, lift, child) =>
            Transform.translate(offset: Offset(0, -lift), child: child),
      ),
    );
  }
}
