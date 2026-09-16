import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bottom_fade.dart';
import 'drag_select.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../home/widgets/video_grid_tile.dart';
import '../home/widgets/video_list_tile.dart';

/// One place that decides how a list of videos is laid out, so the home
/// screen, folders, playlists and favourites all look and behave the same —
/// including multi-select and, in custom order, drag-and-drop reordering.
class VideoSliver extends StatelessWidget {
  const VideoSliver({
    super.key,
    required this.videos,
    required this.viewMode,
    required this.onTap,
    required this.onMore,
    required this.progressOf,
    required this.isFavorite,
    this.isPinned,
    this.subtitleOf,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onReorder,
  });

  final List<Video> videos;
  final ViewMode viewMode;
  final void Function(Video video, int index) onTap;
  final void Function(Video video) onMore;
  final double Function(Video video) progressOf;
  final bool Function(Video video) isFavorite;
  final bool Function(Video video)? isPinned;
  final String Function(Video video)? subtitleOf;

  final bool selectionMode;
  final Set<String> selectedIds;

  /// Non-null turns the list into a reorderable one (custom order).
  final void Function(int oldIndex, int newIndex)? onReorder;

  bool get _reorderable => onReorder != null && !selectionMode;

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.grid) {
      final width = MediaQuery.sizeOf(context).width;
      final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pageMargin,
          2,
          AppTheme.pageMargin,
          listBottomInset(context),
        ),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // Room for the thumbnail plus a two-line title and the meta row.
            childAspectRatio: 0.76,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final video = videos[index];
            return DragSelectable(
              key: ValueKey(video.id),
              id: video.id,
              child: VideoGridTile(
                video: video,
                progress: progressOf(video),
                isFavorite: isFavorite(video),
                isPinned: isPinned?.call(video) ?? false,
                selectionMode: selectionMode,
                selected: selectedIds.contains(video.id),
                onTap: () => onTap(video, index),
                onMore: () => onMore(video),
              ),
            );
          }, childCount: videos.length),
        ),
      );
    }

    if (_reorderable) {
      return SliverPadding(
        padding: EdgeInsets.only(top: 2, bottom: listBottomInset(context)),
        sliver: SliverReorderableList(
          itemCount: videos.length,
          // onReorderItem hands over an index already adjusted for the removal,
          // so the caller can insert at it directly.
          onReorderItem: onReorder!,
          itemBuilder: (context, index) => _listTile(index, draggable: true),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.only(top: 2, bottom: listBottomInset(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _listTile(index),
          childCount: videos.length,
        ),
      ),
    );
  }

  Widget _listTile(int index, {bool draggable = false}) {
    final video = videos[index];
    // Tagged so a drag across the list can tell what is under the finger.
    return DragSelectable(
      key: ValueKey(video.id),
      id: video.id,
      child: VideoListTile(
        video: video,
        progress: progressOf(video),
        isFavorite: isFavorite(video),
        isPinned: isPinned?.call(video) ?? false,
        subtitleOverride: subtitleOf?.call(video),
        selectionMode: selectionMode,
        selected: selectedIds.contains(video.id),
        dragHandleIndex: draggable ? index : null,
        onTap: () => onTap(video, index),
        onMore: () => onMore(video),
      ),
    );
  }
}
