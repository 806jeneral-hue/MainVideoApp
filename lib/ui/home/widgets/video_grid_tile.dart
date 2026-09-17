import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/video.dart';
import '../../common/glass.dart';
import '../../common/video_thumbnail.dart';
import '../../../core/theme/app_icons.dart';

/// Grid version of the video card — same white surface, same rounding, same
/// information as the list tile, just stacked instead of side by side.
class VideoGridTile extends StatelessWidget {
  const VideoGridTile({
    super.key,
    required this.video,
    required this.onTap,
    required this.onMore,
    this.progress = 0,
    this.isFavorite = false,
    this.isPinned = false,
    this.selectionMode = false,
    this.selected = false,
  });

  final Video video;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final double progress;
  final bool isFavorite;
  final bool isPinned;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.muted;

    return GlassSurface(
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onMore,
          borderRadius: AppTheme.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => VideoThumbnail(
                        video: video,
                        width: constraints.maxWidth,
                        height: constraints.maxWidth * 9 / 16,
                        showPlayGlyph: !selectionMode,
                        progress: progress,
                      ),
                    ),
                    if (isPinned || isFavorite)
                      Positioned(
                        right: 7,
                        top: 7,
                        child: _Badge(
                          icon: isPinned
                              ? AppIcons.push_pin_rounded
                              : AppIcons.favorite_rounded,
                        ),
                      ),
                    if (selectionMode)
                      Positioned(
                        left: 7,
                        top: 7,
                        child: _Badge(
                          icon: selected
                              ? AppIcons.check_circle_rounded
                              : AppIcons.circle_outlined,
                          color: selected
                              ? AppTheme.accentOnDark
                              : Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.storage_rounded,
                                    size: 12,
                                    color: muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${Fmt.fileSize(video.sizeBytes)}  ·  ${video.folderName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            onPressed: onMore,
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            color: muted,
                            icon: const Icon(AppIcons.more_vert),
                            tooltip: context.s.more,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.color = AppTheme.accentOnDark});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}
