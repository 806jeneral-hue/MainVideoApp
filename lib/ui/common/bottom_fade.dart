import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Room left under a list's last item, so it can scroll clear of the bars and
/// be read at full size above them.
const double kFadeBand = 28;

/// Keeps a list from showing in the strip under the floating bottom bars.
///
/// Rows do pass behind the bars — that is what the frosting is for — but the
/// gap between the bars and the bottom edge of the phone belongs to the page,
/// not to the list, so the list is cut off there. Nothing can flash into that
/// gap while scrolling or refreshing, and rows fade out as they go under the
/// bars (see [EmergeFromBottom]).
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The bar's own bottom margin plus whatever the system keeps for its
    // gesture handle: together, the empty strip under the bars. The system
    // inset comes from [SystemBottomInset], because by the time a page's body
    // is built the Scaffold has replaced the one in the tree with the height
    // of its own bottom bars.
    final strip = AppTheme.space12 + SystemBottomInset.of(context);
    if (strip <= 0 || MediaQuery.paddingOf(context).bottom <= 0) return child;

    return ClipRect(clipper: _AboveTheGap(strip), child: child);
  }
}

/// Carries the system's own bottom inset — the room the phone keeps for its
/// gesture handle — down past the Scaffolds, which overwrite it.
class SystemBottomInset extends InheritedWidget {
  const SystemBottomInset({
    super.key,
    required this.value,
    required super.child,
  });

  final double value;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SystemBottomInset>()?.value ??
      0;

  @override
  bool updateShouldNotify(SystemBottomInset oldWidget) =>
      oldWidget.value != value;
}

class _AboveTheGap extends CustomClipper<Rect> {
  const _AboveTheGap(this.strip);

  final double strip;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    size.width,
    (size.height - strip).clamp(0, size.height),
  );

  @override
  bool shouldReclip(_AboveTheGap oldClipper) => oldClipper.strip != strip;
}

/// Bottom padding that lets the last item scroll all the way clear of the
/// bars, so it can be seen at full strength above them.
///
/// This is scroll extent, not empty space on screen: content passes behind the
/// bars rather than stopping above them.
double listBottomInset(BuildContext context, {double extra = kFadeBand}) =>
    MediaQuery.paddingOf(context).bottom + extra;
