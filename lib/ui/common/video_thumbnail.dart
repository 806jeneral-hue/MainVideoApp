import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/video.dart';
import '../../data/services/thumbnail_service.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

/// Auto-generated thumbnail with the duration badge and, when the video has
/// been started before, a thin resume bar along the bottom.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.video,
    this.width = 148,
    this.height = 88,
    this.progress = 0,
    this.showDuration = true,
    this.showPlayGlyph = false,
    this.borderRadius,
  });

  final Video video;
  final double width;
  final double height;

  /// 0..1 resume progress; 0 hides the bar.
  final double progress;
  final bool showDuration;

  /// A small floating play button in the middle — for the library cards,
  /// where the thumbnail is the thing you tap to watch.
  final bool showPlayGlyph;
  final BorderRadius? borderRadius;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;

  int get _requestWidth => (widget.width * 2).round().clamp(120, 640);
  int get _requestHeight => (widget.height * 2).round().clamp(120, 640);

  @override
  void initState() {
    super.initState();
    // A cache hit is filled in before the first build, so a recycled tile
    // scrolling back into view paints its thumbnail immediately.
    final cached = ThumbnailService.peek(
      widget.video.assetId,
      _requestWidth,
      _requestHeight,
    );
    if (cached != null) {
      _bytes = cached;
      _loading = false;
      return;
    }
    _resolve();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.assetId == widget.video.assetId) return;

    final cached = ThumbnailService.peek(
      widget.video.assetId,
      _requestWidth,
      _requestHeight,
    );
    setState(() {
      _bytes = cached;
      _loading = cached == null;
    });
    if (cached == null) _resolve();
  }

  Future<void> _resolve() async {
    final bytes = await ThumbnailService.load(
      widget.video.assetId,
      width: _requestWidth,
      height: _requestHeight,
    );
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.borderRadius ?? AppTheme.thumbRadius;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: _bytes != null
                    ? Image.memory(
                        _bytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: _requestWidth,
                        filterQuality: FilterQuality.low,
                      )
                    : Center(
                        child: _loading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.muted,
                                ),
                              )
                            : Icon(
                                AppIcons.movie_outlined,
                                color: context.muted.withValues(alpha: 0.7),
                              ),
                      ),
              ),
              if (widget.showPlayGlyph) const Center(child: _PlayGlyph()),
              if (widget.showDuration && widget.video.durationMs > 0)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: _DurationBadge(
                    label: Fmt.durationMs(widget.video.durationMs),
                  ),
                ),
              if (widget.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: widget.progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.accentOnDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Duration as a small smoked-glass pill on the thumbnail.
///
/// No live blur: a blur per thumbnail would be paid on every scroll frame, and
/// a translucent dark fill with a light edge reads the same at this size.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: AppTheme.pillRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Frosted play button floating in the middle of a card thumbnail.
class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: const AppIcon(
        AppIcons.play_arrow_rounded,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}
