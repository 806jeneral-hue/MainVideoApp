import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// Switches the player's frosting off for a moment — while the whole player
/// is fading in, fading out or shrinking into the mini player. Nothing can be
/// read through a panel that is itself moving and fading, so the blur only
/// costs frames there.
class GlassBlurGate extends InheritedWidget {
  const GlassBlurGate({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassBlurGate>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(GlassBlurGate oldWidget) =>
      oldWidget.enabled != enabled;
}

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
        : Color.alphaBlend(
            tint!.withValues(alpha: 0.82),
            AppTheme.glassFill(theme),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: AppTheme.glassShadow(theme),
      ),
      child: ClipRRect(
        borderRadius: shape,
        // Grouped: every panel over the same video shares one read of what is
        // behind them instead of each taking its own.
        child: BackdropFilter.grouped(
          enabled: GlassBlurGate.enabledOf(context),
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
        AppIcon(
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

/// Glass for the library screens: the milky fill, bright edge and soft lift
/// from [AppTheme.glassSurface], without a live blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.floating = false,
    this.blur = false,
  });

  final Widget child;
  final BorderRadius? radius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool floating;

  /// Blurs what is behind it, the way real frosted glass does. Kept for the
  /// few pieces that float on their own — headers, filters, bars — never for
  /// list cards, where one blur layer per row would cost the scroll its
  /// smoothness.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final shape = radius ?? AppTheme.cardRadius;
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: context.glassSurface(
        radius: shape,
        selected: selected,
        floating: floating,
      ),
      padding: padding,
      child: child,
    );
    if (!blur || AppTheme.isSolid) return surface;

    return Stack(
      children: [
        // Behind the fill, so the frosting reads through it rather than over.
        Positioned.fill(
          child: ClipRRect(
            borderRadius: shape,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
        surface,
      ],
    );
  }
}

/// Shrinks its child a touch while a finger is down — the small physical
/// response that makes a glass button feel pressed rather than just tapped.
///
/// Uses a listener, so it never competes with the child's own gestures.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.94});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Round floating glass button for page headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 46,
    this.iconSize = 22,
    this.selected = false,
    this.blur = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool selected;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = BorderRadius.circular(size / 2);

    return PressScale(
      child: GlassSurface(
        radius: shape,
        floating: true,
        blur: blur,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: tooltip,
              child: SizedBox(
                width: size,
                height: size,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: AppIcon(
                    icon,
                    key: ValueKey(icon),
                    size: iconSize,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
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

/// Drop-in replacement for an [IconButton] in an [AppBar]'s actions: the same
/// arguments, drawn as a floating glass circle.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Filled with the accent, for the one action a page wants noticed.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 42,
            height: 42,
            child: IconTheme.merge(
              data: IconThemeData(
                size: 21,
                color: highlighted
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppTheme.space8),
      child: PressScale(
        child: highlighted
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: body,
              )
            : GlassSurface(
                radius: BorderRadius.circular(21),
                floating: true,
                child: body,
              ),
      ),
    );
  }
}

/// A bottom bar of see-through glass: the list scrolling behind it shows
/// through, blurred. Used for the navigation bar and the mini player so the
/// two read as one piece.
class FrostedBar extends StatelessWidget {
  const FrostedBar({super.key, required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (AppTheme.isSolid) {
      // A solid bar: nothing to see through, so nothing to blur.
      return DecoratedBox(
        decoration: AppTheme.frostedBar(
          theme,
          radius,
        ).copyWith(boxShadow: AppTheme.floatingShadow(theme.brightness)),
        child: ClipRRect(borderRadius: radius, child: child),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppTheme.floatingShadow(theme.brightness),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.frostedBlur,
            sigmaY: AppTheme.frostedBlur,
          ),
          child: Container(
            decoration: AppTheme.frostedBar(theme, radius),
            // The rim is painted over the fill, so the bar carries the same
            // lit edge as every other piece of glass.
            foregroundDecoration: ShapeDecoration(
              shape: AppTheme.glassEdge(
                theme.brightness == Brightness.dark,
                radius,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
