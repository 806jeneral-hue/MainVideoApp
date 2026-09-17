import 'package:flutter/material.dart';

/// The app's own soft, filled navigation icons: a pillowy house and folder
/// with a small smile cut out of them, and a rounded heart and music note.
///
/// Drawn from path data on a 24 x 24 grid, so they stay crisp at any size and
/// need no icon package.
enum NavGlyphKind { home, folder, heart, music }

class NavGlyph extends StatelessWidget {
  const NavGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.size = 28,
  });

  final NavGlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(_paths[kind]!, color),
    );
  }

  static final Map<NavGlyphKind, Path> _paths = {
    NavGlyphKind.home: _parse(
      'M12 2.6c1.1 0 1.9.5 2.8 1.2 1.8 1.4 3.8 3 5.2 4.3 1 .9 1.5 2 1.5 3.3'
      'v5.2c0 2.7-2.1 4.8-4.8 4.8H7.3c-2.7 0-4.8-2.1-4.8-4.8v-5.2'
      'c0-1.3.5-2.4 1.5-3.3 1.4-1.3 3.4-2.9 5.2-4.3.9-.7 1.7-1.2 2.8-1.2z'
      'M8.6 13.6c0-.5.4-.8.9-.7.7.2 1.6.3 2.5.3s1.8-.1 2.5-.3'
      'c.5-.1.9.2.9.7 0 1.9-1.5 3.4-3.4 3.4s-3.4-1.5-3.4-3.4z',
    ),
    NavGlyphKind.folder: _parse(
      'M6.7 3.3h2.5c1 0 1.9.4 2.6 1.1l.6.6c.4.4 1 .7 1.6.7h3.3'
      'c2.5 0 4.2 1.8 4.2 4.2v6.2c0 2.5-1.9 4.5-4.4 4.5H6.9'
      'c-2.5 0-4.4-2-4.4-4.5V7.5c0-2.3 1.9-4.2 4.2-4.2z'
      'M8.8 13.4c0-.5.4-.8.9-.7.7.2 1.5.3 2.3.3s1.6-.1 2.3-.3'
      'c.5-.1.9.2.9.7 0 1.8-1.4 3.2-3.2 3.2s-3.2-1.4-3.2-3.2z',
    ),
    NavGlyphKind.heart: _parse(
      'M12 20.8c-.5 0-.9-.2-1.3-.5C5.8 16.4 2.6 13.4 2.6 9.3'
      'c0-2.9 2.2-5.1 5-5.1 1.8 0 3.3.9 4.4 2.3 1.1-1.4 2.6-2.3 4.4-2.3'
      'c2.8 0 5 2.2 5 5.1 0 4.1-3.2 7.1-8.1 11-.4.3-.8.5-1.3.5z',
    ),
    NavGlyphKind.music: _parse(
      'M18.1 2.9c1.2-.3 2.3.6 2.3 1.8v10.5a3.7 3.7 0 1 1-2.4-3.5V8.4'
      'l-7.4 1.9v7.3a3.7 3.7 0 1 1-2.4-3.5V7.4c0-1.1.7-2 1.8-2.3z',
    ),
  };

  /// A small reader for the SVG path commands these icons use: M L H V C S A
  /// Z, absolute and relative.
  static Path _parse(String data) {
    final path = Path()..fillType = PathFillType.evenOdd;
    final tokens = RegExp(
      r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?',
    ).allMatches(data).map((m) => m.group(0)!).toList();

    var i = 0;
    var command = '';
    var x = 0.0, y = 0.0;
    var startX = 0.0, startY = 0.0;
    var lastCtrlX = 0.0, lastCtrlY = 0.0;
    var lastWasCubic = false;

    bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      if (isCommand(tokens[i])) command = tokens[i++];
      final relative = command == command.toLowerCase();
      final dx = relative ? x : 0.0;
      final dy = relative ? y : 0.0;

      switch (command.toUpperCase()) {
        case 'M':
          x = next() + dx;
          y = next() + dy;
          path.moveTo(x, y);
          startX = x;
          startY = y;
          // Further pairs after a move are lines.
          command = relative ? 'l' : 'L';
          lastWasCubic = false;
        case 'L':
          x = next() + dx;
          y = next() + dy;
          path.lineTo(x, y);
          lastWasCubic = false;
        case 'H':
          x = next() + dx;
          path.lineTo(x, y);
          lastWasCubic = false;
        case 'V':
          y = next() + dy;
          path.lineTo(x, y);
          lastWasCubic = false;
        case 'C':
          final x1 = next() + dx, y1 = next() + dy;
          final x2 = next() + dx, y2 = next() + dy;
          x = next() + dx;
          y = next() + dy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrlX = x2;
          lastCtrlY = y2;
          lastWasCubic = true;
        case 'S':
          final x1 = lastWasCubic ? 2 * x - lastCtrlX : x;
          final y1 = lastWasCubic ? 2 * y - lastCtrlY : y;
          final x2 = next() + dx, y2 = next() + dy;
          x = next() + dx;
          y = next() + dy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrlX = x2;
          lastCtrlY = y2;
          lastWasCubic = true;
        case 'A':
          final rx = next(), ry = next();
          final rotation = next();
          final largeArc = next() != 0;
          final clockwise = next() != 0;
          x = next() + dx;
          y = next() + dy;
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: clockwise,
          );
          lastWasCubic = false;
        case 'Z':
          path.close();
          x = startX;
          y = startY;
          lastWasCubic = false;
        default:
          i++;
      }
    }
    return path;
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.path != path;
}
