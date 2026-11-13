import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/utils/haptics.dart';

/// Tags a tile with the video id AND its current index in the ordered list,
/// so the drag can both identify the item and compute ranges for reverse-drag
/// deselection — no guessing from pixel heights needed.
class DragSelectable extends StatelessWidget {
  const DragSelectable({
    super.key,
    required this.id,
    required this.index,
    required this.child,
  });

  final String id;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => MetaData(
        behavior: HitTestBehavior.translucent,
        metaData: DragSelectTag(id, index),
        child: child,
      );
}

class DragSelectTag {
  const DragSelectTag(this.id, this.index);
  final String id;
  final int index;
}

/// Lets a long-press-and-hold sweep across a list selecting as it goes, and
/// scrolls the list when the finger reaches the top or bottom edge.
/// Dragging back over already-selected items deselects them (range logic is
/// handled by the [onHover] callback which receives both id and index).
class DragSelectArea extends StatefulWidget {
  const DragSelectArea({
    super.key,
    required this.controller,
    this.armed = false,
    this.selectionMode = false,
    this.onLongPressStart,
    required this.onHover,
    required this.onEnd,
    required this.child,
  });

  final ScrollController controller;

  /// True from the moment a long press starts a selection until the finger
  /// lifts. Only then does a drag select rather than scroll.
  final bool armed;

  /// True when multi-select mode is currently active.
  final bool selectionMode;

  /// Optional callback when a stationary hold on a tile activates selection mode.
  final void Function(String id, int index)? onLongPressStart;

  /// Called each time the finger moves onto a new item.
  /// Receives both the item's [id] and its [index] in the ordered list so the
  /// callback can compute a selection range and deselect items going backward.
  final void Function(String id, int index) onHover;

  /// Called when the active drag gesture ends or pointer lifts.
  final VoidCallback onEnd;

  final Widget child;

  /// How close to an edge the finger has to get before the list starts moving.
  static const double edgeZone = 90;

  /// Pixels per tick at the very edge.
  static const double maxStep = 18;

  /// Deliberate long-press hold duration required before drag selection activates.
  static const Duration longPressTimeout = Duration(milliseconds: 800);

  /// Slop distance in logical pixels to allow minor finger jitter during hold.
  static const double touchSlop = 20.0;

  @override
  State<DragSelectArea> createState() => _DragSelectAreaState();
}

class _DragSelectAreaState extends State<DragSelectArea> {
  Timer? _autoScroll;
  Timer? _longPressTimer;
  double _step = 0;
  String? _lastId;
  Offset? _downPos;
  DragSelectTag? _downTag;
  bool _isDragging = false;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _downPos = event.position;
    _downTag = _tagAt(event.position);
    _isDragging = false;

    if (widget.armed) {
      _isDragging = true;
      if (_downTag != null) {
        _lastId = _downTag!.id;
        widget.onHover(_downTag!.id, _downTag!.index);
      }
      return;
    }

    // A deliberate long-press hold (800 ms) is required to start selection,
    // whether selectionMode is currently active or not.
    if (_downTag != null) {
      final tag = _downTag!;
      _longPressTimer = Timer(DragSelectArea.longPressTimeout, () {
        _longPressTimer = null;
        if (!mounted || _downTag == null) return;
        _isDragging = true;
        _lastId = tag.id;
        Haptics.medium();
        if (!widget.selectionMode && widget.onLongPressStart != null) {
          widget.onLongPressStart!(tag.id, tag.index);
        } else {
          widget.onHover(tag.id, tag.index);
        }
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downPos;
    if (down != null && _longPressTimer != null) {
      // Movement exceeding touch slop cancels the long press timer —
      // this means normal scrolling or quick swiping will never start selection.
      if ((event.position - down).distance > DragSelectArea.touchSlop) {
        _longPressTimer?.cancel();
        _longPressTimer = null;
      }
    }

    // Only drag-select if a deliberate long-press activated _isDragging or widget.armed
    if (!_isDragging && !widget.armed) return;

    final tag = _tagAt(event.position);
    if (tag != null && tag.id != _lastId) {
      _lastId = tag.id;
      Haptics.tick();
      widget.onHover(tag.id, tag.index);
    }

    _updateAutoScroll(event.position);
  }

  void _onPointerUp(PointerEvent event) {
    _finish();
  }

  void _onPointerCancel(PointerEvent event) {
    _finish();
  }

  /// Finds the tile under the finger by hit-testing this subtree.
  DragSelectTag? _tagAt(Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(globalPosition));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final tag = target.metaData;
        if (tag is DragSelectTag) return tag;
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
      final tag = _tagAt(globalPosition);
      if (tag != null && tag.id != _lastId) {
        _lastId = tag.id;
        Haptics.tick();
        widget.onHover(tag.id, tag.index);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _finish() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _stopAutoScroll();
    _step = 0;
    _lastId = null;
    _downPos = null;
    _downTag = null;
    final wasDragging = _isDragging || widget.armed;
    _isDragging = false;
    if (wasDragging) {
      widget.onEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
