import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/video.dart';
import '../../common/video_thumbnail.dart';

/// One video as a white card floating on the page: thumbnail on the left,
/// title and metadata beside it, overflow menu on the right.
///
/// Everything the tile showed before is still here — favourite and pin marks,
/// the resume bar, size, folder, the custom-order drag handle and the
/// selection tick.
class VideoListTile extends StatelessWidget {
  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    required this.onMore,
    this.progress = 0,
    this.isFavorite = false,
    this.isPinned = false,
    this.subtitleOverride,
    this.selectionMode = false,
    this.selected = false,
    this.dragHandleIndex,
  });

  final Video video;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final double progress;
  final bool isFavorite;
  final bool isPinned;
  final String? subtitleOverride;

  /// While a multi-select is running, tapping toggles selection instead of
  /// opening the video.
  final bool selectionMode;
  final bool selected;

  /// Set when the list is in custom order, to show the drag handle.
  final int? dragHandleIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.muted;
    final accent = context.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        10,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? context.accentWash : theme.colorScheme.surface,
          borderRadius: AppTheme.cardRadius,
          boxShadow: context.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMore,
            borderRadius: AppTheme.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 22, right: 6),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected ? accent : muted,
                        size: 22,
                      ),
                    ),
                  ],
                  VideoThumbnail(
                    video: video,
                    width: selectionMode ? 106 : 118,
                    height: selectionMode ? 70 : 78,
                    progress: progress,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            video.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          _MetaRow(
                            video: video,
                            muted: muted,
                            accent: accent,
                            isFavorite: isFavorite,
                            isPinned: isPinned,
                            subtitleOverride: subtitleOverride,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (dragHandleIndex != null)
                    ReorderableDragStartListener(
                      index: dragHandleIndex!,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
                        child: Icon(Icons.drag_handle_rounded, color: muted),
                      ),
                    )
                  else if (!selectionMode)
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: IconButton(
                        onPressed: onMore,
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        color: muted,
                        icon: const Icon(Icons.more_vert),
                        tooltip: context.s.more,
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Size and source line, with the favourite and pin marks kept inline.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.video,
    required this.muted,
    required this.accent,
    required this.isFavorite,
    required this.isPinned,
    required this.subtitleOverride,
  });

  final Video video;
  final Color muted;
  final Color accent;
  final bool isFavorite;
  final bool isPinned;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w500);

    return Row(
      children: [
        if (isPinned) ...[
          Icon(Icons.push_pin_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
        ],
        if (isFavorite) ...[
          Icon(Icons.favorite_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
        ],
        if (subtitleOverride != null)
          Expanded(
            child: Text(
              subtitleOverride!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          )
        else ...[
          Icon(Icons.storage_rounded, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(Fmt.fileSize(video.sizeBytes), style: style),
          Text('  ·  ', style: style),
          Icon(Icons.folder_outlined, size: 13, color: muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              video.folderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}
