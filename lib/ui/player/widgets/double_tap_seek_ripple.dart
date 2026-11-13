import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';

/// YouTube-style curved ripple overlay that appears on the left or right side
/// of the video player during a double-tap seek sequence.
class DoubleTapSeekRipple extends StatefulWidget {
  const DoubleTapSeekRipple({
    super.key,
    required this.visible,
    required this.isForward,
    required this.seconds,
  });

  /// Whether the seek ripple is currently active.
  final bool visible;

  /// True for right side (fast forward), false for left side (rewind).
  final bool isForward;

  /// Accumulated seek seconds (e.g. 2, 4, 6...).
  final int seconds;

  @override
  State<DoubleTapSeekRipple> createState() => _DoubleTapSeekRippleState();
}

class _DoubleTapSeekRippleState extends State<DoubleTapSeekRipple>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _arrowController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );

    if (widget.visible) {
      _fadeController.value = 1.0;
      _arrowController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DoubleTapSeekRipple oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.visible && !oldWidget.visible) {
      _fadeController.forward();
      _arrowController.repeat();
      _pulseController.forward(from: 0.0).then((_) {
        if (mounted) _pulseController.reverse();
      });
    } else if (!widget.visible && oldWidget.visible) {
      _fadeController.reverse().then((_) {
        if (mounted && !widget.visible) {
          _arrowController.stop();
        }
      });
    } else if (widget.visible && widget.seconds != oldWidget.seconds) {
      // Pulse animation when additional taps accumulate
      _pulseController.forward(from: 0.0).then((_) {
        if (mounted) _pulseController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _arrowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        if (_fadeAnimation.value <= 0.0) return const SizedBox.shrink();

        final size = MediaQuery.sizeOf(context);
        final halfWidth = size.width / 2;

        return Positioned(
          left: widget.isForward ? null : 0,
          right: widget.isForward ? 0 : null,
          top: 0,
          bottom: 0,
          width: halfWidth,
          child: IgnorePointer(
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: ClipPath(
                clipper: _SeekArcClipper(isForward: widget.isForward),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: widget.isForward
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: widget.isForward
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AnimatedArrows(
                            isForward: widget.isForward,
                            controller: _arrowController,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.isForward ? '+' : '-'}${widget.seconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws an arc shape on the inner side (towards the center of the screen),
/// mirroring YouTube's double-tap seek highlight.
class _SeekArcClipper extends CustomClipper<Path> {
  const _SeekArcClipper({required this.isForward});

  final bool isForward;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isForward) {
      // Right half: left edge curves inwards towards the left
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.5,
        0,
        0,
      );
      path.close();
    } else {
      // Left half: right edge curves inwards towards the right
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.5,
        size.width,
        0,
      );
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SeekArcClipper oldClipper) =>
      oldClipper.isForward != isForward;
}

/// 3 chevron arrows that animate in sequence to indicate forward/backward seek.
class _AnimatedArrows extends StatelessWidget {
  const _AnimatedArrows({
    required this.isForward,
    required this.controller,
  });

  final bool isForward;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value;
        // Staggered opacity waves across the 3 arrows (0, 1, 2)
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final arrowIndex = isForward ? index : (2 - index);
              final phase = (progress - (arrowIndex * 0.25)) % 1.0;
              final opacity = (phase < 0.5
                      ? phase * 2
                      : (1.0 - phase) * 2)
                  .clamp(0.25, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Icon(
                  isForward
                      ? AppIcons.play_arrow_rounded
                      : AppIcons.arrow_back_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: opacity),
                  shadows: const [
                    Shadow(color: Colors.black45, blurRadius: 4),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

