import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/video.dart';
import '../../data/services/video_file_service.dart';
import '../../state/library_controller.dart';
import '../common/video_thumbnail.dart';
import '../folders/add_to_playlist_sheet.dart';
import 'move_to_sheet.dart';
import 'video_info_page.dart';

/// Long-press / "…" menu for a single video (phase 6).
Future<void> showVideoActions(
  BuildContext context,
  Video video, {
  VoidCallback? onPlay,
  VoidCallback? onSelect,
  Future<void> Function()? onRemoveFromPlaylist,
}) {
  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) => _VideoActionsSheet(
      video: video,
      onPlay: onPlay,
      onSelect: onSelect,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
    ),
  );
}

class _VideoActionsSheet extends StatelessWidget {
  const _VideoActionsSheet({
    required this.video,
    this.onPlay,
    this.onSelect,
    this.onRemoveFromPlaylist,
  });

  final Video video;
  final VoidCallback? onPlay;

  /// Starts a multi-select with this video already ticked.
  final VoidCallback? onSelect;
  final Future<void> Function()? onRemoveFromPlaylist;

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
            const Divider(height: 1),
            const SizedBox(height: 6),
            if (onPlay != null)
              _Action(
                icon: Icons.play_arrow_rounded,
                label: context.s.play,
                onTap: () {
                  Navigator.pop(context);
                  onPlay!();
                },
              ),
            if (onSelect != null)
              _Action(
                icon: Icons.checklist_rounded,
                label: context.s.select,
                onTap: () {
                  Navigator.pop(context);
                  onSelect!();
                },
              ),
            _Action(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              label: isFavorite
                  ? context.s.removeFromFavorites
                  : context.s.addToFavorites,
              iconColor: isFavorite ? context.accent : null,
              onTap: () => library.toggleFavorite(video.id),
            ),
            _Action(
              icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              label: isPinned ? context.s.unpinFromTop : context.s.pinToTop,
              iconColor: isPinned ? context.accent : null,
              onTap: () => library.toggleVideoPin(video.id),
            ),
            _Action(
              icon: Icons.playlist_add_rounded,
              label: context.s.addToPlaylist,
              onTap: () async {
                Navigator.pop(context);
                await showAddToPlaylistSheet(context, [video.id]);
              },
            ),
            if (onRemoveFromPlaylist != null)
              _Action(
                icon: Icons.playlist_remove_rounded,
                label: context.s.removeFromThisPlaylist,
                onTap: () async {
                  Navigator.pop(context);
                  await onRemoveFromPlaylist!();
                },
              ),
            _Action(
              icon: isHidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_outlined,
              label: isHidden ? context.s.unhideVideo : context.s.hideVideo,
              iconColor: isHidden ? context.accent : null,
              onTap: () => library.toggleVideoHidden(video.id),
            ),
            _Action(
              icon: Icons.drive_file_move_outline,
              label: context.s.moveTo,
              onTap: () async {
                Navigator.pop(context);
                await showMoveToSheet(context, [video]);
              },
            ),
            _Action(
              icon: Icons.drive_file_rename_outline_rounded,
              label: context.s.rename,
              onTap: () async {
                Navigator.pop(context);
                await _rename(context, library, video);
              },
            ),
            _Action(
              icon: Icons.info_outline_rounded,
              label: context.s.videoInfo,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VideoInfoPage(video: video),
                  ),
                );
              },
            ),
            _Action(
              icon: Icons.delete_outline_rounded,
              label: context.s.deleteFromDevice,
              destructive: true,
              onTap: () async {
                Navigator.pop(context);
                await _delete(context, library, video);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

Future<void> _rename(
  BuildContext context,
  LibraryController library,
  Video video,
) async {
  final controller = TextEditingController(text: video.displayName);
  final messenger = ScaffoldMessenger.of(context);
  final s = context.s;

  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
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
    SnackBar(
      content: Text(
        result.ok ? s.renamed : (result.message ?? s.couldNotRename),
      ),
    ),
  );
}

Future<void> _delete(
  BuildContext context,
  LibraryController library,
  Video video,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = context.s;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
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
    messenger.showSnackBar(SnackBar(content: Text(s.videoDeleted)));
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (result.status) {
        FileOpStatus.denied => s.permissionDenied,
        FileOpStatus.notFound => s.fileGone,
        _ => result.message ?? s.couldNotDelete,
      }),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: iconColor ?? color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      shape: const RoundedRectangleBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
    );
  }
}
