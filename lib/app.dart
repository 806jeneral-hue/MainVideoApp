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
import 'state/music_controller.dart';
import 'state/playback_controller.dart';
import 'state/settings_controller.dart';
import 'ui/common/app_background.dart';
import 'ui/shell/home_shell.dart';
import 'ui/common/bottom_fade.dart';

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
        // The music library reads nothing until the Music tab is first opened.
        ChangeNotifierProvider(create: (_) => MusicController()),
        // One playback session for the whole app — this is what lets the mini
        // player survive leaving the player screen, and what guarantees a new
        // video replaces the old one instead of playing alongside it.
        ChangeNotifierProvider(
          create: (context) {
            final library = context.read<LibraryController>();
            final playback = PlaybackController(
              settings: context.read<SettingsController>(),
              library: library,
              music: context.read<MusicController>(),
            );
            // Keeps whatever is playing in step with renames and deletions.
            library.onVideoChanged = (oldId, replacement) => playback
                .onLibraryVideoChanged(oldId: oldId, replacement: replacement);
            // A song deleted from the Music tab leaves the queue the same way.
            context.read<MusicController>().onSongDeleted = (id) =>
                playback.onLibraryVideoChanged(oldId: id);
            return playback;
          },
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          // Gesture feedback reads a plain flag rather than the provider, so
          // it can be called from inside a drag handler without a context.
          Haptics.enabled = settings.hapticsEnabled;
          // Read while painting glass, so it cannot go through the theme.
          AppTheme.glassStrength = settings.glassStrength;

          return MaterialApp(
            title: 'Main Video',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            // Pages are always see-through: behind them is either the chosen
            // picture or the app's own backdrop.
            theme: AppTheme.light(settings.accent, true),
            darkTheme: AppTheme.dark(settings.accent, true),
            builder: (context, child) => SystemBottomInset(
              // Read here, above every route, where it is still the phone's
              // own inset rather than the height of a Scaffold's bottom bars.
              value: MediaQuery.paddingOf(context).bottom,
              child: AppBackground(child: child ?? const SizedBox.shrink()),
            ),
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
