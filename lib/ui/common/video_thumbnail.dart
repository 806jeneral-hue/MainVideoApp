import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/video.dart';
import '../../data/services/thumbnail_service.dart';

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
    this.borderRadius,
  });

  final Video video;
  final double width;
  final double height;

  /// 0..1 resume progress; 0 hides the bar.
  final double progress;
  final bool showDuration;
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
                                Icons.movie_outlined,
                                color: context.muted.withValues(alpha: 0.7),
                              ),
                      ),
              ),
              if (widget.showDuration && widget.video.durationMs > 0)
                Positioned(
                  left: 7,
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

/// Dark pill with a small play glyph, sitting on the thumbnail.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: AppTheme.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
