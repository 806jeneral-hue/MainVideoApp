import 'package:flutter/material.dart';

/// Room left under a list's last item, so it can scroll clear of the bars and
/// be read in full above them.
const double kFadeBand = 24;

/// Lets a list run on behind the floating bottom bars and dissolve there.
///
/// The navigation bar and mini player are see-through glass, so what scrolls
/// behind them shows softly through their blur, the way frosted glass does.
/// Across the height of the bars the list fades out gradually — it is still
/// there just under their top edge and gone by the bottom of the screen — so
/// the bars never sit on a hard cut-off.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // With `extendBody: true` the Scaffold reports the height of the bottom
    // bars here, so this tracks the mini player appearing and disappearing.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (bottomInset <= 0) return child;

    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final height = bounds.height;
          if (height <= 0) {
            return const LinearGradient(
              colors: [Colors.white, Colors.white],
            ).createShader(bounds);
          }

          // Full strength until the top of the bars, then an eased dissolve
          // down to nothing at the bottom edge of the screen.
          final start = ((height - bottomInset) / height).clamp(0.0, 1.0);
          final span = 1 - start;

          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.white,
              Colors.white,
              Color(0xB3FFFFFF),
              Color(0x40FFFFFF),
              Colors.transparent,
            ],
            stops: [0, start, start + span * 0.35, start + span * 0.7, 1],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

/// Bottom padding that lets the last item scroll all the way clear of the
/// bars, so it can be seen at full strength above them.
///
/// This is scroll extent, not empty space on screen: content passes behind the
/// bars rather than stopping above them.
double listBottomInset(BuildContext context, {double extra = kFadeBand}) =>
    MediaQuery.paddingOf(context).bottom + extra;
