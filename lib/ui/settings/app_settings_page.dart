import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_localizations.dart';
import '../../state/library_controller.dart';
import '../../data/services/background_image_service.dart';
import '../../state/settings_controller.dart';
import 'about_page.dart';
import 'playback_settings_page.dart';
import 'hidden_videos_page.dart';
import 'recycle_bin_page.dart';
import 'scan_folders_page.dart';
import 'widgets/settings_tiles.dart';
import '../common/glass_dialog.dart';
import '../common/glass_controls.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';
import '../common/default_backdrop.dart';
import '../common/glass.dart';
import '../../data/models/enums.dart';

/// Phase 7 — the general settings screen that gathers appearance, history,
/// and links out to the playback and folder screens.
class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.watch<LibraryController>();

    return Scaffold(
      appBar: AppBar(title: Text(context.s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
        children: [
          SettingsSection(context.s.appearance),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: AppIcons.dark_mode_outlined,
                title: context.s.darkMode,
                subtitle: context.s.darkModeBody,
                value: settings.isDark,
                onChanged: settings.toggleDarkMode,
              ),
              SettingsSwitch(
                icon: AppIcons.brightness_auto_rounded,
                title: context.s.followSystemTheme,
                subtitle: context.s.followSystemThemeBody,
                value: settings.themeMode == ThemeMode.system,
                onChanged: (value) => settings.setThemeMode(
                  value ? ThemeMode.system : ThemeMode.light,
                ),
              ),
              SettingsTile(
                icon: AppIcons.translate_rounded,
                title: context.s.language,
                subtitle: context.s.languageBody,
                trailing: Text(
                  settings.localeCode == null
                      ? context.s.systemLanguage
                      : AppLocalizations.stringsFor(
                          Locale(settings.localeCode!),
                        ).languageName,
                  style: TextStyle(
                    color: context.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickLanguage(context, settings),
              ),
            ],
          ),
          SettingsSection(context.s.appStyle),
          _StylePicker(settings: settings),
          SettingsSection(context.s.accentColor),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.s.accentColorBody,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in AccentPalette.options)
                        _AccentSwatch(
                          option: option,
                          selected: settings.accentKey == option.key,
                          onTap: () => settings.setAccentKey(option.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Only the glass look has glass to thin out.
          if (settings.appStyle == AppStyle.glass)
            _GlassCard(settings: settings),
          SettingsSection(context.s.backgroundImage),
          _BackgroundCard(settings: settings),
          SettingsSection(context.s.history),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: AppIcons.history_rounded,
                title: context.s.showWatchHistory,
                subtitle: context.s.showWatchHistoryBody,
                value: settings.showHistory,
                onChanged: settings.setShowHistory,
              ),
              SettingsTile(
                icon: AppIcons.delete_sweep_outlined,
                title: context.s.clearWatchHistory,
                subtitle: context.s.clearWatchHistoryBody,
                destructive: true,
                onTap: () => _confirmClearHistory(context, library),
              ),
            ],
          ),
          SettingsSection(context.s.playback),
          SettingsCard(
            children: [
              SettingsTile(
                icon: AppIcons.play_circle_outline_rounded,
                title: context.s.playbackSettings,
                subtitle: context.s.playbackSettingsBody,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlaybackSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(context.s.folders),
          SettingsCard(
            children: [
              SettingsTile(
                icon: AppIcons.rule_folder_outlined,
                title: context.s.foldersToScan,
                subtitle: library.scanFolders.isEmpty
                    ? context.s.allFoldersHidden(library.hiddenFolders.length)
                    : context.s.selectedFoldersHidden(
                        library.scanFolders.length,
                        library.hiddenFolders.length,
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanFoldersPage()),
                ),
              ),
              SettingsTile(
                icon: AppIcons.refresh_rounded,
                title: context.s.rescanDevice,
                subtitle: context.s.videoCount(library.allVideos.length),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final message = context.s.libraryRescanned;
                  await library.refresh();
                  messenger.showSnackBar(glassSnackBar(content: Text(message)));
                },
              ),
            ],
          ),
          SettingsSection(context.s.recycleBin),
          SettingsCard(
            children: [
              SettingsSwitch(
                icon: AppIcons.restore_from_trash_rounded,
                title: context.s.recycleBinToggle,
                subtitle: context.s.recycleBinToggleBody,
                value: settings.recycleBinEnabled,
                onChanged: settings.setRecycleBinEnabled,
              ),
              SettingsTile(
                icon: AppIcons.delete_outline_rounded,
                title: context.s.recycleBin,
                subtitle: context.s.binCount(library.recycleBinCount),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecycleBinPage()),
                ),
              ),
              SettingsTile(
                icon: AppIcons.visibility_off_outlined,
                title: context.s.hiddenVideos,
                subtitle: library.hiddenVideoCount == 0
                    ? context.s.hiddenVideosBody
                    : context.s.hiddenCount(library.hiddenVideoCount),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HiddenVideosPage()),
                ),
              ),
            ],
          ),
          SettingsSection(context.s.about),
          SettingsCard(
            children: [
              SettingsTile(
                icon: AppIcons.info_outline_rounded,
                title: context.s.aboutApp,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// System / English / Arabic. Switching to Arabic also flips the whole
  /// interface to right-to-left.
  Future<void> _pickLanguage(
    BuildContext context,
    SettingsController settings,
  ) {
    final options = <String?>[
      null,
      ...AppLocalizations.supportedLocales.map((l) => l.languageCode),
    ];

    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.s.language,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final code in options)
              GlassTile(
                leading: Icon(
                  code == null
                      ? AppIcons.phone_android_rounded
                      : AppIcons.translate_rounded,
                  color: settings.localeCode == code ? context.accent : null,
                ),
                title: Text(
                  code == null
                      ? context.s.systemLanguage
                      : AppLocalizations.stringsFor(Locale(code)).languageName,
                ),
                selected: settings.localeCode == code,
                trailing: settings.localeCode == code
                    ? Icon(AppIcons.check_rounded, color: context.accent)
                    : null,
                onTap: () {
                  settings.setLocaleCode(code);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    LibraryController library,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.s.historyCleared;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: Text(context.s.clearHistoryConfirmTitle),
        content: Text(context.s.clearHistoryConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.s.clear),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await library.clearHistory();
    messenger.showSnackBar(glassSnackBar(content: Text(done)));
  }
}

/// One colour in the accent picker.
/// Background picture: a preview, choose / remove, and how soft it is.
/// The two looks side by side, each as a small picture of itself.
class _StylePicker extends StatelessWidget {
  const _StylePicker({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.appStyleBody,
              style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: _StyleOption(
                    label: s.styleGlass,
                    selected: settings.appStyle == AppStyle.glass,
                    preview: const _StylePreview(solid: false),
                    onTap: () => settings.setAppStyle(AppStyle.glass),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: _StyleOption(
                    label: s.styleSolid,
                    selected: settings.appStyle == AppStyle.solid,
                    preview: const _StylePreview(solid: true),
                    onTap: () => settings.setAppStyle(AppStyle.solid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(aspectRatio: 0.78, child: preview),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(AppIcons.check_circle_rounded, size: 16, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : context.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny drawing of a look — its page, a title, three rows and the bar — in
/// the current light or dark mode, so the choice can be seen before it is made.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.solid});

  final bool solid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = solid ? const Color(0xFFF2782B) : context.accent;

    final page = solid
        ? (isDark ? const Color(0xFF131417) : const Color(0xFFFAF5EF))
        : (isDark ? const Color(0xFF151A28) : const Color(0xFFEEEAF1));
    final card = solid
        ? AppTheme.solidCard(isDark)
        : Colors.white.withValues(alpha: isDark ? 0.10 : 0.55);
    final edge = solid
        ? Colors.transparent
        : Colors.white.withValues(alpha: isDark ? 0.25 : 0.9);
    final line = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    Widget row({bool marked = false}) => Container(
      height: 20,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: edge, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            color: marked && solid ? accent : Colors.transparent,
          ),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 3, color: line)),
          const SizedBox(width: 6),
          Container(
            width: 20,
            height: 13,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3D45) : const Color(0xFFD8D2CC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: page,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page,
                  Color.alphaBlend(accent.withValues(alpha: 0.25), page),
                ],
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (solid) ...[
                  Container(width: 3, height: 10, color: accent),
                  const SizedBox(width: 3),
                ],
                Container(width: 28, height: 5, color: line),
                const Spacer(),
                Container(
                  width: 22,
                  height: 9,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            row(marked: true),
            row(),
            row(),
            const Spacer(),
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: edge, width: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How solid the app's glass is, on a plain slider so it can be felt rather
/// than picked from steps.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.glassStrengthBody,
              style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
            ),
            Row(
              children: [
                Icon(AppIcons.blur_on_rounded, size: 20, color: context.muted),
                const SizedBox(width: AppTheme.space8),
                Text(s.glassStrength, style: theme.textTheme.bodyMedium),
                Expanded(
                  child: Slider(
                    value: settings.glassStrength,
                    onChanged: settings.setGlassStrength,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  const _BackgroundCard({required this.settings});

  final SettingsController settings;

  Future<void> _choose() async {
    final path = await BackgroundImageService.pick();
    if (path != null) await settings.setBackgroundImage(path);
  }

  Future<void> _remove() async {
    await settings.setBackgroundImage(null);
    await BackgroundImageService.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final path = settings.backgroundImage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.backgroundImageBody,
              style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
            ),
            const SizedBox(height: AppTheme.space16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: AppTheme.thumbRadius,
                  child: SizedBox(
                    width: 64,
                    height: 96,
                    child: path == null
                        ? const DefaultBackdrop()
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Wrap(
                    spacing: AppTheme.space8,
                    runSpacing: AppTheme.space8,
                    children: [
                      FilledButton.icon(
                        onPressed: _choose,
                        icon: const Icon(AppIcons.photo_library_outlined),
                        label: Text(
                          path == null ? s.chooseImage : s.changeImage,
                        ),
                      ),
                      if (path != null)
                        TextButton(
                          onPressed: _remove,
                          child: Text(s.removeImage),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (path != null) ...[
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Icon(
                    AppIcons.blur_on_rounded,
                    size: 20,
                    color: context.muted,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(s.backgroundBlur, style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: settings.backgroundBlur,
                      max: 40,
                      onChanged: settings.setBackgroundBlur,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = option.swatch(theme.brightness);

    return Tooltip(
      message: context.s.accentName(option.key),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                : null,
          ),
          child: selected
              ? Icon(
                  AppIcons.check_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
