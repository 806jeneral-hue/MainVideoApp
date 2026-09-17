import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/song.dart';
import '../../../data/services/album_art_service.dart';
import '../../../core/theme/app_icons.dart';

/// A song's album cover, or a soft tinted tile with a note when it has none.
///
/// Covers come from [AlbumArtService]: one read per album, cached in memory
/// and on disk, so a long list scrolls without asking the platform again.
class AlbumArt extends StatefulWidget {
  const AlbumArt({
    super.key,
    required this.song,
    required this.size,
    this.radius,
    this.decodeSize,
  });

  final Song song;
  final double size;
  final BorderRadius? radius;

  /// Pixel size asked of the platform; defaults to twice [size], which
  /// covers any screen density without decoding the full picture.
  final int? decodeSize;

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  Uint8List? _bytes;
  bool _loaded = false;

  int get _pixels => widget.decodeSize ?? _bucket((widget.size * 2).round());

  /// Rounds up to a few fixed sizes so rows, grids and the player share
  /// cached covers instead of each decoding its own.
  static int _bucket(int pixels) {
    if (pixels <= 160) return 160;
    if (pixels <= 320) return 320;
    return 640;
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.albumKey != widget.song.albumKey ||
        oldWidget.decodeSize != widget.decodeSize) {
      _resolve();
    }
  }

  void _resolve() {
    final cached = AlbumArtService.peek(widget.song, _pixels);
    if (cached != null) {
      _bytes = cached.$1;
      _loaded = true;
      return;
    }
    _loaded = false;
    final song = widget.song;
    AlbumArtService.load(song, size: _pixels).then((bytes) {
      if (!mounted || widget.song.albumKey != song.albumKey) return;
      setState(() {
        _bytes = bytes;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.radius ?? AppTheme.thumbRadius;
    final bytes = _bytes;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    key: ValueKey(widget.song.albumKey),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    width: widget.size,
                    height: widget.size,
                  )
                : _Placeholder(
                    key: ValueKey('empty-$_loaded'),
                    size: widget.size,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          AppIcons.music_note_rounded,
          size: size * 0.42,
          color: accent.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
