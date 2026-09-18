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
import '../common/glass.dart';
import '../common/empty_state.dart';
import '../common/bottom_fade.dart';
import '../common/drag_select.dart';
import '../common/fast_scroller.dart';
import '../common/tab_scroll.dart';
import '../common/selection.dart';
import '../common/video_slivers.dart';
import '../home/widgets/sort_sheet.dart';
import '../player/mini_player.dart';
import '../settings/settings_button.dart';
import '../player/player_page.dart';
import '../video/video_actions_sheet.dart';
import 'video_picker_page.dart';
import '../../core/theme/app_icons.dart';
import '../common/app_icon.dart';
import '../../state/bookmark_controller.dart';
import '../../data/models/bookmark.dart';
import '../common/quick_menu.dart';
import '../common/play_menus.dart';

/// Which kind of list a [CollectionPage] is showing.
enum CollectionKind { folder, playlist, favorites }

/// One screen for anything that is "a list of videos": a real device folder,
/// a manual playlist, or Favorites. Phase 3 asks for them to behave the same,
/// including the List/Grid switch from phase 2, and each keeps its own sort
/// order — including a custom drag-and-drop one.
class CollectionPage extends StatefulWidget {
  const CollectionPage._({
    required this.kind,
    this.folderPath,
    this.playlistId,
  });

  factory CollectionPage.folder(String path) =>
      CollectionPage._(kind: CollectionKind.folder, folderPath: path);

  factory CollectionPage.playlist(String id) =>
      CollectionPage._(kind: CollectionKind.playlist, playlistId: id);

  factory CollectionPage.favorites() =>
      const CollectionPage._(kind: CollectionKind.favorites);

  final CollectionKind kind;
  final String? folderPath;
  final String? playlistId;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with VideoSelection<CollectionPage> {
  final ScrollController _ownScrollController = ScrollController();

  @override
  void dispose() {
    _ownScrollController.dispose();
    super.dispose();
  }

  CollectionKey get _key => switch (widget.kind) {
    CollectionKind.folder => CollectionKey.folder(widget.folderPath!),
    CollectionKind.playlist => CollectionKey.playlist(widget.playlistId!),
    CollectionKind.favorites => CollectionKey.favorites,
  };

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();

    final playlist = widget.playlistId == null
        ? null
        : library.playlistById(widget.playlistId!);

    final title = switch (widget.kind) {
      CollectionKind.folder =>
        widget.folderPath!
            .split(RegExp(r'[\\/]'))
            .where((s) => s.isNotEmpty)
            .last,
      CollectionKind.playlist => playlist?.name ?? context.s.newPlaylist,
      CollectionKind.favorites => context.s.favorites,
    };

    final videos = switch (widget.kind) {
      CollectionKind.folder => library.videosOfFolder(widget.folderPath!),
      CollectionKind.playlist =>
        playlist == null ? const <Video>[] : library.videosOfPlaylist(playlist),
      CollectionKind.favorites => library.favoriteVideos,
    };
    pruneSelection(videos);

    final prefs = library.prefsFor(_key);
    // As the Favorites tab this uses the shell's controller so re-tapping the
    // tab scrolls to top; pushed as a route it uses its own.
    final scrollController = TabScroll.maybeOf(context) ?? _ownScrollController;

    return Scaffold(
      // The list runs on behind the mini player and fades out above it, the
      // same as on the main tabs.
      extendBody: true,
      appBar: selectionMode
          ? buildSelectionAppBar(
              context: context,
              count: selectedIds.length,
              onClose: clearSelection,
              onSelectAll: () => selectAll(videos),
            )
          : AppBar(
              // As the Favorites tab it carries the settings gear like the
              // other tabs; opened on top of them it keeps its back button.
              leading: TabScroll.isTab(context)
                  ? SettingsButton.leading()
                  : null,
              leadingWidth: TabScroll.isTab(context)
                  ? SettingsButton.leadingWidth
                  : null,
              title: Text(title),
              actions: [
                if (widget.kind == CollectionKind.playlist && playlist != null)
                  HeaderAction(
                    tooltip: context.s.addVideos,
                    icon: const Icon(AppIcons.playlist_add_rounded),
                    onPressed: () async {
                      final picked = await Navigator.of(context)
                          .push<List<String>>(
                            MaterialPageRoute(
                              builder: (_) => VideoPickerPage(
                                title: context.s.addToPlaylistTitle(
                                  playlist.name,
                                ),
                                excluded: playlist.videoIds.toSet(),
                              ),
                            ),
                          );
                      if (picked != null && picked.isNotEmpty) {
                        await library.addToPlaylist(playlist.id, picked);
                      }
                    },
                  ),
                HeaderAction(
                  tooltip: switch (library.nextViewMode) {
                    ViewMode.list => context.s.listView,
                    ViewMode.compact => context.s.compactView,
                    ViewMode.grid => context.s.gridView,
                  },
                  icon: Icon(switch (library.nextViewMode) {
                    ViewMode.list => AppIcons.view_agenda_rounded,
                    ViewMode.compact => AppIcons.view_list_rounded,
                    ViewMode.grid => AppIcons.grid_view_rounded,
                  }),
                  onPressed: library.toggleViewMode,
                ),
                HeaderAction(
                  tooltip: context.s.sort,
                  icon: const AppIcon(AppIcons.swap_vert_rounded),
                  onPressed: () => showSortSheet(context, _key),
                ),
                const SizedBox(width: 16),
              ],
            ),
      bottomNavigationBar: selectionMode
          ? SelectionActionsBar(
              selected: selectedVideos(videos),
              onDone: clearSelection,
              playlistId: widget.kind == CollectionKind.playlist
                  ? widget.playlistId
                  : null,
            )
          // Opened on top of the tabs, this page covers the main mini player,
          // so it carries its own. As the Favorites tab it already has one.
          : (TabScroll.isTab(context)
                ? null
                : const SafeArea(
                    top: false,
                    child: MiniPlayer(aboveNavigation: false),
                  )),
      body: videos.isEmpty
          ? _empty(context, widget.kind)
          : DragSelectArea(
              controller: scrollController,
              armed: dragArmed,
              onHover: addToSelection,
              onEnd: endDragSelection,
              child: BottomFade(
                child: FastScroller(
                  controller: scrollController,
                  bottomPadding: listBottomInset(context, extra: 0),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${context.s.videoCount(videos.length)}  ·  '
                                  '${Fmt.fileSize(videos.fold(0, (s, v) => s + v.sizeBytes))}'
                                  '${prefs.isManual ? "  ·  ${context.s.customOrder}" : ""}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                ),
                              ),
                              Builder(
                                builder: (buttonContext) => TextButton.icon(
                                  // A tap plays in order straight away; holding
                                  // opens the other ways: from the mark, as a
                                  // custom session, shuffled.
                                  onLongPress: () => showQuickMenu(
                                    context,
                                    anchor: anchorOf(buttonContext),
                                    actions: videoPlayActions(
                                      context,
                                      collection: _key,
                                      videos: videos,
                                      title: title,
                                    ),
                                  ),
                                  onPressed: () => _playAll(
                                    context,
                                    videos,
                                    title,
                                    shuffled: false,
                                  ),
                                  icon: const AppIcon(
                                    AppIcons.play_arrow_rounded,
                                    size: 20,
                                  ),
                                  label: Text(context.s.playAll),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      VideoSliver(
                        videos: videos,
                        viewMode: library.viewMode,
                        marker: context.select<BookmarkController, StopMarker?>(
                          (b) => b.markerFor(_key),
                        ),
                        selectionMode: selectionMode,
                        selectedIds: selectedIds,
                        onReorder: prefs.isManual
                            ? (oldIndex, newIndex) => library.reorder(
                                _key,
                                videos,
                                oldIndex,
                                newIndex,
                              )
                            : null,
                        progressOf: (video) => settings.showHistory
                            ? library.historyFor(video.id)?.progress ?? 0
                            : 0,
                        isFavorite: (video) => library.isFavorite(video.id),
                        isPinned: (video) => library.isVideoPinned(video.id),
                        onTap: (video, index) {
                          if (selectionMode) {
                            toggleSelection(video);
                            return;
                          }
                          openPlayer(
                            context,
                            queue: videos,
                            startIndex: index,
                            queueTitle: title,
                            collection: _key,
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
                              queueTitle: title,
                              collection: _key,
                            ),
                            onSelect: () => startSelection(video),
                            collection: _key,
                            onRemoveFromPlaylist:
                                widget.kind == CollectionKind.playlist &&
                                    playlist != null
                                ? () => library.removeFromPlaylist(
                                    playlist.id,
                                    video.id,
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _playAll(
    BuildContext context,
    List<Video> videos,
    String title, {
    required bool shuffled,
  }) {
    openPlayer(
      context,
      queue: videos,
      startIndex: 0,
      queueTitle: title,
      shuffle: shuffled,
      collection: _key,
    );
  }

  Widget _empty(BuildContext context, CollectionKind kind) {
    final s = context.s;
    return switch (kind) {
      CollectionKind.favorites => EmptyState(
        icon: AppIcons.favorite_border_rounded,
        title: s.noFavorites,
        message: s.noFavoritesBody,
      ),
      CollectionKind.playlist => EmptyState(
        icon: AppIcons.queue_music_rounded,
        title: s.emptyPlaylist,
        message: s.emptyPlaylistBody,
      ),
      CollectionKind.folder => EmptyState(
        icon: AppIcons.folder_off_outlined,
        title: s.folderEmpty,
        message: s.folderEmptyBody,
      ),
    };
  }
}
