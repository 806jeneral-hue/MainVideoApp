import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/video.dart';
import '../../data/services/video_file_service.dart';
import '../../state/library_controller.dart';
import '../common/video_thumbnail.dart';
import '../folders/add_to_playlist_sheet.dart';
import 'move_to_sheet.dart';
import 'video_info_page.dart';
import '../common/glass_dialog.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';
import '../../state/bookmark_controller.dart';
import '../../data/models/collection_prefs.dart';
import '../common/quick_tiles.dart';

/// Long-press / "…" menu for a single video (phase 6).
Future<void> showVideoActions(
  BuildContext context,
  Video video, {
  VoidCallback? onPlay,
  VoidCallback? onSelect,
  Future<void> Function()? onRemoveFromPlaylist,

  /// The list the menu was opened from, for marking where the user stopped.
  CollectionKey? collection,
}) {
  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) => _VideoActionsSheet(
      video: video,
      onPlay: onPlay,
      onSelect: onSelect,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      collection: collection,
    ),
  );
}

class _VideoActionsSheet extends StatelessWidget {
  const _VideoActionsSheet({
    required this.video,
    this.onPlay,
    this.onSelect,
    this.onRemoveFromPlaylist,
    this.collection,
  });

  final Video video;
  final VoidCallback? onPlay;

  /// Starts a multi-select with this video already ticked.
  final VoidCallback? onSelect;
  final Future<void> Function()? onRemoveFromPlaylist;
  final CollectionKey? collection;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);
    final isFavorite = library.isFavorite(video.id);
    final isPinned = library.isVideoPinned(video.id);
    final isHidden = library.isVideoHidden(video.id);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
              child: Row(
                children: [
                  VideoThumbnail(video: video, width: 88, height: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          video.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${Fmt.durationMs(video.durationMs)}  ·  ${Fmt.fileSize(video.sizeBytes)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The main things to do, as two pills: play stands out.
                  if (onPlay != null || onSelect != null)
                    Row(
                      children: [
                        if (onPlay != null)
                          Expanded(
                            child: PillAction(
                              icon: AppIcons.play_arrow_rounded,
                              label: context.s.play,
                              filled: true,
                              onTap: () {
                                Navigator.pop(context);
                                onPlay!();
                              },
                            ),
                          ),
                        if (onPlay != null && onSelect != null)
                          const SizedBox(width: 8),
                        if (onSelect != null)
                          Expanded(
                            child: PillAction(
                              icon: AppIcons.checklist_rounded,
                              label: context.s.select,
                              onTap: () {
                                Navigator.pop(context);
                                onSelect!();
                              },
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  TileGrid(
                    tiles: [
                      if (collection != null) _markTile(context, library),
                      QuickTile(
                        icon: isFavorite
                            ? AppIcons.favorite
                            : AppIcons.favorite_border,
                        label: context.s.tileFavorite,
                        active: isFavorite,
                        onTap: () => library.toggleFavorite(video.id),
                      ),
                      QuickTile(
                        icon: isPinned
                            ? AppIcons.push_pin_rounded
                            : AppIcons.push_pin_outlined,
                        label: context.s.tilePin,
                        active: isPinned,
                        onTap: () => library.toggleVideoPin(video.id),
                      ),
                      QuickTile(
                        icon: AppIcons.playlist_add_rounded,
                        label: context.s.tilePlaylist,
                        onTap: () async {
                          Navigator.pop(context);
                          await showAddToPlaylistSheet(context, [video.id]);
                        },
                      ),
                      if (onRemoveFromPlaylist != null)
                        QuickTile(
                          icon: AppIcons.playlist_remove_rounded,
                          label: context.s.tileRemoveFromList,
                          onTap: () async {
                            Navigator.pop(context);
                            await onRemoveFromPlaylist!();
                          },
                        ),
                      QuickTile(
                        icon: isHidden
                            ? AppIcons.visibility_rounded
                            : AppIcons.visibility_off_outlined,
                        label: isHidden
                            ? context.s.tileUnhide
                            : context.s.tileHide,
                        active: isHidden,
                        onTap: () => library.toggleVideoHidden(video.id),
                      ),
                      QuickTile(
                        icon: AppIcons.drive_file_move_outline,
                        label: context.s.tileMove,
                        onTap: () async {
                          Navigator.pop(context);
                          await showMoveToSheet(context, [video]);
                        },
                      ),
                      QuickTile(
                        icon: AppIcons.drive_file_rename_outline_rounded,
                        label: context.s.tileRename,
                        onTap: () async {
                          Navigator.pop(context);
                          await promptRenameVideo(context, library, video);
                        },
                      ),
                      QuickTile(
                        icon: AppIcons.info_outline_rounded,
                        label: context.s.tileInfo,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoInfoPage(video: video),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DangerRow(
                    label: context.s.deleteFromDevice,
                    onTap: () async {
                      Navigator.pop(context);
                      await confirmDeleteVideo(context, library, video);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Asks for a new name and renames the file. Shared with the player's own
/// options sheet.
Future<void> promptRenameVideo(
  BuildContext context,
  LibraryController library,
  Video video,
) async {
  final controller = TextEditingController(text: video.displayName);
  final messenger = ScaffoldMessenger.of(context);
  final s = context.s;

  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: Text(context.s.renameVideo),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: context.s.newName),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(context.s.rename),
        ),
      ],
    ),
  );

  if (name == null || name.trim().isEmpty) return;
  final result = await library.renameVideo(video, name);
  messenger.showSnackBar(
    glassSnackBar(
      content: Text(
        result.ok ? s.renamed : (result.message ?? s.couldNotRename),
      ),
    ),
  );
}

/// Confirms, then deletes the file. Shared with the player's options sheet.
Future<void> confirmDeleteVideo(
  BuildContext context,
  LibraryController library,
  Video video,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = context.s;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: Text(context.s.deleteVideoTitle),
      content: Text(context.s.deleteVideoBody(video.displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.s.delete),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  final result = await library.deleteVideo(video);
  if (result.ok) {
    messenger.showSnackBar(glassSnackBar(content: Text(s.videoDeleted)));
    return;
  }
  messenger.showSnackBar(
    glassSnackBar(
      content: Text(switch (result.status) {
        FileOpStatus.denied => s.permissionDenied,
        FileOpStatus.notFound => s.fileGone,
        _ => result.message ?? s.couldNotDelete,
      }),
    ),
  );
}

extension on _VideoActionsSheet {
  /// This list's mark: set it on this video — where it was left, if it was
  /// started — or, on the marked video, take it off.
  Widget _markTile(BuildContext context, LibraryController library) {
    final bookmarks = context.watch<BookmarkController>();
    final key = collection!;
    final marked = bookmarks.markerFor(key)?.videoId == video.id;
    return QuickTile(
      icon: AppIcons.bookmark_rounded,
      label: marked ? context.s.tileMarked : context.s.tileMark,
      active: marked,
      onTap: () {
        if (marked) {
          bookmarks.clearMarker(key);
          return;
        }
        final resume = library.resumePositionMs(video.id);
        final valid = resume > 2000 && resume < video.durationMs - 3000;
        bookmarks.setMarker(
          key,
          videoId: video.id,
          positionMs: valid ? resume : 0,
        );
      },
    );
  }
}
