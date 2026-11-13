import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../shell/app_bottom_nav.dart';
import 'bottom_fade.dart';
import 'tab_scroll.dart';

/// Shrinks a list item away as it slides under the floating bottom bars.
///
/// Above the bars nothing happens at all: a row sitting still on screen is
/// always its full size and strength, however close to the bars it is.
///
/// Partly visible rows resting mostly above the bar's top edge stay at full size
/// and full opacity, letting them peek out from behind the bar with no gap or
/// empty band above the navigation. Only once a row has mostly sunk behind the
/// bar's top edge (visible fraction falling below [fadeStartVisibleFraction])
/// does it begin to shrink and fade, reaching full transparency once it is
/// fully or nearly fully behind the bar.
///
/// The work is done while painting, not while building: the row's raster is
/// kept in its own layer and only the transform around it changes, so what it
/// shows is always this frame's position, never the last one's.
class EmergeFromBottom extends StatelessWidget {
  const EmergeFromBottom({super.key, required this.child});

  final Widget child;

  /// How small a row is by the time it reaches the bottom of the screen.
  static const double minScale = 0.78;

  /// The visible fraction of the row above the bar line at which the shrink
  /// and fade effect begins.
  ///
  /// A row that is mostly above the bar's top edge (visible fraction >= 0.35)
  /// remains at full size (scale 1.0) and full opacity (alpha 255).
  static const double fadeStartVisibleFraction = 0.35;

  /// The visible fraction of the row above the bar line at which the row
  /// reaches full transparency (alpha = 0) and minimum scale.
  ///
  /// At 0.0, the row is completely hidden once its top edge has sunk behind
  /// the bar's top edge.
  static const double fadeEndVisibleFraction = 0.0;

  /// Computes the emerge effect metrics for an item at [globalTop] with [itemHeight]
  /// against a bar whose top edge is at [line].
  static EmergeMetrics computeMetrics({
    required double globalTop,
    required double itemHeight,
    required double line,
  }) {
    if (itemHeight <= 0) {
      return const EmergeMetrics(
        visibleFraction: 1.0,
        t: 0.0,
        alpha: 255,
        scale: 1.0,
      );
    }

    final visibleFraction = ((line - globalTop) / itemHeight).clamp(0.0, 1.0);

    if (visibleFraction >= fadeStartVisibleFraction) {
      return EmergeMetrics(
        visibleFraction: visibleFraction,
        t: 0.0,
        alpha: 255,
        scale: 1.0,
      );
    }

    if (visibleFraction <= fadeEndVisibleFraction) {
      return const EmergeMetrics(
        visibleFraction: 0.0,
        t: 1.0,
        alpha: 0,
        scale: minScale,
      );
    }

    final t = (fadeStartVisibleFraction - visibleFraction) /
        (fadeStartVisibleFraction - fadeEndVisibleFraction);
    final eased = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    final alpha = (((1.0 - eased).clamp(0.0, 1.0)) * 255).round();
    final scale = 1.0 - (1.0 - minScale) * eased;

    return EmergeMetrics(
      visibleFraction: visibleFraction,
      t: t,
      alpha: alpha,
      scale: scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!TabScroll.isTab(context)) return child;

    final notifier = TabSelectionBridge.maybeOf(context);
    if (notifier != null) {
      return ValueListenableBuilder<Widget?>(
        valueListenable: notifier,
        builder: (context, selectionBar, _) =>
            _buildWithBars(context, selectionBar),
      );
    }
    return _buildWithBars(context, null);
  }

  Widget _buildWithBars(BuildContext context, Widget? selectionBar) {
    final double barHeight;
    if (selectionBar != null) {
      if (selectionBar is SizedBox &&
          (selectionBar.height == 0 || selectionBar.width == 0)) {
        barHeight = 0;
      } else {
        barHeight = AppBottomNav.outerHeight;
      }
    } else {
      barHeight = AppBottomNav.outerHeight;
    }

    final bars = SystemBottomInset.of(context) + barHeight;
    if (bars <= 0) return child;

    return _EmergeBox(
      line: MediaQuery.sizeOf(context).height - bars,
      band: bars,
      child: RepaintBoundary(child: child),
    );
  }
}

/// Result of computing progress and transform metrics for [EmergeFromBottom].
class EmergeMetrics {
  const EmergeMetrics({
    required this.visibleFraction,
    required this.t,
    required this.alpha,
    required this.scale,
  });

  /// Fraction of the item that is visible above the bottom bar line (0.0 to 1.0).
  final double visibleFraction;

  /// Normalized progress of the fade/shrink effect (0.0 = untouched, 1.0 = fully hidden).
  final double t;

  /// Paint opacity (0 to 255).
  final int alpha;

  /// Transform scale (between [EmergeFromBottom.minScale] and 1.0).
  final double scale;
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
    if (_band <= 0 || size.height <= 0) {
      context.paintChild(child, offset);
      return;
    }

    // Read while painting, so it is where the row is on this frame rather than
    // where it was when the list was last built.
    final globalTop = localToGlobal(Offset.zero).dy;
    final itemHeight = size.height;

    // Guard: when a list item hasn't been laid out on screen yet (e.g. the
    // first scroll into a folder), localToGlobal can return positions that are
    // far outside the visible area (negative or beyond screen height * 2).
    // In that case the emerge maths clamps t to 1.0 → alpha becomes 0 and the
    // row disappears. We detect this by checking that the item's top edge is
    // within a reasonable range and draw it normally when it isn't.
    if (globalTop < -itemHeight || globalTop > _line + _band * 2) {
      context.paintChild(child, offset);
      return;
    }

    final metrics = EmergeFromBottom.computeMetrics(
      globalTop: globalTop,
      itemHeight: itemHeight,
      line: _line,
    );

    if (metrics.t <= 0) {
      context.paintChild(child, offset);
      return;
    }

    if (metrics.alpha == 0) return;

    // Scaled about its own top edge, so the row keeps its place on the page
    // while it draws back under the bar.
    final anchor = offset + Offset(size.width / 2, 0);
    final transform = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(metrics.scale, metrics.scale, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);

    context.pushTransform(true, offset, transform, (inner, innerOffset) {
      inner.pushOpacity(innerOffset, metrics.alpha, (opacity, opacityOffset) {
        opacity.paintChild(child, opacityOffset);
      });
    });
  }
}
