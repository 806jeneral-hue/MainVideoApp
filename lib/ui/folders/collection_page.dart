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
import '../common/app_sheet.dart';
import '../common/fast_scroller.dart';
import '../common/tab_scroll.dart';
import '../common/selection.dart';
import '../common/video_slivers.dart';
import '../home/widgets/sort_sheet.dart';
import '../player/player_page.dart';
import '../video/video_actions_sheet.dart';
import 'video_picker_page.dart';

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
      appBar: selectionMode
          ? buildSelectionAppBar(
              context: context,
              count: selectedIds.length,
              onClose: clearSelection,
              onSelectAll: () => selectAll(videos),
            )
          : AppBar(
              title: Text(title),
              actions: [
                if (widget.kind == CollectionKind.playlist && playlist != null)
                  IconButton(
                    tooltip: context.s.addVideos,
                    icon: const Icon(Icons.playlist_add_rounded),
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
                IconButton(
                  tooltip: library.viewMode == ViewMode.list
                      ? context.s.gridView
                      : context.s.listView,
                  icon: Icon(
                    library.viewMode == ViewMode.list
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                  ),
                  onPressed: library.toggleViewMode,
                ),
                IconButton(
                  tooltip: context.s.sort,
                  icon: const Icon(Icons.swap_vert_rounded),
                  onPressed: () => showSortSheet(context, _key),
                ),
                const SizedBox(width: 6),
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
          : null,
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
                              TextButton.icon(
                                // Long-press goes straight to shuffled; a tap
                                // asks which order to use.
                                onLongPress: () => _playAll(
                                  context,
                                  videos,
                                  title,
                                  shuffled: true,
                                ),
                                onPressed: () =>
                                    _askPlayMode(context, videos, title),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: Text(context.s.playAll),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      VideoSliver(
                        videos: videos,
                        viewMode: library.viewMode,
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
                            ),
                            onSelect: () => startSelection(video),
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

  /// Play All offers both orders rather than assuming one.
  Future<void> _askPlayMode(
    BuildContext context,
    List<Video> videos,
    String title,
  ) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
            child: Text(
              context.s.howToPlay,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: Text(context.s.playInOrder),
            subtitle: Text(context.s.videoCount(videos.length)),
            onTap: () {
              Navigator.pop(sheetContext);
              _playAll(context, videos, title, shuffled: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded),
            title: Text(context.s.playShuffled),
            subtitle: Text(context.s.videoCount(videos.length)),
            onTap: () {
              Navigator.pop(sheetContext);
              _playAll(context, videos, title, shuffled: true);
            },
          ),
          const SizedBox(height: 12),
        ],
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
    );
  }

  Widget _empty(BuildContext context, CollectionKind kind) {
    final s = context.s;
    return switch (kind) {
      CollectionKind.favorites => EmptyState(
        icon: Icons.favorite_border_rounded,
        title: s.noFavorites,
        message: s.noFavoritesBody,
      ),
      CollectionKind.playlist => EmptyState(
        icon: Icons.queue_music_rounded,
        title: s.emptyPlaylist,
        message: s.emptyPlaylistBody,
      ),
      CollectionKind.folder => EmptyState(
        icon: Icons.folder_off_outlined,
        title: s.folderEmpty,
        message: s.folderEmptyBody,
      ),
    };
  }
}
