import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/video.dart';
import '../../state/playback_controller.dart';
import '../common/video_thumbnail.dart';
import 'player_page.dart';

/// The bar that appears above the bottom navigation while a video is playing
/// and the full-screen player is not open.
///
/// It keeps the same session alive, so browsing other folders never stops
/// playback — and tapping it goes straight back to full screen.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<PlaybackController, bool>(
      (p) => p.showMiniPlayer,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: visible ? const _MiniPlayerBar() : const SizedBox.shrink(),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context) {
    // Only the things that change between videos are watched here. Play state
    // and position come straight from the player below, so the button can
    // never disagree with what the video is actually doing.
    final (video, queueTitle, controller) = context
        .select<PlaybackController, (Video?, String, VideoPlayerController?)>(
          (p) => (p.currentOrNull, p.queueTitle, p.player),
        );

    if (video == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppTheme.cardRadius,
          boxShadow: context.floatingShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => openPlayerFullscreen(context),
            borderRadius: AppTheme.cardRadius,
            child: SizedBox(
              height: MiniPlayer.height,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusCard),
                    ),
                    child: _Progress(controller: controller),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 2),
                      child: Row(
                        children: [
                          // Keyed by the video so switching tracks rebuilds
                          // the thumbnail instead of holding the previous
                          // frame while the new one decodes.
                          VideoThumbnail(
                            key: ValueKey(video.id),
                            video: video,
                            width: 58,
                            height: 34,
                            showDuration: false,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  queueTitle.isEmpty
                                      ? video.folderName
                                      : queueTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _PreviousButton(),
                          _PlayPauseButton(controller: controller),
                          const _NextButton(),
                          _MiniButton(
                            icon: Icons.close_rounded,
                            tooltip: context.s.done,
                            onPressed: context.read<PlaybackController>().stop,
                          ),
                        ],
                      ),
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
      icon: Icon(icon),
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
      icon: Icons.skip_previous_rounded,
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
        icon: value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
      icon: Icons.skip_next_rounded,
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
        minHeight: 2,
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
          minHeight: 2,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(context.accent),
        );
      },
    );
  }
}
