import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/video.dart';
import '../../../state/library_controller.dart';
import '../../common/glass.dart';
import '../../common/mark_ribbon.dart';
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
    this.markedAtMs,
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

  /// Set on the video marked as where the user stopped in this list: how far
  /// into it the mark is.
  final int? markedAtMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.muted;
    final accent = context.accent;
    final solid = AppTheme.isSolid;
    final isDark = theme.brightness == Brightness.dark;
    // The classic look marks the video watched last with an accent strip.
    final lastPlayed =
        solid &&
        context.select<LibraryController, bool>(
          (l) => l.lastPlayedId == video.id,
        );
    final cardRadius = compact
        ? BorderRadius.circular(16)
        : AppTheme.cardRadius;

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
        child: _LastPlayedStrip(
          show: lastPlayed,
          radius: cardRadius,
          color: accent,
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        VideoThumbnail(
                          video: video,
                          width: thumbWidth,
                          height: thumbHeight,
                          borderRadius: compact
                              ? BorderRadius.circular(11)
                              : null,
                          showPlayGlyph: !selectionMode && !compact && !solid,
                          progress: progress,
                        ),
                        if (markedAtMs != null)
                          PositionedDirectional(
                            top: 0,
                            end: 8,
                            child: MarkRibbon(
                              color: accent,
                              width: compact ? 11 : 14,
                            ),
                          ),
                      ],
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
                              subtitleOverride: markedAtMs == null
                                  ? subtitleOverride
                                  : null,
                              markedAtMs: markedAtMs,
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
                          child: Icon(
                            AppIcons.drag_handle_rounded,
                            color: muted,
                          ),
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
                          color: solid && (isDark || lastPlayed)
                              ? accent
                              : muted,
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
      ),
    );

    // Given a height, the row fills it exactly, so a screenful is a whole
    // number of videos with no half one left under the bars.
    return extent == null ? row : SizedBox(height: extent, child: row);
  }
}

/// The accent strip down the leading edge of the card for the video watched
/// last. It sits on the side the menu is, as in the classic look's design.
class _LastPlayedStrip extends StatelessWidget {
  const _LastPlayedStrip({
    required this.show,
    required this.radius,
    required this.color,
    required this.child,
  });

  final bool show;
  final BorderRadius radius;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    );
  }
}

/// Where a video came from, as a small mark before its folder: Instagram's
/// logo for its downloads, a play mark for everything else. The glass look
/// keeps its plain folder mark.
class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.folder, required this.muted});

  final String folder;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.isSolid) {
      return Icon(AppIcons.folder_outlined, size: 13, color: muted);
    }
    final instagram = folder.toLowerCase().contains('instagram');
    return Icon(
      instagram ? AppIcons.instagram_logo : AppIcons.play_box,
      size: 15,
      color: muted,
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
    this.markedAtMs,
  });

  final Video video;
  final Color muted;
  final Color accent;
  final bool isFavorite;
  final bool isPinned;
  final String? subtitleOverride;
  final int? markedAtMs;

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
        if (markedAtMs != null)
          Expanded(
            child: Text(
              context.s.markedAt(
                Fmt.duration(Duration(milliseconds: markedAtMs!)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else if (subtitleOverride != null)
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
          _SourceIcon(folder: video.folderName, muted: muted),
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
