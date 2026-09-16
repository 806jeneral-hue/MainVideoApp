import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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
    // The shell below draws its own frosted surface and handle.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const radius = BorderRadius.vertical(
      top: Radius.circular(AppTheme.radiusSheet),
    );

    // A frosted glass sheet: the page (or the video) stays softly visible
    // behind it. The blur is paid only while a sheet is open.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFraction,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.glassBlur,
            sigmaY: AppTheme.glassBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.84)
                  : Colors.white.withValues(alpha: 0.86),
              borderRadius: radius,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              // Lifts the sheet above the keyboard instead of letting it
              // cover the field being typed into.
              child: Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: AppTheme.space12,
                        bottom: AppTheme.space12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: AppTheme.pillRadius,
                      ),
                    ),
                    Flexible(
                      child: hasOwnScroll
                          ? child
                          : SingleChildScrollView(child: child),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
