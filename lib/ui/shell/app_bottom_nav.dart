import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../common/glass.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Not drawn — the bar is icons only — but still read out by TalkBack and
  /// shown on long press.
  final String label;
}

/// Floating glass navigation: icons only, with the current tab sitting in a
/// soft accent-tinted circle.
///
/// The circle is sized from the bar's own height so it always keeps an even
/// margin above and below instead of pressing against the edges.
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
  static const double indicatorSize = 52;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space4,
        AppTheme.space20,
        AppTheme.space12,
      ),
      child: GlassSurface(
        radius: BorderRadius.circular(barHeight / 2),
        floating: true,
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
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
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const size = AppBottomNav.indicatorSize;

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
          child: Center(
            child: PressScale(
              scale: 0.9,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.24 : 0.14,
                        )
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary.withValues(
                            alpha: isDark ? 0.36 : 0.22,
                          )
                        : Colors.transparent,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    size: 27,
                    color: selected ? theme.colorScheme.primary : context.muted,
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
