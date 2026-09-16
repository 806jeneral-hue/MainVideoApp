import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../common/empty_state.dart';
import '../common/bottom_fade.dart';
import '../common/drag_select.dart';
import '../common/fast_scroller.dart';
import '../common/glass.dart';
import '../common/tab_scroll.dart';
import '../common/selection.dart';
import '../common/video_slivers.dart';
import '../player/player_page.dart';
import '../video/video_actions_sheet.dart';
import 'widgets/library_status_view.dart';
import 'widgets/sort_sheet.dart';

/// Quick filters standing in for the Recently Added / Recently Played
/// sections of phase 6.
enum HomeFilter { all, recentlyAdded, recentlyPlayed }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with VideoSelection<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _ownScrollController = ScrollController();
  bool _searching = false;
  HomeFilter _filter = HomeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    _ownScrollController.dispose();
    super.dispose();
  }

  void _toggleSearch(LibraryController library) {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      library.clearQuery();
    }
  }

  List<Video> _videosFor(LibraryController library, HomeFilter filter) {
    final videos = switch (filter) {
      HomeFilter.all => library.homeVideos,
      HomeFilter.recentlyAdded => library.recentlyAdded,
      HomeFilter.recentlyPlayed => library.recentlyPlayed,
    };
    // homeVideos already applies the search; the other two are raw lists.
    final q = library.query.trim().toLowerCase();
    if (filter == HomeFilter.all || q.isEmpty) return videos;
    return videos.where((v) => v.title.toLowerCase().contains(q)).toList();
  }

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

    // The history filter is meaningless while history is switched off.
    final filter = (!showHistory && _filter == HomeFilter.recentlyPlayed)
        ? HomeFilter.all
        : _filter;
    final videos = _videosFor(library, filter);
    pruneSelection(videos);

    final prefs = library.prefsFor(CollectionKey.home);
    // The shell owns a controller per tab so re-tapping Home scrolls to top;
    // fall back to our own if this page is ever shown outside a tab.
    final scrollController = TabScroll.maybeOf(context) ?? _ownScrollController;

    return Scaffold(
      appBar: selectionMode
          ? buildSelectionAppBar(
              context: context,
              count: selectedIds.length,
              onClose: clearSelection,
              onSelectAll: () => selectAll(videos),
            )
          : null,
      bottomNavigationBar: selectionMode
          ? SelectionActionsBar(
              selected: selectedVideos(videos),
              onDone: clearSelection,
            )
          : null,
      body: RefreshIndicator(
        color: context.accent,
        onRefresh: library.refresh,
        child: DragSelectArea(
          controller: scrollController,
          armed: dragArmed,
          onHover: addToSelection,
          onEnd: endDragSelection,
          child: BottomFade(
            child: FastScroller(
              controller: scrollController,
              // Starts below the floating header buttons.
              topPadding: MediaQuery.paddingOf(context).top + 76,
              bottomPadding: listBottomInset(context, extra: 0),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  if (!selectionMode)
                    SliverToBoxAdapter(
                      child: _Header(
                        searching: _searching,
                        searchController: _searchController,
                        onQueryChanged: library.setQuery,
                        onToggleSearch: () => _toggleSearch(library),
                        onSort: () =>
                            showSortSheet(context, CollectionKey.home),
                        viewMode: library.viewMode,
                        onToggleView: library.toggleViewMode,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _FilterRow(
                      selected: filter,
                      showHistory: showHistory,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pageMargin + 4,
                        4,
                        AppTheme.pageMargin + 4,
                        12,
                      ),
                      child: Text(
                        _subtitleFor(
                          context,
                          filter,
                          videos.length,
                          library,
                          prefs,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                      viewMode: library.viewMode,
                      selectionMode: selectionMode,
                      selectedIds: selectedIds,
                      // Custom order only applies to the unfiltered, unsearched list.
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
                      isFavorite: (video) => library.isFavorite(video.id),
                      isPinned: (video) => library.isVideoPinned(video.id),
                      subtitleOf:
                          filter == HomeFilter.recentlyPlayed && showHistory
                          ? (video) {
                              final record = library.historyFor(video.id);
                              if (record == null) return video.folderName;
                              return '${Fmt.relativeDate(record.lastPlayed, context.s)}  ·  ${video.folderName}';
                            }
                          : null,
                      onTap: (video, index) {
                        if (selectionMode) {
                          toggleSelection(video);
                          return;
                        }
                        openPlayer(
                          context,
                          queue: videos,
                          startIndex: index,
                          queueTitle: _titleFor(filter),
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
                          onPlay: () => openPlayer(
                            context,
                            queue: videos,
                            startIndex: videos.indexOf(video),
                            queueTitle: _titleFor(filter),
                          ),
                          onSelect: () => startSelection(video),
                        );
                      },
                    ),
                ],
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
  };

  String _subtitleFor(
    BuildContext context,
    HomeFilter filter,
    int count,
    LibraryController library,
    CollectionPrefs prefs,
  ) {
    final s = context.s;
    if (library.isScanning) return s.stillScanning(s.videoCount(count));
    if (library.query.isNotEmpty) {
      return s.matchingQuery(s.videoCount(count), library.query);
    }
    return switch (filter) {
      HomeFilter.all => s.sortedBy(
        s.videoCount(count),
        prefs.sortField.label(s).toLowerCase(),
      ),
      HomeFilter.recentlyAdded => s.newestOnDevice,
      HomeFilter.recentlyPlayed => s.pickUpWhereYouLeftOff,
    };
  }

  Widget _emptyFor(
    BuildContext context,
    HomeFilter filter,
    LibraryController library,
  ) {
    final s = context.s;
    if (library.query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: s.nothingFound,
        message: s.noVideoMatches(library.query),
      );
    }
    return switch (filter) {
      HomeFilter.recentlyPlayed => EmptyState(
        icon: Icons.history_rounded,
        title: s.nothingWatchedYet,
        message: s.nothingWatchedYetBody,
      ),
      _ => EmptyState(
        icon: Icons.movie_outlined,
        title: s.noVideosFound,
        message: s.noVideosFoundBody,
      ),
    };
  }
}

/// Clean media-app header: floating glass actions on one row, the large
/// screen title under them. Search grows out of the same spot as the title,
/// so opening it feels like the header changing shape rather than a new bar.
class _Header extends StatelessWidget {
  const _Header({
    required this.searching,
    required this.searchController,
    required this.onQueryChanged,
    required this.onToggleSearch,
    required this.onSort,
    required this.viewMode,
    required this.onToggleView,
  });

  final bool searching;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback onSort;
  final ViewMode viewMode;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        MediaQuery.paddingOf(context).top + AppTheme.space12,
        AppTheme.pageMargin,
        AppTheme.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GlassIconButton(
                tooltip: viewMode == ViewMode.list ? s.gridView : s.listView,
                icon: viewMode == ViewMode.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_rounded,
                onPressed: onToggleView,
              ),
              const Spacer(),
              GlassIconButton(
                tooltip: s.sort,
                icon: Icons.swap_vert_rounded,
                onPressed: onSort,
              ),
              const SizedBox(width: AppTheme.space12),
              GlassIconButton(
                tooltip: searching ? s.closeSearch : s.search,
                icon: searching ? Icons.close_rounded : Icons.search_rounded,
                selected: searching,
                onPressed: onToggleSearch,
              ),
            ],
          ),
          // No screen title: the space goes to the videos. Search opens here,
          // under the buttons, only while it is in use.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: searching
                ? Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space16),
                    child: _SearchField(
                      controller: searchController,
                      onChanged: onQueryChanged,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Glass search field. Wired to the same query the library already filters
/// by — this only changes how it looks.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      radius: AppTheme.pillRadius,
      floating: true,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: context.s.searchVideos,
          filled: false,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

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
    };

    return SizedBox(
      // Tall enough that the pills' shadows are not cut off by the list.
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pageMargin,
          AppTheme.space4,
          AppTheme.pageMargin,
          AppTheme.space8,
        ),
        clipBehavior: Clip.none,
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
    );
  }
}

/// Glass pill. The selected one is tinted with the accent and carries a tick;
/// the rest stay quiet.
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

    return PressScale(
      child: GlassSurface(
        radius: AppTheme.pillRadius,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTheme.pillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space20,
                vertical: 11,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? theme.colorScheme.onSurface
                            : context.muted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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
}
