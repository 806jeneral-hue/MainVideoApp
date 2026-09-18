import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's own background, shown whenever no picture is chosen in Settings.
///
/// A deep night blue (or, in the light theme, a warm pearl) with soft amber
/// glows, a few blurred rounded play triangles drifting out of focus, and two
/// large curved sheets whose edges catch the light. Everything is painted from
/// code — nothing to load, crisp on any screen — and cached as one layer, so
/// the lists scrolling over it never repaint it.
class DefaultBackdrop extends StatelessWidget {
  const DefaultBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(isDark ? _Palette.dark : _Palette.light),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.glow,
    required this.glowStrength,
    required this.sheet,
    required this.edge,
    required this.cool,
  });

  final Color top;
  final Color middle;
  final Color bottom;

  /// The amber of the bokeh and triangles.
  final Color glow;
  final double glowStrength;

  /// The fill of the curved sheets, and the light running along their edges.
  final Color sheet;
  final Color edge;

  /// A faint cool glow that keeps the middle from going flat.
  final Color cool;

  static const dark = _Palette(
    top: Color(0xFF141A2B),
    middle: Color(0xFF10131F),
    bottom: Color(0xFF1B1310),
    glow: Color(0xFFE86A22),
    glowStrength: 1,
    sheet: Color(0xFFB9531C),
    edge: Color(0xFFFF9A4D),
    cool: Color(0xFF4A5B8C),
  );

  static const light = _Palette(
    top: Color(0xFFF3EEF1),
    middle: Color(0xFFEDEAF2),
    bottom: Color(0xFFF7EAE0),
    glow: Color(0xFFF08A4B),
    glowStrength: 0.62,
    sheet: Color(0xFFF6B58A),
    edge: Color(0xFFF28C4E),
    cool: Color(0xFFB9C4E6),
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.p);

  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & size;
    final unit = math.min(w, h);

    // Base wash, cool at the top warming towards the bottom.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.middle, p.bottom],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    _glow(canvas, Offset(w * 0.45, h * 0.42), unit * 0.9, p.cool, 0.18);

    // Out-of-focus amber lights.
    const bokeh = [
      (0.88, 0.03, 0.26, 0.50),
      (0.03, 0.35, 0.24, 0.62),
      (0.97, 0.50, 0.16, 0.28),
      (0.05, 0.73, 0.26, 0.55),
      (0.62, 0.66, 0.20, 0.30),
      (0.18, 0.90, 0.28, 0.70),
      (0.98, 0.82, 0.22, 0.34),
      (0.42, 0.24, 0.14, 0.14),
    ];
    for (final (x, y, r, a) in bokeh) {
      _glow(canvas, Offset(w * x, h * y), unit * r, p.glow, a * p.glowStrength);
    }

    // Blurred play triangles drifting in the depth.
    _triangle(
      canvas,
      Offset(w * 0.84, h * 0.28),
      unit * 0.36,
      0.40,
      unit * 0.02,
    );
    _triangle(
      canvas,
      Offset(w * 0.13, h * 0.585),
      unit * 0.22,
      0.46,
      unit * 0.012,
    );
    _triangle(
      canvas,
      Offset(w * 0.84, h * 0.84),
      unit * 0.28,
      0.30,
      unit * 0.03,
    );

    // Top-left sheet, bulging down into the page.
    final topSheet = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.56, 0)
      ..cubicTo(w * 0.42, h * 0.10, w * 0.20, h * 0.14, 0, h * 0.21)
      ..close();
    _sheet(
      canvas,
      topSheet,
      Path()
        ..moveTo(w * 0.56, 0)
        ..cubicTo(w * 0.42, h * 0.10, w * 0.20, h * 0.14, 0, h * 0.21),
      Rect.fromLTWH(0, 0, w * 0.6, h * 0.22),
      Alignment.topLeft,
    );
    // A fainter second line just inside the first.
    _edgeLine(
      canvas,
      Path()
        ..moveTo(w * 0.22, h * 0.13)
        ..cubicTo(w * 0.14, h * 0.20, w * 0.06, h * 0.24, 0, h * 0.34),
      0.35,
    );

    // Bottom-right sheet, sweeping up from the corner.
    final bottomEdge = Path()
      ..moveTo(w * 0.38, h)
      ..cubicTo(w * 0.52, h * 0.84, w * 0.78, h * 0.68, w, h * 0.59);
    _sheet(
      canvas,
      Path.from(bottomEdge)
        ..lineTo(w, h)
        ..close(),
      bottomEdge,
      Rect.fromLTWH(w * 0.38, h * 0.58, w * 0.62, h * 0.42),
      Alignment.bottomRight,
    );
    _edgeLine(
      canvas,
      Path()
        ..moveTo(w * 0.24, h)
        ..cubicTo(w * 0.42, h * 0.86, w * 0.70, h * 0.70, w, h * 0.54),
      0.3,
    );
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.45),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.38, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  /// A rounded, right-pointing triangle centred on [center].
  void _triangle(
    Canvas canvas,
    Offset center,
    double side,
    double alpha,
    double blur,
  ) {
    final half = side / 2;
    final points = [
      center + Offset(-half * 0.62, -half),
      center + Offset(half * 0.95, 0),
      center + Offset(-half * 0.62, half),
    ];
    final corner = side * 0.16;

    Offset toward(Offset from, Offset to) {
      final d = to - from;
      return from + d * (corner / d.distance);
    }

    final path = Path();
    for (var i = 0; i < 3; i++) {
      final vertex = points[i];
      final entry = toward(vertex, points[(i + 2) % 3]);
      final exit = toward(vertex, points[(i + 1) % 3]);
      i == 0
          ? path.moveTo(entry.dx, entry.dy)
          : path.lineTo(entry.dx, entry.dy);
      path.quadraticBezierTo(vertex.dx, vertex.dy, exit.dx, exit.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.glow.withValues(alpha: alpha * p.glowStrength),
            p.sheet.withValues(alpha: alpha * 0.55 * p.glowStrength),
          ],
        ).createShader(path.getBounds())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  void _sheet(
    Canvas canvas,
    Path fill,
    Path edge,
    Rect bounds,
    Alignment from,
  ) {
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: from,
          end: -from,
          colors: [
            p.sheet.withValues(alpha: 0.42 * p.glowStrength),
            p.sheet.withValues(alpha: 0.10 * p.glowStrength),
          ],
        ).createShader(bounds),
    );
    _edgeLine(canvas, edge, 1);
  }

  /// A thin line of light with a soft halo, as if the edge caught the glow.
  void _edgeLine(Canvas canvas, Path path, double strength) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = p.edge.withValues(alpha: 0.22 * strength * p.glowStrength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = p.edge.withValues(alpha: 0.85 * strength),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.p != p;
}
