import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bottom_fade.dart';
import 'emerge.dart';
import 'drag_select.dart';
import '../../data/models/bookmark.dart';
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
    this.marker,
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

  /// This list's stop marker, shown on the video it points at.
  final StopMarker? marker;

  int? _markedAt(Video video) =>
      marker?.videoId == video.id ? marker!.positionMs : null;

  bool get _reorderable => onReorder != null && !selectionMode;

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.grid) {
      final width = MediaQuery.sizeOf(context).width;
      final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

      // Each card is exactly as tall as what it holds — the 16:9 thumbnail,
      // a two-line title and the meta line — so no empty band is left under
      // the text on any screen width or font size.
      const spacing = AppTheme.space12;
      final cellWidth =
          (width - AppTheme.pageMargin * 2 - spacing * (columns - 1)) / columns;
      final scaler = MediaQuery.textScalerOf(context);
      final thumbHeight = (cellWidth - 16) * 9 / 16;
      final textHeight =
          scaler.scale(14) * 1.25 * 2 + 5 + scaler.scale(12.5) * 1.3;
      final cardHeight = 8 + thumbHeight + 9 + textHeight + 12;

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
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = videos[index];
              return DragSelectable(
                key: ValueKey(video.id),
                id: video.id,
                child: EmergeFromBottom(
                  child: VideoGridTile(
                    video: video,
                    progress: progressOf(video),
                    isFavorite: isFavorite(video),
                    isPinned: isPinned?.call(video) ?? false,
                    selectionMode: selectionMode,
                    selected: selectedIds.contains(video.id),
                    markedAtMs: _markedAt(video),
                    onTap: () => onTap(video, index),
                    onMore: () => onMore(video),
                  ),
                ),
              );
            },
            childCount: videos.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),
      );
    }

    // A screenful holds a whole number of videos: the rows share out the room
    // left between whatever sits above the list and the floating bars, so no
    // half a row is ever parked at the bottom.
    final perScreen = viewMode == ViewMode.compact ? 9 : 5;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.viewportMainAxisExtent -
            constraints.precedingScrollExtent -
            steadyBottomInset(context) -
            2;
        final extent = (room / perScreen).clamp(
          viewMode == ViewMode.compact ? 52.0 : 88.0,
          viewMode == ViewMode.compact ? 96.0 : 168.0,
        );

        if (_reorderable) {
          return SliverPadding(
            padding: EdgeInsets.only(top: 2, bottom: listBottomInset(context)),
            sliver: SliverReorderableList(
              itemCount: videos.length,
              itemExtent: extent,
              // onReorderItem hands over an index already adjusted for the
              // removal, so the caller can insert at it directly.
              onReorderItem: onReorder!,
              itemBuilder: (context, index) =>
                  _listTile(index, extent: extent, draggable: true),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.only(top: 2, bottom: listBottomInset(context)),
          sliver: SliverFixedExtentList(
            itemExtent: extent,
            delegate: SliverChildBuilderDelegate(
              (context, index) => _listTile(index, extent: extent),
              childCount: videos.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        );
      },
    );
  }

  Widget _listTile(int index, {double? extent, bool draggable = false}) {
    final video = videos[index];
    // Tagged so a drag across the list can tell what is under the finger.
    return DragSelectable(
      key: ValueKey(video.id),
      id: video.id,
      child: EmergeFromBottom(
        child: VideoListTile(
          video: video,
          compact: viewMode == ViewMode.compact,
          extent: extent,
          markedAtMs: _markedAt(video),
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
      ),
    );
  }
}
