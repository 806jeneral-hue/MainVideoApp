import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../data/services/pip_service.dart';
import '../../state/library_controller.dart';
import '../../state/music_controller.dart';
import '../../state/playback_controller.dart';
import '../favorites/favorites_page.dart';
import '../folders/folders_page.dart';
import '../home/home_page.dart';
import '../music/music_page.dart';
import '../common/tab_scroll.dart';
import '../player/mini_player.dart';
import 'app_bottom_nav.dart';
import 'nav_glyphs.dart';

/// Bottom navigation: Home / Folders / Favorites / Music, with the mini player
/// docked above it. Settings open from the gear in each tab's header.
///
/// This is also the app's long-lived host for things that outlive any one
/// screen: the lifecycle observer that pauses playback, the PiP channel, and
/// the incremental rescan that runs when the app comes back to the foreground.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  /// A tab is built the first time it is opened and kept alive afterwards, so
  /// startup only pays for Home instead of filtering and sorting the library
  /// four times before the first frame.
  final Set<int> _visited = {0};

  /// One scroll controller per tab, owned here so that tapping the tab you are
  /// already on can send its list back to the top.
  final List<ScrollController> _scrollControllers = List.generate(
    4,
    (_) => ScrollController(),
  );

  static const _pages = [
    HomePage(),
    FoldersPage(),
    FavoritesPage(),
    MusicPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    PipService.ensureWired();
    // Notification buttons and audio focus reach playback through here.
    context.read<PlaybackController>().bindBackgroundService();
    PipService.onPipChanged = (inPip) =>
        context.read<PlaybackController>().setPipState(inPip);
    PipService.onUserLeaveHint = () {
      final playback = context.read<PlaybackController>();
      // Picture-in-picture is for a video being watched, never for music.
      if (playback.isFullscreen &&
          playback.isPlaying &&
          !playback.isAudio &&
          playback.settings.pipEnabled) {
        playback.enterPip();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.onPipChanged = null;
    PipService.onUserLeaveHint = null;
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int value) {
    // Tapping the tab you are already on takes that list back to the top.
    if (value == _index) {
      scrollToTop(_scrollControllers[value]);
      return;
    }
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      context.read<PlaybackController>().handleAppPaused();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Picks up anything recorded or downloaded while the app was away,
      // without re-reading the whole device.
      context.read<LibraryController>().syncNewVideos();
      context.read<MusicController>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lists run the full height of the screen and pass behind the floating
      // bar, fading out as they reach it, instead of stopping above it.
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pages.length; i++)
            if (_visited.contains(i))
              TabScroll(controller: _scrollControllers[i], child: _pages[i])
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            AppBottomNav(
              currentIndex: _index,
              onSelected: _onTabSelected,
              items: [
                NavItem(glyph: NavGlyphKind.home, label: context.s.navHome),
                NavItem(
                  glyph: NavGlyphKind.folder,
                  label: context.s.navFolders,
                ),
                NavItem(
                  glyph: NavGlyphKind.heart,
                  label: context.s.navFavorites,
                ),
                NavItem(glyph: NavGlyphKind.music, label: context.s.navMusic),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
