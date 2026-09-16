import 'package:flutter/material.dart';

/// One way of showing a bottom sheet, used everywhere in the app.
///
/// A plain `showModalBottomSheet` caps its height at 9/16 of the screen and
/// simply clips anything taller — which is why long menus came out cut off.
/// This always turns that cap off, keeps the sheet clear of the status bar,
/// and lets the content scroll when it does not fit, so a sheet is never
/// truncated on a short screen, at a large font size, or with the keyboard up.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,

  /// Set when the sheet already contains its own scrolling list, so it is not
  /// nested inside a second scroll view.
  bool hasOwnScroll = false,

  /// Fraction of the screen the sheet may grow to before it starts scrolling.
  double maxHeightFraction = 0.88,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SheetShell(
      hasOwnScroll: hasOwnScroll,
      maxHeightFraction: maxHeightFraction,
      child: Builder(builder: builder),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.child,
    required this.hasOwnScroll,
    required this.maxHeightFraction,
  });

  final Widget child;
  final bool hasOwnScroll;
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFraction,
      ),
      child: SafeArea(
        top: false,
        // Lifts the sheet above the keyboard instead of letting it cover the
        // field being typed into.
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: hasOwnScroll ? child : SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}
