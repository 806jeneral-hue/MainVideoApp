import 'package:flutter/material.dart';

/// The lit rim of a pane of glass: a hairline that catches the light at the
/// top-left corner and fades away towards the bottom-right, instead of the
/// even outline a plain border draws.
///
/// It is a [ShapeBorder], so the same edge can be given to cards, dialogs,
/// chips, sheets and anything drawn with a [ShapeDecoration] — one stroke per
/// element, which costs no more than the border it replaces.
@immutable
class GlassBorder extends OutlinedBorder {
  const GlassBorder({
    required this.radius,
    required this.lit,
    required this.shade,
    this.width = 1.2,
  }) : super(side: BorderSide.none);

  final BorderRadius radius;

  /// The colour of the rim where the light hits it.
  final Color lit;

  /// The colour it settles to on the far side.
  final Color shade;

  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  ShapeBorder scale(double t) => GlassBorder(
    radius: radius * t,
    lit: Color.lerp(null, lit, t)!,
    shade: Color.lerp(null, shade, t)!,
    width: width * t,
  );

  @override
  GlassBorder copyWith({BorderSide? side, BorderRadius? radius}) => GlassBorder(
    radius: radius ?? this.radius,
    lit: lit,
    shade: shade,
    width: width,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is GlassBorder) {
      return GlassBorder(
        radius: BorderRadius.lerp(a.radius, radius, t)!,
        lit: Color.lerp(a.lit, lit, t)!,
        shade: Color.lerp(a.shade, shade, t)!,
        width: a.width + (width - a.width) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is GlassBorder) return b.lerpFrom(this, 1 - t);
    return super.lerpTo(b, t);
  }

  RRect _rrect(Rect rect, TextDirection? direction) =>
      radius.resolve(direction).toRRect(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect.deflate(width), textDirection));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    // Stroked down the middle of the edge, so the light sits on the rim
    // rather than just inside or outside it.
    final inset = _rrect(rect.deflate(width / 2), textDirection);
    canvas.drawRRect(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lit, Color.lerp(lit, shade, 0.55)!, shade],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassBorder &&
      other.radius == radius &&
      other.lit == lit &&
      other.shade == shade &&
      other.width == width;

  @override
  int get hashCode => Object.hash(radius, lit, shade, width);
}
