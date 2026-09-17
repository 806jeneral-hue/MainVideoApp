import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../common/empty_state.dart';
import '../common/bottom_fade.dart';
import '../common/drag_select.dart';
import '../common/fast_scroller.dart';
import '../common/glass.dart';
import '../common/tab_header.dart';
import '../common/tab_scroll.dart';
import '../common/selection.dart';
import '../common/video_slivers.dart';
import '../player/player_page.dart';
import '../video/video_actions_sheet.dart';
import 'widgets/library_status_view.dart';
import 'widgets/sort_sheet.dart';
import '../../core/theme/app_icons.dart';

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
                      child: TabHeader(
                        title: context.s.appTitle,
                        searching: _searching,
                        searchController: _searchController,
                        searchHint: context.s.searchVideos,
                        onQueryChanged: library.setQuery,
                        onToggleSearch: () => _toggleSearch(library),
                        onSortAndLayout: () => showSortSheet(
                          context,
                          CollectionKey.home,
                          showViewMode: true,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _FilterRow(
                      selected: filter,
                      showHistory: showHistory,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTheme.space12),
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
      _ => EmptyState(
        icon: AppIcons.movie_outlined,
        title: s.noVideosFound,
        message: s.noVideosFoundBody,
      ),
    };
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
                        AppIcons.check_rounded,
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
