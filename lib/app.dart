import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/haptics.dart';
import 'data/repositories/collection_prefs_repository.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/repositories/history_repository.dart';
import 'data/repositories/playlist_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'state/library_controller.dart';
import 'state/playback_controller.dart';
import 'state/settings_controller.dart';
import 'ui/common/app_background.dart';
import 'ui/shell/home_shell.dart';

class MainVideoApp extends StatelessWidget {
  const MainVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const settingsRepo = SettingsRepository();

    return MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<FavoritesRepository>(
          create: (_) => const FavoritesRepository(),
        ),
        Provider<HistoryRepository>(create: (_) => const HistoryRepository()),
        Provider<PlaylistRepository>(create: (_) => const PlaylistRepository()),
        Provider<CollectionPrefsRepository>(
          create: (_) => const CollectionPrefsRepository(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsController(settingsRepo)),
        ChangeNotifierProvider(
          create: (context) {
            final settings = context.read<SettingsController>();
            final library = LibraryController(
              settings: settingsRepo,
              favorites: context.read<FavoritesRepository>(),
              history: context.read<HistoryRepository>(),
              playlists: context.read<PlaylistRepository>(),
              collectionPrefs: context.read<CollectionPrefsRepository>(),
            );
            // Deleting checks the setting at the moment it runs, so flipping
            // the recycle bin on or off takes effect immediately.
            library.recycleBinEnabled = () => settings.recycleBinEnabled;
            return library..load();
          },
        ),
        // One playback session for the whole app — this is what lets the mini
        // player survive leaving the player screen, and what guarantees a new
        // video replaces the old one instead of playing alongside it.
        ChangeNotifierProvider(
          create: (context) {
            final library = context.read<LibraryController>();
            final playback = PlaybackController(
              settings: context.read<SettingsController>(),
              library: library,
            );
            // Keeps whatever is playing in step with renames and deletions.
            library.onVideoChanged = (oldId, replacement) => playback
                .onLibraryVideoChanged(oldId: oldId, replacement: replacement);
            return playback;
          },
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          // Gesture feedback reads a plain flag rather than the provider, so
          // it can be called from inside a drag handler without a context.
          Haptics.enabled = settings.hapticsEnabled;

          return MaterialApp(
            title: 'Main Video',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(
              settings.accent,
              settings.backgroundImage != null,
            ),
            darkTheme: AppTheme.dark(
              settings.accent,
              settings.backgroundImage != null,
            ),
            builder: (context, child) =>
                AppBackground(child: child ?? const SizedBox.shrink()),
            // A null locale follows the device; Arabic also flips the layout
            // to right-to-left, which Flutter handles through Directionality.
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
