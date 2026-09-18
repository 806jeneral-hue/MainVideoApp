import 'package:flutter/widgets.dart';

import '../../core/theme/app_icons.dart';

/// Draws an [AppIcons] icon, swapping in the app's own hand-drawn shapes where
/// the icon font's version is not soft enough.
///
/// The hand-drawn ones — the transport controls, search and sort — are plump,
/// with every corner and line end clearly rounded, and the triangles sit in
/// the middle by their visual centre so they look centred in a round button.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphs[icon];
    if (glyph == null) return Icon(icon, size: size, color: color);
    final flip =
        icon.matchTextDirection &&
        Directionality.of(context) == TextDirection.rtl;

    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return CustomPaint(
      size: Size.square(side),
      painter: _GlyphPainter(
        glyph,
        color ?? theme.color ?? const Color(0xFF000000),
        flip: flip,
      ),
    );
  }

  static final Map<IconData, List<_Stroke>> _glyphs = () {
    final search = [
      _Stroke(
        Path()..addOval(
          Rect.fromCircle(center: const Offset(10.6, 10.6), radius: 6.1),
        ),
        3.1,
      ),
      _Stroke(_line(const Offset(15.4, 15.4), const Offset(19.4, 19.4)), 3.6),
    ];
    // A chevron pointing right, centred on its own bounds.
    final chevronRight = [
      _Stroke(
        _polyline(const [Offset(9.5, 5.5), Offset(16, 12), Offset(9.5, 18.5)]),
        3.2,
      ),
    ];
    return <IconData, List<_Stroke>>{
      AppIcons.keyboard_arrow_down_rounded: [
        _Stroke(
          _polyline(const [
            Offset(5.5, 8.8),
            Offset(12, 15.2),
            Offset(18.5, 8.8),
          ]),
          3.4,
        ),
      ],
      AppIcons.chevron_right_rounded: chevronRight,
      AppIcons.arrow_back_rounded: _mirror(chevronRight),
      // A plain plus: two thick strokes with round ends, no box around it.
      AppIcons.add_rounded: [
        _Stroke(_line(const Offset(12, 5.2), const Offset(12, 18.8)), 3.1),
        _Stroke(_line(const Offset(5.2, 12), const Offset(18.8, 12)), 3.1),
      ],
      // A plain minus, to match the plus.
      AppIcons.remove_rounded: [
        _Stroke(_line(const Offset(5.2, 12), const Offset(18.8, 12)), 3.1),
      ],
      // A thick cross with round ends.
      AppIcons.close_rounded: [
        _Stroke(_line(const Offset(6.2, 6.2), const Offset(17.8, 17.8)), 3.2),
        _Stroke(_line(const Offset(17.8, 6.2), const Offset(6.2, 17.8)), 3.2),
      ],
      // A full disc with a thick, round-ended cross cut out of it.
      AppIcons.cancel_rounded: [
        _Stroke(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(12, 12), radius: 10.5),
          ),
        ),
        _Stroke(
          _line(const Offset(8.4, 8.4), const Offset(15.6, 15.6)),
          2.9,
          true,
        ),
        _Stroke(
          _line(const Offset(15.6, 8.4), const Offset(8.4, 15.6)),
          2.9,
          true,
        ),
      ],
      AppIcons.play_arrow_rounded: [
        _Stroke(_centred(_triangle(4.2, 19.8, 6.6, 20.4, 3.4))),
      ],
      AppIcons.pause_rounded: [
        _Stroke(_pill(Rect.fromLTRB(5.8, 4.6, 10.4, 19.4))),
        _Stroke(_pill(Rect.fromLTRB(13.6, 4.6, 18.2, 19.4))),
      ],
      AppIcons.skip_next_rounded: _skip(),
      AppIcons.skip_previous_rounded: _mirror(_skip()),
      AppIcons.search_rounded: search,
      AppIcons.swap_vert_rounded: [
        _Stroke(_line(const Offset(8, 19), const Offset(8, 5.6)), 2.9),
        _Stroke(
          _polyline(const [
            Offset(4.2, 9.2),
            Offset(8, 5.2),
            Offset(11.8, 9.2),
          ]),
          2.9,
        ),
        _Stroke(_line(const Offset(16, 5), const Offset(16, 18.4)), 2.9),
        _Stroke(
          _polyline(const [
            Offset(12.2, 14.8),
            Offset(16, 18.8),
            Offset(19.8, 14.8),
          ]),
          2.9,
        ),
      ],
    };
  }();

  /// Skip forward: a rounded triangle up against a wide rounded bar.
  static List<_Stroke> _skip() => [
    _Stroke(_triangle(5, 19, 3.6, 15.2, 3)),
    _Stroke(_pill(Rect.fromLTRB(16.2, 5, 20.4, 19))),
  ];

  static List<_Stroke> _mirror(List<_Stroke> strokes) {
    final flip = Matrix4.identity()
      ..translateByDouble(24, 0, 0, 1)
      ..scaleByDouble(-1, 1, 1, 1);
    return [
      for (final s in strokes)
        _Stroke(s.path.transform(flip.storage), s.width, s.erase),
    ];
  }

  static Path _pill(Rect rect) => Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.width / 2)));

  static Path _line(Offset a, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy);

  static Path _polyline(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// A right-pointing triangle from [top] to [bottom], its flat side at
  /// [left] and its tip at [right], with every corner rounded by [corner].
  static Path _triangle(
    double top,
    double bottom,
    double left,
    double right,
    double corner,
  ) {
    final p = [
      Offset(left, top),
      Offset(right, (top + bottom) / 2),
      Offset(left, bottom),
    ];

    Offset toward(Offset from, Offset to) {
      final d = to - from;
      return from + d * (corner / d.distance);
    }

    final path = Path();
    for (var i = 0; i < 3; i++) {
      final vertex = p[i];
      final entry = toward(vertex, p[(i + 2) % 3]);
      final exit = toward(vertex, p[(i + 1) % 3]);
      if (i == 0) {
        path.moveTo(entry.dx, entry.dy);
      } else {
        path.lineTo(entry.dx, entry.dy);
      }
      path.quadraticBezierTo(vertex.dx, vertex.dy, exit.dx, exit.dy);
    }
    return path..close();
  }

  /// Moves a triangle so its centroid, not its bounding box, sits at the
  /// centre: that is where the eye reads a triangle's middle.
  static Path _centred(Path triangle) {
    final box = triangle.getBounds();
    final centroidX = box.left + box.width / 3;
    return triangle.shift(Offset(12 - centroidX, 12 - box.center.dy));
  }
}

/// One part of a glyph: filled when [width] is null, otherwise stroked with
/// round ends and joins.
class _Stroke {
  const _Stroke(this.path, [this.width, this.erase = false]);

  final Path path;
  final double? width;

  /// Cuts this part out of what is drawn before it instead of painting it.
  final bool erase;
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.strokes, this.color, {this.flip = false});

  final List<_Stroke> strokes;
  final Color color;

  /// Mirrors the glyph, for arrows in right-to-left layouts.
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(size.width / 24);
    final erases = strokes.any((s) => s.erase);
    if (erases) canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = color
        ..isAntiAlias = true;
      if (stroke.width != null) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width!
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      }
      if (stroke.erase) paint.blendMode = BlendMode.clear;
      canvas.drawPath(stroke.path, paint);
    }
    if (erases) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.strokes != strokes || old.flip != flip;
}
