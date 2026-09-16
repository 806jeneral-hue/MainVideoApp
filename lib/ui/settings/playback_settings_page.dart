import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/services/background_audio_service.dart';
import '../../data/services/pip_service.dart';
import '../../state/settings_controller.dart';
import '../player/widgets/playback_sheets.dart';
import 'widgets/settings_tiles.dart';

/// Phase 5 — every player behaviour is a switch here instead of being forced
/// on. The player reads these values, it never hard-codes them.
class PlaybackSettingsPage extends StatefulWidget {
  const PlaybackSettingsPage({super.key});

  @override
  State<PlaybackSettingsPage> createState() => _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends State<PlaybackSettingsPage> {
  bool? _pipSupported;

  @override
  void initState() {
    super.initState();
    PipService.isSupported().then((value) {
      if (mounted) setState(() => _pipSupported = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text(context.s.playbackSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
        children: [
          SettingsSection(context.s.startingAVideo),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: Icons.play_circle_outline_rounded,
                title: context.s.resumePlayback,
                subtitle: context.s.resumePlaybackBody,
                value: settings.resumePlayback,
                onChanged: settings.setResumePlayback,
              ),
              SettingsSwitch(
                icon: Icons.queue_play_next_rounded,
                title: context.s.autoplayNext,
                subtitle: context.s.autoplayNextBody,
                value: settings.autoplayNext,
                onChanged: settings.setAutoplayNext,
              ),
            ],
          ),
          SettingsSection(context.s.whilePlaying),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: Icons.swipe_rounded,
                title: context.s.gestureControls,
                subtitle: context.s.gestureControlsBody,
                value: settings.gesturesEnabled,
                onChanged: settings.setGesturesEnabled,
              ),
              SettingsTile(
                icon: Icons.forward_10_rounded,
                title: context.s.skipAmount,
                subtitle: context.s.skipAmountBody,
                trailing: Text(
                  '${settings.seekSeconds}s',
                  style: TextStyle(
                    color: context.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickSeekSeconds(context, settings),
              ),
              SettingsSwitch(
                icon: Icons.vibration_rounded,
                title: context.s.haptics,
                subtitle: context.s.hapticsBody,
                value: settings.hapticsEnabled,
                onChanged: settings.setHapticsEnabled,
              ),
              SettingsSwitch(
                icon: Icons.screen_lock_portrait_rounded,
                title: context.s.keepScreenOn,
                subtitle: context.s.keepScreenOnBody,
                value: settings.keepScreenOn,
                onChanged: settings.setKeepScreenOn,
              ),
              SettingsSwitch(
                icon: Icons.picture_in_picture_alt_rounded,
                title: context.s.pipTitle,
                subtitle: _pipSupported == false
                    ? context.s.pipUnsupported
                    : context.s.pipBody,
                value: settings.pipEnabled && _pipSupported != false,
                onChanged: _pipSupported == false
                    ? null
                    : settings.setPipEnabled,
              ),
              SettingsSwitch(
                icon: Icons.headphones_rounded,
                title: context.s.backgroundPlayback,
                subtitle: context.s.backgroundPlaybackBody,
                value: settings.backgroundPlayback,
                // The notification is what keeps Android from reclaiming the
                // app, so the permission is asked for here rather than later.
                onChanged: (value) async {
                  if (value) {
                    await BackgroundAudioService.ensureNotificationPermission();
                  }
                  await settings.setBackgroundPlayback(value);
                },
              ),
            ],
          ),
          SettingsSection(context.s.availableInPlayer),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: Icons.repeat_one_on_rounded,
                title: context.s.abRepeat,
                subtitle: context.s.abRepeatBody,
                value: settings.abRepeatEnabled,
                onChanged: settings.setAbRepeatEnabled,
              ),
              SettingsSwitch(
                icon: Icons.bedtime_outlined,
                title: context.s.sleepTimer,
                subtitle: context.s.sleepTimerBody,
                value: settings.sleepTimerEnabled,
                onChanged: settings.setSleepTimerEnabled,
              ),
            ],
          ),
          SettingsSection(context.s.defaults),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.speed_rounded,
                title: context.s.defaultSpeed,
                subtitle: context.s.defaultSpeedBody,
                trailing: Text(
                  Fmt.speed(settings.defaultSpeed),
                  style: TextStyle(
                    color: context.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickDefaultSpeed(context, settings),
              ),
              SettingsSwitch(
                icon: Icons.shuffle_rounded,
                title: context.s.shuffleByDefault,
                subtitle: context.s.shuffleByDefaultBody,
                value: settings.shuffle,
                onChanged: settings.setShuffle,
              ),
              SettingsTile(
                icon: Icons.repeat_rounded,
                title: context.s.defaultRepeatMode,
                subtitle: context.s.defaultRepeatModeBody,
                trailing: Text(
                  settings.loopMode.label(context.s),
                  style: TextStyle(
                    color: context.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickLoopMode(context, settings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickSeekSeconds(
    BuildContext context,
    SettingsController settings,
  ) {
    const options = [5, 10, 15, 20, 30, 60];

    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: Text(
                context.s.skipAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final seconds in options)
                    ChoiceChip(
                      label: Text(context.s.secondsOption(seconds)),
                      selected: settings.seekSeconds == seconds,
                      onSelected: (_) {
                        settings.setSeekSeconds(seconds);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDefaultSpeed(
    BuildContext context,
    SettingsController settings,
  ) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: Text(
                context.s.defaultSpeed,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final speed in kSpeedOptions)
                    ChoiceChip(
                      label: Text(Fmt.speed(speed)),
                      selected: settings.defaultSpeed == speed,
                      onSelected: (_) {
                        settings.setDefaultSpeed(speed);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLoopMode(
    BuildContext context,
    SettingsController settings,
  ) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in LoopMode.values)
              ListTile(
                leading: Icon(
                  mode == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: settings.loopMode == mode ? context.accent : null,
                ),
                title: Text(mode.label(context.s)),
                trailing: settings.loopMode == mode
                    ? Icon(Icons.check_rounded, color: context.accent)
                    : null,
                onTap: () {
                  settings.setLoopMode(mode);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
