import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How tall the dissolve is, measured upwards from the top edge of the
/// navigation bar.
const double kFadeBand = 90;

/// Dissolves the bottom of a list so videos are already gone by the time they
/// reach the navigation bar.
///
/// The list still owns the whole screen — it scrolls on behind the bar rather
/// than stopping short of it — but a video is fully transparent from the top
/// edge of the bar downwards, and fades in over [kFadeBand] above that. So a
/// video only ever becomes visible above the bar, never beside or behind it.
///
/// The faded region is clipped to the same rounded corners the cards and
/// buttons use, so its edge belongs to the same shape language.
class BottomFade extends StatelessWidget {
  const BottomFade({
    super.key,
    required this.child,
    this.fadeBand = kFadeBand,
    this.cornerRadius = AppTheme.radiusSheet,
  });

  final Widget child;
  final double fadeBand;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    // With `extendBody: true` the Scaffold reports the height of the bottom
    // bars here, so this tracks the mini player appearing and disappearing.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return RepaintBoundary(
      child: ClipPath(
        clipper: _FadeAreaClipper(
          bottomInset: bottomInset,
          radius: cornerRadius,
        ),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final height = bounds.height;
            if (height <= 0) {
              return const LinearGradient(
                colors: [Colors.white, Colors.white],
              ).createShader(bounds);
            }

            // Fully transparent from the top of the bar down.
            final end = ((height - bottomInset) / height).clamp(0.0, 1.0);
            final start = ((height - bottomInset - fadeBand) / height).clamp(
              0.0,
              end,
            );
            final span = end - start;

            // Eased rather than linear: a straight ramp still reads as a band
            // with edges, these stops make the dissolve feel continuous.
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.white,
                Colors.white,
                Color(0xBFFFFFFF),
                Color(0x4DFFFFFF),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [
                0,
                start,
                start + span * 0.42,
                start + span * 0.74,
                end,
                1,
              ],
            ).createShader(bounds);
          },
          child: child,
        ),
      ),
    );
  }
}

/// Rounds off the bottom of the visible area at the top edge of the bar,
/// rather than at the bottom of the screen.
class _FadeAreaClipper extends CustomClipper<Path> {
  const _FadeAreaClipper({required this.bottomInset, required this.radius});

  final double bottomInset;
  final double radius;

  @override
  Path getClip(Size size) {
    final bottom = (size.height - bottomInset).clamp(0.0, size.height);
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(0, 0, size.width, bottom),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      ),
    );
  }

  @override
  bool shouldReclip(_FadeAreaClipper old) =>
      old.bottomInset != bottomInset || old.radius != radius;
}

/// Bottom padding that lets the last item scroll all the way clear of the
/// dissolve, so it can be seen at full opacity above the bar.
///
/// This is scroll extent, not empty space on screen: content passes behind the
/// navigation bar rather than stopping above it.
double listBottomInset(BuildContext context, {double extra = kFadeBand}) =>
    MediaQuery.paddingOf(context).bottom + extra;
