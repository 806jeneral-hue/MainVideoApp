import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'bottom_fade.dart';

/// Shrinks a list item away as it slides under the floating bottom bars.
///
/// Above the bars nothing happens at all: a row sitting still on screen is
/// always its full size and strength, however close to the bars it is. Only
/// once a row crosses the bars' top edge does it start to shrink and fade,
/// until it is gone by the bottom of the screen — so rows sink under the bars
/// and rise back out of them one by one, instead of being cut off at an edge.
///
/// The work is done while painting, not while building: the row's raster is
/// kept in its own layer and only the transform around it changes, so what it
/// shows is always this frame's position, never the last one's.
class EmergeFromBottom extends StatelessWidget {
  const EmergeFromBottom({super.key, required this.child});

  final Widget child;

  /// How small a row is by the time it reaches the bottom of the screen.
  static const double _minScale = 0.78;

  @override
  Widget build(BuildContext context) {
    // The navigation bar's top edge, leaving the mini player out: rows keep
    // their size and place when it appears, and it floats over the last one.
    final bars = steadyBottomInset(context);
    if (bars <= 0) return child;

    return _EmergeBox(
      line: MediaQuery.sizeOf(context).height - bars,
      band: bars,
      // Its own layer, so sliding under the bars never re-rasterises the row.
      child: RepaintBoundary(child: child),
    );
  }
}

class _EmergeBox extends SingleChildRenderObjectWidget {
  const _EmergeBox({
    required this.line,
    required this.band,
    required super.child,
  });

  final double line;
  final double band;

  @override
  _RenderEmerge createRenderObject(BuildContext context) =>
      _RenderEmerge(line, band);

  @override
  void updateRenderObject(BuildContext context, _RenderEmerge renderObject) {
    renderObject
      ..line = line
      ..band = band;
  }
}

class _RenderEmerge extends RenderProxyBox {
  _RenderEmerge(this._line, this._band);

  double _line;
  double _band;

  set line(double value) {
    if (_line == value) return;
    _line = value;
    markNeedsPaint();
  }

  set band(double value) {
    if (_band == value) return;
    _band = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_band <= 0) {
      context.paintChild(child, offset);
      return;
    }

    // Read while painting, so it is where the row is on this frame rather than
    // where it was when the list was last built.
    final bottom = localToGlobal(Offset.zero).dy + size.height;
    final t = ((bottom - _line) / _band).clamp(0.0, 1.0);
    if (t <= 0) {
      context.paintChild(child, offset);
      return;
    }

    // The moment any of the row is behind the bar it starts drawing back, and
    // it is gone well before it reaches the bottom of the bar.
    final eased = Curves.easeOutCubic.transform(t);
    final alpha = (((1 - eased * 1.35).clamp(0.0, 1.0)) * 255).round();
    if (alpha == 0) return;

    // Scaled about its own top edge, so the row keeps its place on the page
    // while it draws back under the bar.
    final scale = 1 - (1 - EmergeFromBottom._minScale) * eased;
    final anchor = offset + Offset(size.width / 2, 0);
    final transform = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);

    context.pushTransform(true, offset, transform, (inner, innerOffset) {
      inner.pushOpacity(innerOffset, alpha, (opacity, opacityOffset) {
        opacity.paintChild(child, opacityOffset);
      });
    });
  }
}
