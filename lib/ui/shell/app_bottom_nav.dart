import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../common/glass.dart';
import 'nav_glyphs.dart';

class NavItem {
  const NavItem({required this.glyph, required this.label});

  final NavGlyphKind glyph;

  /// Not drawn — the bar is icons only — but still read out by TalkBack and
  /// shown on long press.
  final String label;
}

/// Floating glass navigation: see-through with a real blur, so whatever
/// scrolls behind it shows softly through, and the current tab sitting in a
/// wider, lighter capsule of glass.
///
/// The capsule is inset evenly from the bar on every side, so its rounding
/// follows the bar's own edge instead of floating inside it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const double barHeight = 68;
  static const double _inset = 6;
  static const double _gap = 4;

  /// How much wider the current tab's capsule is than the others.
  static const double _selectedWeight = 1.35;

  /// The whole footprint including the space around the bar. The player
  /// uses it to know where the mini player sits above it.
  static const double outerHeight =
      AppTheme.space4 + barHeight + AppTheme.space12;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(barHeight / 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.barMargin,
        AppTheme.space4,
        AppTheme.barMargin,
        AppTheme.space12,
      ),
      child: FrostedBar(
        radius: radius,
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final units = (items.length - 1) + _selectedWeight;
                final unit =
                    (constraints.maxWidth - _gap * (items.length - 1)) / units;

                return Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        width: i == currentIndex
                            ? unit * _selectedWeight
                            : unit,
                        onTap: () => onSelected(i),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = AppBottomNav.barHeight - AppBottomNav._inset * 2;

    // Light: the current tab takes the accent. Dark: it lights up white, the
    // way the reference glass does; the others sit back, dimmed.
    final color = selected
        ? (isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary)
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.45 : 0.40);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: PressScale(
            scale: 0.92,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: selected
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.72))
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: const Duration(milliseconds: 220),
                  builder: (context, value, _) => NavGlyph(
                    kind: item.glyph,
                    color: value ?? color,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
