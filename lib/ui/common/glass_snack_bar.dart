import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_icons.dart';

/// The notice shown after an action — "Video deleted", "Added to queue" — as
/// a floating capsule of frosted glass with real blur, in place of Material's
/// flat bar.
///
/// It is still a [SnackBar], so showing, queueing and dismissing it work
/// exactly as before; only what it draws changes.
SnackBar glassSnackBar({
  required Widget content,
  Duration duration = const Duration(milliseconds: 3000),
  IconData icon = AppIcons.info_outline_rounded,
}) {
  return SnackBar(
    content: _GlassToast(icon: icon, child: content),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    shape: const RoundedRectangleBorder(),
  );
}

class _GlassToast extends StatelessWidget {
  const _GlassToast({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppTheme.floatingShadow(theme.brightness),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.62),
              borderRadius: radius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
