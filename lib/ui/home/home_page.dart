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
              topPadding: 72,
              bottomPadding: listBottomInset(context, extra: 0),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  if (!selectionMode)
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      toolbarHeight: 64,
                      titleSpacing: AppTheme.pageMargin + 4,
                      title: _searching
                          ? _SearchField(
                              controller: _searchController,
                              onChanged: library.setQuery,
                            )
                          : Text(
                              context.s.appTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                      actions: [
                        _HeaderIcon(
                          tooltip: _searching
                              ? context.s.closeSearch
                              : context.s.search,
                          icon: _searching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          onPressed: () => _toggleSearch(library),
                        ),
                        if (!_searching) ...[
                          _HeaderIcon(
                            tooltip: context.s.sort,
                            icon: Icons.swap_vert_rounded,
                            onPressed: () =>
                                showSortSheet(context, CollectionKey.home),
                          ),
                          _HeaderIcon(
                            tooltip: library.viewMode == ViewMode.list
                                ? context.s.gridView
                                : context.s.listView,
                            icon: library.viewMode == ViewMode.list
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            onPressed: library.toggleViewMode,
                            filled: true,
                          ),
                        ],
                        const SizedBox(width: AppTheme.pageMargin),
                      ],
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

/// Header action. The view toggle gets a soft filled button so it reads as the
/// primary control, the rest stay as plain dark icons.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!filled) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 24),
        color: theme.colorScheme.onSurface,
        onPressed: onPressed,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: context.s.searchVideos,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          contentPadding: EdgeInsets.zero,
          isDense: true,
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
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageMargin),
        children: [
          for (final entry in filters.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
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

/// Soft rounded pill. Selected gets the pastel wash and a tick; unselected
/// stays a plain light surface.
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

    return Material(
      color: selected ? context.accentWash : theme.colorScheme.surface,
      borderRadius: AppTheme.pillRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.pillRadius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(selected ? 12 : 16, 9, 16, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 17, color: context.accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? theme.colorScheme.onSurface : context.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
