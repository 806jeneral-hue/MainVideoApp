import 'package:flutter/widgets.dart';

/// The player's own shortcut icons, drawn in the app's soft style: thick
/// strokes with round ends, rounded corners, and filled shapes where a solid
/// block reads better — the lock's body, the floating window.
enum PlayerGlyphKind {
  lock,
  pictureInPicture,
  displayMode,
  rotate,
  fastForward,
}

class PlayerGlyph extends StatelessWidget {
  const PlayerGlyph(
    this.kind, {
    super.key,
    required this.color,
    this.size = 22,
  });

  final PlayerGlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PlayerGlyphPainter(kind, color),
  );
}

class _PlayerGlyphPainter extends CustomPainter {
  const _PlayerGlyphPainter(this.kind, this.color);

  final PlayerGlyphKind kind;
  final Color color;

  Paint _stroke(double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint get _fill => Paint()
    ..color = color
    ..isAntiAlias = true;

  static RRect _screen() => RRect.fromRectAndRadius(
    const Rect.fromLTWH(2.8, 4.6, 18.4, 14.8),
    const Radius.circular(3.8),
  );

  static Path _polyline(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    switch (kind) {
      case PlayerGlyphKind.lock:
        // An open padlock: the shackle swung up, a solid body, a keyhole.
        canvas.drawPath(
          Path()
            ..moveTo(8, 11)
            ..lineTo(8, 8.2)
            ..arcToPoint(
              const Offset(15.7, 6.7),
              radius: const Radius.circular(4),
            ),
          _stroke(2.7),
        );
        canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.6, 10.4, 14.8, 10.6),
            const Radius.circular(3.4),
          ),
          _fill,
        );
        canvas.drawCircle(
          const Offset(12, 15.3),
          1.7,
          Paint()..blendMode = BlendMode.clear,
        );
        canvas.restore();

      case PlayerGlyphKind.pictureInPicture:
        canvas.drawRRect(_screen(), _stroke(2.5));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(11.4, 10.6, 6.8, 5.8),
            const Radius.circular(1.9),
          ),
          _fill,
        );

      case PlayerGlyphKind.displayMode:
        canvas.drawRRect(_screen(), _stroke(2.5));
        final chevrons = _stroke(2.3);
        canvas.drawPath(
          _polyline(const [
            Offset(9.2, 9.3),
            Offset(6.6, 12),
            Offset(9.2, 14.7),
          ]),
          chevrons,
        );
        canvas.drawPath(
          _polyline(const [
            Offset(14.8, 9.3),
            Offset(17.4, 12),
            Offset(14.8, 14.7),
          ]),
          chevrons,
        );

      case PlayerGlyphKind.rotate:
        // A phone with a curved arrow turning round its side.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.2, 3, 10.4, 18),
            const Radius.circular(3.2),
          ),
          _stroke(2.5),
        );
        final arrow = _stroke(2.2);
        canvas.drawPath(
          Path()
            ..moveTo(18.2, 8.4)
            ..arcToPoint(
              const Offset(18.2, 15.6),
              radius: const Radius.circular(6.2),
            ),
          arrow,
        );
        canvas.drawPath(
          _polyline(const [
            Offset(16.4, 15.2),
            Offset(18.3, 15.9),
            Offset(19, 14),
          ]),
          arrow,
        );

      case PlayerGlyphKind.fastForward:
        // Two plump, rounded triangles, sat on the middle line.
        canvas.translate(-0.4, 0.8);
        for (final dx in const [0.0, 8.6]) {
          canvas.drawPath(
            Path()
              ..moveTo(3.4 + dx, 6.9)
              ..cubicTo(3.4 + dx, 5.6, 4.8 + dx, 4.8, 5.9 + dx, 5.5)
              ..lineTo(12.3 + dx, 9.8)
              ..cubicTo(13.3 + dx, 10.5, 13.3 + dx, 11.9, 12.3 + dx, 12.6)
              ..lineTo(5.9 + dx, 16.9)
              ..cubicTo(4.8 + dx, 17.6, 3.4 + dx, 16.8, 3.4 + dx, 15.5)
              ..close(),
            _fill,
          );
        }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlayerGlyphPainter old) =>
      old.kind != kind || old.color != color;
}
