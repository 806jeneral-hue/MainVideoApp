import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import 'app_icon.dart';

/// One choice in a quick menu.
class QuickMenuAction {
  const QuickMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;

  /// A second line, such as which video and where.
  final String? subtitle;

  /// Filled with the accent: the choice most likely wanted.
  final bool highlighted;
  final VoidCallback onTap;
}

/// Opens a short stack of choices springing out of [anchor] — the button that
/// was held down — over a dimmed page. Tapping outside closes it.
///
/// Every choice is the same size whatever its text, so the stack reads as one
/// neat column.
Future<void> showQuickMenu(
  BuildContext context, {
  required Rect anchor,
  required List<QuickMenuAction> actions,
}) {
  if (actions.isEmpty) return Future.value();
  Haptics.light();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, animation, _) =>
          _QuickMenu(anchor: anchor, actions: actions, animation: animation),
    ),
  );
}

/// The on-screen rectangle of the widget [context] belongs to — the anchor a
/// quick menu springs from.
Rect anchorOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu({
    required this.anchor,
    required this.actions,
    required this.animation,
  });

  final Rect anchor;
  final List<QuickMenuAction> actions;
  final Animation<double> animation;

  static const double _itemHeight = 58;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 32).clamp(0.0, 290.0);
    final height = actions.length * _itemHeight + (actions.length - 1) * _gap;

    // Above the button when it sits low on the screen, below it otherwise.
    final above = anchor.center.dy > size.height / 2;
    final left = (anchor.center.dx - width / 2).clamp(
      16.0,
      (size.width - width - 16).clamp(16.0, double.infinity),
    );
    final top = above
        ? (anchor.top - 12 - height).clamp(16.0, double.infinity)
        : (anchor.bottom + 12).clamp(16.0, size.height - height - 16);

    // The item nearest the button comes first, so the list grows away from
    // the finger.
    final ordered = above ? actions.reversed.toList() : actions;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < ordered.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                _Staggered(
                  animation: animation,
                  // Nearest the button first.
                  order: above ? ordered.length - 1 - i : i,
                  count: ordered.length,
                  fromBelow: above,
                  child: SizedBox(
                    height: _itemHeight,
                    child: _Item(action: ordered[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lets each choice pop in a moment after the one before it.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.order,
    required this.count,
    required this.fromBelow,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final int count;
  final bool fromBelow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (order / (count + 1)) * 0.5;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        (start + 0.6).clamp(0, 1),
        curve: Curves.easeOutBack,
      ),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * (fromBelow ? 14 : -14)),
          child: Transform.scale(
            scale: 0.92 + 0.08 * curved.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.action});

  final QuickMenuAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final highlighted = action.highlighted;
    final radius = AppTheme.pillRadius;

    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          Navigator.of(context).pop();
          action.onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 18, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlighted
                      ? onAccent.withValues(alpha: 0.16)
                      : accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    action.icon,
                    size: 19,
                    color: highlighted ? onAccent : theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: highlighted ? onAccent : null,
                      ),
                    ),
                    if (action.subtitle != null)
                      Text(
                        action.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: highlighted
                              ? onAccent.withValues(alpha: 0.75)
                              : context.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Solid enough to read over any page: the dimmed list is right behind it.
    return highlighted
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: accent,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: content,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.solidCard(
                theme.brightness == Brightness.dark,
              ).withValues(alpha: 0.96),
              borderRadius: radius,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
              ),
              boxShadow: AppTheme.floatingShadow(theme.brightness),
            ),
            child: content,
          );
  }
}
