import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass.dart';

/// A row in a bottom sheet, drawn as its own small glass card.
///
/// It takes the same arguments the sheets gave [ListTile], so a sheet moves
/// to the glass look without changing what any row does. [selected] tints the
/// card with the accent, for the current choice in a picker.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,

    /// Accepted for drop-in use; the card keeps its own consistent padding.
    this.contentPadding,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(_radius);
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pageMargin,
        vertical: AppTheme.space4,
      ),
      child: PressScale(
        scale: 0.98,
        child: GlassSurface(
          radius: radius,
          selected: selected,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: AppTheme.space12,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(
                          size: 22,
                          color: selected
                              ? accent
                              : theme.colorScheme.onSurface,
                        ),
                        child: leading!,
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle.merge(
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected ? accent : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            child: title,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            DefaultTextStyle.merge(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppTheme.space8),
                      IconTheme.merge(
                        data: IconThemeData(color: accent, size: 22),
                        child: trailing!,
                      ),
                    ],
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

/// A glass heading for a bottom sheet.
class GlassSheetTitle extends StatelessWidget {
  const GlassSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin + 6,
        0,
        AppTheme.pageMargin + 6,
        AppTheme.space8,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One choice in a [GlassSegmented].
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Two or three mutually exclusive choices in one glass capsule, with a tinted
/// pill sliding under the chosen one.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final index = segments.indexWhere((s) => s.value == selected);

    return GlassSurface(
      radius: AppTheme.pillRadius,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth / segments.length
              : null;

          return Stack(
            children: [
              if (width != null && index >= 0)
                AnimatedPositionedDirectional(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  start: width * index,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.26 : 0.16),
                      borderRadius: AppTheme.pillRadius,
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.40 : 0.26),
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: width == null
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  for (final segment in segments)
                    _segment(context, segment, width, accent),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    GlassSegment<T> segment,
    double? width,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final active = segment.value == selected;
    final color = active ? accent : context.muted;

    final child = InkWell(
      onTap: active ? null : () => onChanged(segment.value),
      borderRadius: AppTheme.pillRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (segment.icon != null) ...[
              Icon(segment.icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? theme.colorScheme.onSurface : color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return width == null
        ? Material(type: MaterialType.transparency, child: child)
        : SizedBox(
            width: width,
            child: Material(type: MaterialType.transparency, child: child),
          );
  }
}

/// The floating action as a glass capsule tinted with the accent, in place
/// of Material's solid floating button.
class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return PressScale(
      child: GlassSurface(
        radius: AppTheme.pillRadius,
        floating: true,
        selected: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppTheme.pillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space20,
                vertical: 14,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: accent, size: 22),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: AppTheme.space8),
                      label,
                    ],
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
