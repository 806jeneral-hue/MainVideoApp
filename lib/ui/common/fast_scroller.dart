import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_icons.dart';

/// Draggable handle down the side of a long list.
///
/// It appears only once a list is long enough to be worth skimming, fades in
/// while the list moves, and can be grabbed to jump anywhere in one gesture
/// instead of flicking repeatedly.
class FastScroller extends StatefulWidget {
  const FastScroller({
    super.key,
    required this.controller,
    required this.child,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final ScrollController controller;
  final Widget child;

  /// Keeps the handle clear of a floating app bar or navigation bar.
  final double topPadding;
  final double bottomPadding;

  /// Below this much scrollable content the handle would not save anything,
  /// so it never appears.
  static const double minScrollExtent = 1800;

  static const double _thumbHeight = 52;
  static const double _laneWidth = 26;

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  bool _visible = false;
  bool _dragging = false;
  double _fraction = 0;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant FastScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_dragging) return;
    final position = _position;
    if (position == null) return;

    final max = position.maxScrollExtent;
    final next = max <= 0 ? 0.0 : (position.pixels / max).clamp(0.0, 1.0);
    final longEnough = max >= FastScroller.minScrollExtent;

    setState(() {
      _fraction = next;
      _visible = longEnough;
    });

    if (!longEnough) return;
    _lastActivity = DateTime.now();
    _scheduleHide();
  }

  void _scheduleHide() {
    final at = _lastActivity;
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted || _dragging) return;
      // Another scroll happened in the meantime; that one owns the timer.
      if (_lastActivity != at) return;
      setState(() => _visible = false);
    });
  }

  ScrollPosition? get _position {
    if (!widget.controller.hasClients) return null;
    return widget.controller.position;
  }

  void _jumpTo(double fraction, double laneHeight) {
    final position = _position;
    if (position == null) return;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    widget.controller.jumpTo((fraction * max).clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: widget.topPadding,
          bottom: widget.bottomPadding,
          right: 0,
          width: FastScroller._laneWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final laneHeight = constraints.maxHeight;
              final travel = laneHeight - FastScroller._thumbHeight;
              if (travel <= 0) return const SizedBox.shrink();

              return AnimatedOpacity(
                opacity: _visible || _dragging ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !(_visible || _dragging),
                  child: Stack(
                    children: [
                      Positioned(
                        top: _fraction * travel,
                        right: 4,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) {
                            setState(() => _dragging = true);
                          },
                          onVerticalDragUpdate: (details) {
                            final next = (_fraction + details.delta.dy / travel)
                                .clamp(0.0, 1.0);
                            setState(() => _fraction = next);
                            _jumpTo(next, laneHeight);
                          },
                          onVerticalDragEnd: (_) {
                            setState(() => _dragging = false);
                            _lastActivity = DateTime.now();
                            _scheduleHide();
                          },
                          onVerticalDragCancel: () {
                            setState(() => _dragging = false);
                            _lastActivity = DateTime.now();
                            _scheduleHide();
                          },
                          child: Container(
                            width: 20,
                            height: FastScroller._thumbHeight,
                            // A small glass capsule, tinted while it is held.
                            decoration: context.glassSurface(
                              radius: AppTheme.pillRadius,
                              floating: true,
                              selected: _dragging,
                            ),
                            child: Icon(
                              AppIcons.drag_handle_rounded,
                              size: 15,
                              color: _dragging
                                  ? theme.colorScheme.primary
                                  : context.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
