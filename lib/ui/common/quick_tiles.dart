import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'glass.dart';

/// The building blocks of the app's action menus — the player's More menu and
/// a video's menu in the lists — so both are laid out the same way: short
/// sections, small square tiles three to a row, pill buttons for the main
/// actions, and delete on its own in red at the foot.

/// A section's small heading.
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Tiles three to a row; a short last row keeps its tiles the same width.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    const perRow = 3;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += perRow) {
      final chunk = tiles.sublist(i, (i + perRow).clamp(0, tiles.length));
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: Row(
            children: [
              for (var j = 0; j < perRow; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(child: j < chunk.length ? chunk[j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// A small square button: an icon, its name, and — for a setting — what it
/// is set to. Lit in the accent while switched on or changed from its default.
class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final radius = BorderRadius.circular(16);

    return PressScale(
      child: GlassSurface(
        radius: radius,
        selected: active,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: 21,
                    color: active ? accent : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active ? accent : context.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped action. [filled] makes it the accent button that stands out
/// as the main thing to do — Play, in a video's menu.
class PillAction extends StatelessWidget {
  const PillAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final foreground = filled ? theme.colorScheme.onPrimary : null;

    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: AppTheme.pillRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 17, color: foreground ?? accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PressScale(
      child: filled
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppTheme.pillRadius,
              ),
              child: content,
            )
          : GlassSurface(radius: AppTheme.pillRadius, child: content),
    );
  }
}

/// Deleting sits on its own at the foot of a menu, in red.
class DangerRow extends StatelessWidget {
  const DangerRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.redAccent.withValues(alpha: 0.10),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                AppIcons.delete_outline_rounded,
                size: 19,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
