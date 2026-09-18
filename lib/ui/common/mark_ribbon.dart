import 'package:flutter/material.dart';

/// The small bookmark ribbon hanging from the top of a thumbnail: this is the
/// video the user marked as where they stopped in this list.
class MarkRibbon extends StatelessWidget {
  const MarkRibbon({super.key, required this.color, this.width = 14});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * 1.45),
    painter: _RibbonPainter(color),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.22;
    // A tab with rounded top corners and a soft notch cut into its foot.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h - r * 0.6)
      ..lineTo(w / 2, h * 0.74)
      ..lineTo(r, h - r * 0.6)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}
