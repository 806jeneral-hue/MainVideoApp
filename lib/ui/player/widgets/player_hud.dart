import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/playback_controller.dart';
import 'glass.dart';

/// The small floating readout that appears while a gesture is changing
/// volume, brightness, position or speed.
///
/// It listens to its own notifier, so a gesture repaints this box alone.
class PlayerHud extends StatelessWidget {
  const PlayerHud({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return IgnorePointer(
      child: Center(
        child: ValueListenableBuilder<HudState?>(
          valueListenable: playback.hud,
          builder: (context, state, _) => AnimatedOpacity(
            opacity: state == null ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: state == null
                ? const SizedBox.shrink()
                : _HudBox(state: state, playback: playback),
          ),
        ),
      ),
    );
  }
}

class _HudBox extends StatelessWidget {
  const _HudBox({required this.state, required this.playback});

  final HudState state;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Same glass as the rest of the player, so the readout belongs to the
    // same component family and follows the theme.
    return GlassPanel(
      radius: BorderRadius.circular(AppTheme.radiusCard),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon(state.kind),
            color: theme.colorScheme.onSurface,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            state.kind == HudKind.seek
                ? '${Fmt.duration(playback.position)}  (${state.label})'
                : state.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.value,
                minHeight: 4,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.18,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(HudKind kind) => switch (kind) {
    HudKind.volume => Icons.volume_up_rounded,
    HudKind.brightness => Icons.brightness_6_rounded,
    HudKind.seek => Icons.fast_forward_rounded,
    HudKind.speed => Icons.speed_rounded,
  };
}
