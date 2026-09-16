import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/utils/haptics.dart';

/// Tags a tile with the video it shows, so a drag can find out what is under
/// the finger by hit-testing rather than guessing from item heights — which
/// keeps it working for both the list and the grid.
class DragSelectable extends StatelessWidget {
  const DragSelectable({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MetaData(metaData: _DragSelectTag(id), child: child);
}

class _DragSelectTag {
  const _DragSelectTag(this.id);
  final String id;
}

/// Lets a long-press-and-hold sweep across a list selecting as it goes, and
/// scrolls the list when the finger reaches the top or bottom edge.
///
/// It listens to raw pointer events rather than using a gesture recogniser: the
/// long press has already won the gesture arena by the time the drag starts, so
/// a normal drag recogniser would never see it.
class DragSelectArea extends StatefulWidget {
  const DragSelectArea({
    super.key,
    required this.controller,
    required this.armed,
    required this.onHover,
    required this.onEnd,
    required this.child,
  });

  final ScrollController controller;

  /// True from the moment a long press starts a selection until the finger
  /// lifts. Only then does a drag select rather than scroll.
  final bool armed;

  final ValueChanged<String> onHover;
  final VoidCallback onEnd;
  final Widget child;

  /// How close to an edge the finger has to get before the list starts moving.
  static const double edgeZone = 90;

  /// Pixels per tick at the very edge.
  static const double maxStep = 18;

  @override
  State<DragSelectArea> createState() => _DragSelectAreaState();
}

class _DragSelectAreaState extends State<DragSelectArea> {
  Timer? _autoScroll;
  double _step = 0;
  String? _lastId;

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  void _onMove(Offset globalPosition) {
    if (!widget.armed) return;

    final id = _idAt(globalPosition);
    if (id != null && id != _lastId) {
      _lastId = id;
      Haptics.tick();
      widget.onHover(id);
    }

    _updateAutoScroll(globalPosition);
  }

  /// Finds the tile under the finger by hit-testing this subtree.
  String? _idAt(Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;

    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(globalPosition));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final tag = target.metaData;
        if (tag is _DragSelectTag) return tag.id;
      }
    }
    return null;
  }

  void _updateAutoScroll(Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final local = box.globalToLocal(globalPosition);
    final height = box.size.height;

    // Speed ramps up the closer the finger gets to the edge.
    if (local.dy < DragSelectArea.edgeZone) {
      final t = 1 - (local.dy / DragSelectArea.edgeZone).clamp(0.0, 1.0);
      _step = -DragSelectArea.maxStep * t;
    } else if (local.dy > height - DragSelectArea.edgeZone) {
      final t =
          ((local.dy - (height - DragSelectArea.edgeZone)) /
                  DragSelectArea.edgeZone)
              .clamp(0.0, 1.0);
      _step = DragSelectArea.maxStep * t;
    } else {
      _step = 0;
    }

    if (_step == 0) {
      _stopAutoScroll();
      return;
    }
    _startAutoScroll(globalPosition);
  }

  void _startAutoScroll(Offset globalPosition) {
    if (_autoScroll != null) return;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final controller = widget.controller;
      if (!controller.hasClients || _step == 0) return;

      final position = controller.position;
      final next = (position.pixels + _step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      controller.jumpTo(next);

      // New rows have moved under the stationary finger — take them too.
      final id = _idAt(globalPosition);
      if (id != null && id != _lastId) {
        _lastId = id;
        widget.onHover(id);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _finish() {
    _stopAutoScroll();
    _step = 0;
    _lastId = null;
    if (widget.armed) widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) => _onMove(event.position),
      onPointerUp: (_) => _finish(),
      onPointerCancel: (_) => _finish(),
      child: widget.child,
    );
  }
}
