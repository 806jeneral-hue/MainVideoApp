import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../common/bottom_fade.dart';
import 'about_page.dart';
import 'app_settings_page.dart';
import 'playback_settings_page.dart';
import 'scan_folders_page.dart';
import 'widgets/settings_tiles.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';

/// The settings hub, opened from the gear in the header of every main tab:
/// the library summary, the scan and rescan controls, and the way into
/// playback settings, app settings and About.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text(context.s.settings)),
      body: BottomFade(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, 6, 14, listBottomInset(context)),
          children: [
            _LibrarySummary(
              videos: library.allVideos.length,
              folders: library.allFolders.length,
              favorites: library.favoriteVideos.length,
            ),
            SettingsSection(context.s.library),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: AppIcons.rule_folder_outlined,
                  title: context.s.foldersToScan,
                  subtitle: library.scanFolders.isEmpty
                      ? context.s.all
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
                  subtitle: context.s.rescanDeviceBody,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final message = context.s.libraryRescanned;
                    await library.refresh();
                    messenger.showSnackBar(
                      glassSnackBar(content: Text(message)),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(context.s.settings),
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
                SettingsTile(
                  icon: AppIcons.tune_rounded,
                  title: context.s.appSettings,
                  subtitle: context.s.appearance,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AppSettingsPage()),
                  ),
                ),
                SettingsSwitch(
                  icon: AppIcons.dark_mode_outlined,
                  title: context.s.darkMode,
                  value: settings.isDark,
                  onChanged: settings.toggleDarkMode,
                ),
              ],
            ),
            SettingsSection(context.s.about),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: AppIcons.info_outline_rounded,
                  title: context.s.aboutApp,
                  subtitle: context.s.version(AboutPage.version),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.videos,
    required this.folders,
    required this.favorites,
  });

  final int videos;
  final int folders;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            _Stat(value: videos, label: context.s.statVideos),
            _Divider(),
            _Stat(value: folders, label: context.s.folders),
            _Divider(),
            _Stat(value: favorites, label: context.s.favorites),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
