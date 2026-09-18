import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/playback_controller.dart';
import '../../common/glass.dart';
import '../../../core/theme/app_icons.dart';
import 'player_glyphs.dart';

/// The floating readout that appears while a gesture is changing volume,
/// brightness, position or speed.
///
/// Volume and brightness show as a tall glass level on the side of the screen
/// away from the finger — a swipe on the right shows on the left and the
/// other way round — so the thumb never covers it. Seeking and the other
/// readouts stay in the middle.
///
/// It listens to its own notifier, so a gesture repaints this alone.
class PlayerHud extends StatefulWidget {
  const PlayerHud({super.key});

  @override
  State<PlayerHud> createState() => _PlayerHudState();
}

class _PlayerHudState extends State<PlayerHud> {
  /// The last reading, kept while the readout fades out.
  HudState? _last;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _hud(playback),
          _BoostPill(playback: playback),
        ],
      ),
    );
  }

  Widget _hud(PlaybackController playback) {
    return ValueListenableBuilder<HudState?>(
      valueListenable: playback.hud,
      builder: (context, state, _) {
        if (state != null) _last = state;
        final shown = _last;
        if (shown == null) return const SizedBox.shrink();

        final readout = switch (shown.kind) {
          // Volume is swiped on the right, so it reads out on the left.
          HudKind.volume => _Side(
            alignment: Alignment.centerLeft,
            child: _LevelBar(state: shown),
          ),
          // Brightness is swiped on the left, so it reads out on the right.
          HudKind.brightness => _Side(
            alignment: Alignment.centerRight,
            child: _LevelBar(state: shown),
          ),
          // Seeking reads out in a small pill at the top, clear of the
          // picture, instead of a box in the middle of it.
          HudKind.seek => _SeekPill(state: shown, playback: playback),
          _ => Center(
            child: _HudBox(state: shown, playback: playback),
          ),
        };

        return AnimatedOpacity(
          opacity: state == null ? 0 : 1,
          duration: const Duration(milliseconds: 160),
          child: readout,
        );
      },
    );
  }
}

/// Shown for as long as a finger holds the picture: the video is playing at
/// double speed.
class _BoostPill extends StatelessWidget {
  const _BoostPill({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: playback.boosting,
      builder: (context, boosting, _) => AnimatedOpacity(
        opacity: boosting ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: AnimatedScale(
          scale: boosting ? 1 : 0.9,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: AppTheme.space16),
                child: GlassPanel(
                  radius: AppTheme.pillRadius,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerGlyph(
                          PlayerGlyphKind.fastForward,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Text(
                          '${PlaybackController.boostSpeed.toStringAsFixed(0)}×',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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

/// Where the video is being moved to, and by how much.
class _SeekPill extends StatelessWidget {
  const _SeekPill({required this.state, required this.playback});

  final HudState state;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final back = state.label.startsWith('-');

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: AppTheme.space16),
          child: GlassPanel(
            radius: AppTheme.pillRadius,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    back
                        ? AppIcons.fast_rewind_rounded
                        : AppIcons.fast_forward_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    '${Fmt.duration(playback.position)} / ${Fmt.duration(playback.duration)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    state.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.muted,
                      fontWeight: FontWeight.w600,
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

class _Side extends StatelessWidget {
  const _Side({required this.alignment, required this.child});

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
          child: child,
        ),
      ),
    );
  }
}

/// A tall glass level: the icon, a vertical track filling from the bottom,
/// and the percentage.
class _LevelBar extends StatelessWidget {
  // Takes the reading rather than looking it up: a const bar would never
  // rebuild, and the level would stay stuck where it first appeared.
  const _LevelBar({required this.state});

  final HudState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final value = state.value.clamp(0.0, 1.0);
    final trackHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(
      100.0,
      220.0,
    );

    final icon = switch (state.kind) {
      HudKind.volume =>
        value <= 0.001
            ? AppIcons.volume_off_rounded
            : (value < 0.5
                  ? AppIcons.volume_down_rounded
                  : AppIcons.volume_up_rounded),
      _ =>
        value < 0.34
            ? AppIcons.brightness_low_rounded
            : (value < 0.67
                  ? AppIcons.brightness_medium_rounded
                  : AppIcons.brightness_high_rounded),
    };

    return GlassPanel(
      radius: AppTheme.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.onSurface),
          const SizedBox(height: AppTheme.space12),
          SizedBox(
            width: 8,
            height: trackHeight,
            child: ClipRRect(
              borderRadius: AppTheme.pillRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: value,
                      widthFactor: 1,
                      child: ColoredBox(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
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
          Icon(_icon(state.kind), color: theme.colorScheme.onSurface, size: 26),
          const SizedBox(height: 10),
          Text(
            state.kind == HudKind.seek
                ? '${Fmt.duration(playback.position)}  (${state.label})'
                : state.label,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.kind != HudKind.display) ...[
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
        ],
      ),
    );
  }

  IconData _icon(HudKind kind) => switch (kind) {
    HudKind.volume => AppIcons.volume_up_rounded,
    HudKind.brightness => AppIcons.brightness_6_rounded,
    HudKind.seek => AppIcons.fast_forward_rounded,
    HudKind.speed => AppIcons.speed_rounded,
    HudKind.display => AppIcons.aspect_ratio_rounded,
  };
}
