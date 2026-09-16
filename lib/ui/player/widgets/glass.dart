import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A translucent panel that floats over the video.
///
/// The blur and the fill come from the theme, so the same component reads
/// correctly in light and dark without the player owning any colours of its
/// own — and the frame stays visible behind it rather than being covered by a
/// solid bar.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius,
    this.padding = EdgeInsets.zero,
    this.tint,
  });

  final Widget child;
  final BorderRadius? radius;
  final EdgeInsets padding;

  /// Mixes a colour into the surface — used to give the play button the
  /// application's accent without turning it into a solid block.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = radius ?? BorderRadius.circular(AppTheme.radiusSheet);
    final fill = tint == null
        ? AppTheme.glassFill(theme)
        : Color.alphaBlend(tint!.withValues(alpha: 0.82), AppTheme.glassFill(theme));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: AppTheme.glassShadow(theme),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.glassBlur,
            sigmaY: AppTheme.glassBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: shape,
              border: Border.all(color: AppTheme.glassBorder(theme), width: 1),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A round glass button — the transport controls and the back button.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 48,
    this.iconSize = 24,
    this.tint,
    this.iconColor,
    this.child,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? tint;
  final Color? iconColor;

  /// Replaces the icon — used for the buffering spinner.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final content =
        child ??
        Icon(
          icon,
          size: iconSize,
          color: enabled
              ? (iconColor ?? theme.colorScheme.onSurface)
              : theme.colorScheme.onSurface.withValues(alpha: 0.35),
        );

    return GlassPanel(
      radius: BorderRadius.circular(size / 2),
      tint: tint,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact icon inside a shared glass pill — the cluster in the top bar.
class GlassBarIcon extends StatelessWidget {
  const GlassBarIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 21,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        icon,
        color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface,
      ),
    );
  }
}
