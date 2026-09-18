import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/video.dart';
import '../../common/glass.dart';
import '../../common/video_thumbnail.dart';
import '../../../core/theme/app_icons.dart';

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
    this.compact = false,
    this.extent,
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

  /// Smaller thumbnail and text, so more videos fit on screen.
  final bool compact;

  /// The exact height this row was given, so a page holds a whole number of
  /// videos with nothing left over at the bottom. Null lets the row size
  /// itself from its contents.
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.muted;
    final accent = context.accent;

    final gap = compact ? 6.0 : AppTheme.space12;
    final pad = compact ? 6.0 : 10.0;
    // The picture keeps the proportions it has always had; only its size
    // follows the row.
    final ratio = compact ? 1.75 : 1.55;
    final thumbHeight = extent != null
        ? (extent! - gap - pad * 2).clamp(34.0, 160.0)
        : (compact ? 48.0 : (selectionMode ? 76.0 : 88.0));
    final thumbWidth = extent != null
        ? thumbHeight * ratio
        : (compact ? 84.0 : (selectionMode ? 116.0 : 136.0));

    final row = Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        0,
        AppTheme.pageMargin,
        gap,
      ),
      child: GlassSurface(
        selected: selected,
        radius: compact ? BorderRadius.circular(16) : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMore,
            borderRadius: compact
                ? BorderRadius.circular(16)
                : AppTheme.cardRadius,
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        top: compact ? 16 : 22,
                        right: 6,
                      ),
                      child: Icon(
                        selected
                            ? AppIcons.check_circle_rounded
                            : AppIcons.circle_outlined,
                        color: selected ? accent : muted,
                        size: 22,
                      ),
                    ),
                  ],
                  VideoThumbnail(
                    video: video,
                    width: thumbWidth,
                    height: thumbHeight,
                    borderRadius: compact ? BorderRadius.circular(11) : null,
                    showPlayGlyph: !selectionMode && !compact,
                    progress: progress,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: compact ? 1 : 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            video.displayName,
                            maxLines: (compact || thumbHeight < 64) ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (compact
                                        ? theme.textTheme.bodyMedium
                                        : theme.textTheme.bodyLarge)
                                    ?.copyWith(
                                      fontSize: compact ? 13 : null,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                          ),
                          SizedBox(height: compact ? 3 : AppTheme.space8),
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
                        child: Icon(AppIcons.drag_handle_rounded, color: muted),
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
                        icon: const Icon(AppIcons.more_vert),
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

    // Given a height, the row fills it exactly, so a screenful is a whole
    // number of videos with no half one left under the bars.
    return extent == null ? row : SizedBox(height: extent, child: row);
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
          Icon(AppIcons.push_pin_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
        ],
        if (isFavorite) ...[
          Icon(AppIcons.favorite_rounded, size: 13, color: accent),
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
          Icon(AppIcons.storage_rounded, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(Fmt.fileSize(video.sizeBytes), style: style),
          Text('  ·  ', style: style),
          Icon(AppIcons.folder_outlined, size: 13, color: muted),
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
