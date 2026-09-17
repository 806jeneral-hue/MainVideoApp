import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../common/glass_controls.dart';
import '../common/glass_dialog.dart';
import '../../core/theme/app_icons.dart';

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
                icon: AppIcons.play_circle_outline_rounded,
                title: context.s.resumePlayback,
                subtitle: context.s.resumePlaybackBody,
                value: settings.resumePlayback,
                onChanged: settings.setResumePlayback,
              ),
              SettingsSwitch(
                icon: AppIcons.queue_play_next_rounded,
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
                icon: AppIcons.swipe_rounded,
                title: context.s.gestureControls,
                subtitle: context.s.gestureControlsBody,
                value: settings.gesturesEnabled,
                onChanged: settings.setGesturesEnabled,
              ),
              SettingsTile(
                icon: AppIcons.forward_10_rounded,
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
              SettingsTile(
                icon: AppIcons.swipe_rounded,
                title: context.s.swipeSeekSpeed,
                subtitle: context.s.swipeSeekSpeedBody,
                trailing: Text(
                  context.s.swipeSeekOption(settings.swipeSeekSeconds),
                  style: TextStyle(
                    color: context.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickSwipeSeek(context, settings),
              ),
              SettingsSwitch(
                icon: AppIcons.vibration_rounded,
                title: context.s.haptics,
                subtitle: context.s.hapticsBody,
                value: settings.hapticsEnabled,
                onChanged: settings.setHapticsEnabled,
              ),
              SettingsSwitch(
                icon: AppIcons.screen_lock_portrait_rounded,
                title: context.s.keepScreenOn,
                subtitle: context.s.keepScreenOnBody,
                value: settings.keepScreenOn,
                onChanged: settings.setKeepScreenOn,
              ),
              SettingsSwitch(
                icon: AppIcons.picture_in_picture_alt_rounded,
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
                icon: AppIcons.headphones_rounded,
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
                icon: AppIcons.repeat_one_on_rounded,
                title: context.s.abRepeat,
                subtitle: context.s.abRepeatBody,
                value: settings.abRepeatEnabled,
                onChanged: settings.setAbRepeatEnabled,
              ),
              SettingsSwitch(
                icon: AppIcons.bedtime_outlined,
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
                icon: AppIcons.speed_rounded,
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
                icon: AppIcons.shuffle_rounded,
                title: context.s.shuffleByDefault,
                subtitle: context.s.shuffleByDefaultBody,
                value: settings.shuffle,
                onChanged: settings.setShuffle,
              ),
              SettingsTile(
                icon: AppIcons.repeat_rounded,
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

  /// How far one full-width swipe on the video moves it.
  Future<void> _pickSwipeSeek(
    BuildContext context,
    SettingsController settings,
  ) {
    const options = [0, 30, 60, 120, 300, 600];

    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSheetTitle(context.s.swipeSeekSpeed),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Text(
                context.s.swipeSeekSpeedBody,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.muted),
              ),
            ),
            for (final seconds in options)
              GlassTile(
                leading: Icon(
                  seconds == 0
                      ? AppIcons.auto_awesome_rounded
                      : AppIcons.swipe_rounded,
                ),
                title: Text(context.s.swipeSeekOption(seconds)),
                selected: settings.swipeSeekSeconds == seconds,
                trailing: settings.swipeSeekSeconds == seconds
                    ? const Icon(AppIcons.check_rounded)
                    : null,
                onTap: () {
                  settings.setSwipeSeekSeconds(seconds);
                  Navigator.pop(sheetContext);
                },
              ),
            // Any other amount, typed in.
            Builder(
              builder: (_) {
                final custom = !options.contains(settings.swipeSeekSeconds);
                return GlassTile(
                  leading: const Icon(AppIcons.edit_rounded),
                  title: Text(context.s.swipeSeekCustom),
                  subtitle: custom
                      ? Text(
                          context.s.swipeSeekOption(settings.swipeSeekSeconds),
                        )
                      : null,
                  selected: custom,
                  trailing: custom ? const Icon(AppIcons.check_rounded) : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final seconds = await _askSwipeSeekSeconds(
                      context,
                      initial: custom ? settings.swipeSeekSeconds : null,
                    );
                    if (seconds != null) {
                      await settings.setSwipeSeekSeconds(seconds);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: AppTheme.space12),
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
              GlassTile(
                leading: Icon(
                  mode == LoopMode.one
                      ? AppIcons.repeat_one_rounded
                      : AppIcons.repeat_rounded,
                  color: settings.loopMode == mode ? context.accent : null,
                ),
                title: Text(mode.label(context.s)),
                selected: settings.loopMode == mode,
                trailing: settings.loopMode == mode
                    ? Icon(AppIcons.check_rounded, color: context.accent)
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

/// Asks for the seconds a full-width swipe should move, typed in.
Future<int?> _askSwipeSeekSeconds(BuildContext context, {int? initial}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  String? error;

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final s = dialogContext.s;

        void submit() {
          final value = int.tryParse(controller.text.trim());
          if (value == null || value < 1 || value > 3600) {
            setState(() => error = s.swipeSeekInvalid);
            return;
          }
          Navigator.pop(dialogContext, value);
        }

        return GlassDialog(
          title: Text(s.swipeSeekCustom),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.swipeSeekCustomBody),
              const SizedBox(height: AppTheme.space16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: '15',
                  suffixText: s.secondsUnit,
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.cancel),
            ),
            FilledButton(onPressed: submit, child: Text(s.save)),
          ],
        );
      },
    ),
  );
}
