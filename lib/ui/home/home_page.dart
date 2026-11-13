import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/services/recent_searches_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/app_database.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../../data/services/archive_playback_service.dart';
import '../../data/services/permission_service.dart';
import '../../state/bookmark_controller.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../common/app_search_bar.dart';
import '../common/bottom_fade.dart';
import '../common/drag_select.dart';
import '../common/empty_state.dart';
import '../common/fast_scroller.dart';
import '../common/glass.dart';
import '../common/selection.dart';
import '../common/tab_header.dart';
import '../common/tab_scroll.dart';
import '../common/video_slivers.dart';
import '../player/player_page.dart';
import '../video/video_actions_sheet.dart';
import 'widgets/library_status_view.dart';
import 'widgets/sort_sheet.dart';

/// Quick filters standing in for the Recently Added / Recently Played /
/// Archives sections of phase 6.
enum HomeFilter { all, recentlyAdded, recentlyPlayed, archives }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with VideoSelection<HomePage> {
  final ScrollController _ownScrollController = ScrollController();
  HomeFilter _filter = HomeFilter.all;

  /// Single source of truth for whether search is open.
  /// Governs both the header icon and the search bar.
  bool _isSearchOpen = false;

  final GlobalKey<AppSearchBarState> _searchBarKey =
      GlobalKey<AppSearchBarState>();

  AppSearchBarState? get _searchBar => _searchBarKey.currentState;

  @override
  void dispose() {
    _ownScrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- helpers

  List<Video> _videosFor(LibraryController library, HomeFilter filter) {
    final videos = switch (filter) {
      HomeFilter.all => library.homeVideos,
      HomeFilter.recentlyAdded => library.recentlyAdded,
      HomeFilter.recentlyPlayed => library.recentlyPlayed,
      HomeFilter.archives =>
        library.homeVideos.where((v) => v.isArchive).toList(),
    };
    // homeVideos already applies the search; the other two are raw lists.
    if (filter == HomeFilter.all || library.query.trim().isEmpty) return videos;
    return library.filterByQuery(videos, library.query);
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final showHistory = settings.showHistory;

    if (library.status != LibraryStatus.ready) {
      return Scaffold(
        appBar: AppBar(title: Text(context.s.appTitle)),
        body: const LibraryStatusView(),
      );
    }

    final filter = (!showHistory && _filter == HomeFilter.recentlyPlayed)
        ? HomeFilter.all
        : _filter;
    final videos = _videosFor(library, filter);
    pruneSelection(videos);

    final prefs = library.prefsFor(CollectionKey.home);
    final scrollController =
        TabScroll.maybeOf(context) ?? _ownScrollController;

    // Update the shell's selection bar whenever the selection state changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabSelectionBridge.set(
        context,
        selectionMode
            ? SelectionActionsBar(
                key: const ValueKey('home_selection_actions_bar'),
                selected: selectedVideos(videos),
                onDone: clearSelection,
              )
            : null,
      );
    });

    final searchBar = AppSearchBar(
      key: _searchBarKey,
      isOpen: _isSearchOpen,
      hint: context.s.searchVideos,
      initialQuery: library.query,
      recentStorageKey: SettingsKeys.recentVideoSearches,
      onChanged: library.setQuery,
      onClosed: () {
        setState(() => _isSearchOpen = false);
        library.clearQuery();
      },
    );

    return PopScope(
      canPop: !_isSearchOpen && !selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (selectionMode) {
          clearSelection();
          return;
        }
        _searchBar?.handlePop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: RefreshIndicator(
          color: context.accent,
          onRefresh: library.refresh,
          child: DragSelectArea(
            controller: scrollController,
            armed: dragArmed,
            selectionMode: selectionMode,
            onLongPressStart: (id, index) {
              if (index >= 0 && index < videos.length) {
                startSelection(videos[index], index, videos);
              }
            },
            onHover: (id, index) {
              final width = MediaQuery.sizeOf(context).width;
              final gridCols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
              final cols =
                  library.viewMode == ViewMode.grid ? gridCols : 1;
              addToSelection(id, index, videos, cols);
            },
            onEnd: endDragSelection,
            child: BottomFade(
              child: FastScroller(
                controller: scrollController,
                topPadding: MediaQuery.paddingOf(context).top + 76,
                bottomPadding: listBottomInset(context, extra: 0),
                child: CustomScrollView(
                  key: const PageStorageKey('home_video_scroll'),
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: TabHeader(
                        title: context.s.appTitle,
                        searchOpen: _isSearchOpen,
                        searchBarSlot: searchBar,
                        onToggleSearch: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              library.clearQuery();
                            }
                          });
                        },
                        onSortAndLayout: () => showSortSheet(
                          context,
                          CollectionKey.home,
                          showViewMode: true,
                        ),
                        selectionMode: selectionMode,
                        selectedCount: selectedIds.length,
                        totalCount: videos.length,
                        onCloseSelection: clearSelection,
                        onSelectAll: () => selectAll(videos),
                        onDeselectAll: deselectAll,
                        onToggleViewMode: library.toggleViewMode,
                        currentViewMode: library.viewMode,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: selectionMode
                            ? const SizedBox(width: double.infinity)
                            : _FilterRow(
                                selected: filter,
                                showHistory: showHistory,
                                onChanged: (value) =>
                                    setState(() => _filter = value),
                              ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: selectionMode
                            ? AppTheme.space4
                            : AppTheme.space12,
                      ),
                    ),
                    if (videos.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyFor(context, filter, library),
                      )
                    else
                      VideoSliver(
                        videos: videos,
                        searchQuery: library.query,
                        viewMode: library.viewMode,
                        marker: context
                            .select<BookmarkController, StopMarker?>(
                              (b) => b.markerFor(CollectionKey.home),
                            ),
                        selectionMode: selectionMode,
                        selectedIds: selectedIds,
                        onReorder:
                            prefs.isManual &&
                                    filter == HomeFilter.all &&
                                    library.query.isEmpty
                                ? (oldIndex, newIndex) => library.reorder(
                                    CollectionKey.home,
                                    videos,
                                    oldIndex,
                                    newIndex,
                                  )
                                : null,
                        progressOf: (video) => showHistory
                            ? library.historyFor(video.id)?.progress ?? 0
                            : 0,
                        isFavorite: (video) =>
                            library.isFavorite(video.id),
                        isPinned: (video) =>
                            library.isVideoPinned(video.id),
                        subtitleOf: filter == HomeFilter.recentlyPlayed &&
                                showHistory
                            ? (video) {
                                final record =
                                    library.historyFor(video.id);
                                if (record == null) return video.folderName;
                                return '${Fmt.relativeDate(record.lastPlayed, context.s)}  ·  ${video.folderName}';
                              }
                            : null,
                        onTap: (video, index) {
                          // Hide keyboard before opening player.
                          _searchBar?.hideKeyboard();
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (library.query.trim().isNotEmpty) {
                            RecentSearchesService.addRecent(
                              SettingsKeys.recentVideoSearches,
                              library.query.trim(),
                            );
                          }
                          if (selectionMode) {
                            toggleSelection(video);
                            return;
                          }
                          if (video.isArchive) {
                            ArchivePlaybackService.openArchiveAndPlay(
                              context,
                              video.path,
                            );
                            return;
                          }
                          final nonArchiveVideos = videos
                              .where((v) => !v.isArchive)
                              .toList();
                          openPlayer(
                            context,
                            queue: nonArchiveVideos,
                            startIndex: nonArchiveVideos
                                .indexOf(video)
                                .clamp(0, nonArchiveVideos.length - 1),
                            queueTitle: _titleFor(filter),
                            collection: CollectionKey.home,
                          );
                        },
                        onMore: (video) {
                          if (selectionMode) {
                            toggleSelection(video);
                            return;
                          }
                          showVideoActions(
                            context,
                            video,
                            onPlay: () {
                              if (video.isArchive) {
                                ArchivePlaybackService.openArchiveAndPlay(
                                  context,
                                  video.path,
                                );
                              } else {
                                openPlayer(
                                  context,
                                  queue: videos
                                      .where((v) => !v.isArchive)
                                      .toList(),
                                  startIndex: videos
                                      .where((v) => !v.isArchive)
                                      .toList()
                                      .indexOf(video),
                                  queueTitle: _titleFor(filter),
                                  collection: CollectionKey.home,
                                );
                              }
                            },
                            onSelect: () => startSelection(
                              video,
                              videos.indexOf(video),
                              videos,
                            ),
                            collection: CollectionKey.home,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleFor(HomeFilter filter) => switch (filter) {
        HomeFilter.all => context.s.allVideos,
        HomeFilter.recentlyAdded => context.s.filterRecentlyAdded,
        HomeFilter.recentlyPlayed => context.s.filterRecentlyPlayed,
        HomeFilter.archives => 'المضغوطة',
      };

  Widget _emptyFor(
    BuildContext context,
    HomeFilter filter,
    LibraryController library,
  ) {
    final s = context.s;
    if (library.query.isNotEmpty) {
      return EmptyState(
        icon: AppIcons.search_off_rounded,
        title: s.nothingFound,
        message: s.noVideoMatches(library.query),
      );
    }
    return switch (filter) {
      HomeFilter.recentlyPlayed => EmptyState(
          icon: AppIcons.history_rounded,
          title: s.nothingWatchedYet,
          message: s.nothingWatchedYetBody,
        ),
      HomeFilter.archives => EmptyState(
          icon: Icons.folder_zip_rounded,
          title: 'لا توجد ملفات مضغوطة ظاهرة',
          message:
              'لتصفح وتشغيل ملفات ZIP و RAR تلقائياً، تأكد من منح صلاحية قراءة الملفات',
          action: FilledButton.icon(
            onPressed: () async {
              await PermissionService.requestManageStorage();
              await library.refresh();
            },
            icon: const Icon(Icons.security_update_good_rounded, size: 18),
            label: const Text('تفعيل إذن الوصول للملفات'),
          ),
        ),
      _ => EmptyState(
          icon: AppIcons.movie_outlined,
          title: s.noVideosFound,
          message: s.noVideosFoundBody,
        ),
    };
  }
}

// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onChanged,
    required this.showHistory,
  });

  final HomeFilter selected;
  final ValueChanged<HomeFilter> onChanged;
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    final filters = <HomeFilter, String>{
      HomeFilter.all: context.s.filterAll,
      HomeFilter.recentlyAdded: context.s.filterRecentlyAdded,
      if (showHistory)
        HomeFilter.recentlyPlayed: context.s.filterRecentlyPlayed,
      HomeFilter.archives: 'المضغوطة',
    };

    return SizedBox(
      height: 50,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: AlignmentDirectional.centerStart.resolve(
            Directionality.of(context),
          ),
          end: AlignmentDirectional.centerEnd.resolve(
            Directionality.of(context),
          ),
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 1 - 20 / bounds.width.clamp(40, double.infinity), 1],
        ).createShader(bounds),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTheme.pageMargin,
            AppTheme.space4,
            AppTheme.space8,
            AppTheme.space8,
          ),
          clipBehavior: Clip.hardEdge,
          children: [
            for (final entry in filters.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppTheme.space8),
                child: _FilterPill(
                  label: entry.value,
                  selected: selected == entry.key,
                  onTap: () => onChanged(entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;

    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.pillRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(
                    AppIcons.check_circle_rounded,
                    size: 16,
                    color: onAccent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 13,
                    color: selected ? onAccent : context.muted,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return PressScale(
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppTheme.pillRadius,
                color: accent.withValues(
                  alpha: AppTheme.isSolid ? 1 : 0.72,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: content,
            )
          : GlassSurface(radius: AppTheme.pillRadius, child: content),
    );
  }
}
