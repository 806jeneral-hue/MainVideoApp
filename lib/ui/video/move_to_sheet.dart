import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/playlist_style.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../common/glass_controls.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';

/// Moves videos somewhere else — a real device folder, or another playlist.
///
/// A folder move is a real move on disk: the file leaves the folder it was in.
/// A playlist move takes the videos out of [fromPlaylistId] and puts them in
/// the target, rather than leaving a copy behind.
Future<void> showMoveToSheet(
  BuildContext context,
  List<Video> videos, {
  String? fromPlaylistId,
}) {
  if (videos.isEmpty) return Future.value();

  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) =>
        _MoveToSheet(videos: videos, fromPlaylistId: fromPlaylistId),
  );
}

class _MoveToSheet extends StatelessWidget {
  const _MoveToSheet({required this.videos, this.fromPlaylistId});

  final List<Video> videos;
  final String? fromPlaylistId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);

    final sourceFolders = videos.map((v) => v.folderPath).toSet();
    final folders = library.allFolders
        .where(
          (f) => !(sourceFolders.length == 1 && f.path == sourceFolders.first),
        )
        .toList();
    final playlists = library.playlists
        .where((p) => p.id != fromPlaylistId)
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
              child: Text(
                context.s.moveCount(videos.length),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Text(
                context.s.moveExplainer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 14),
                children: [
                  if (fromPlaylistId != null && playlists.isNotEmpty) ...[
                    _Label(context.s.playlists),
                    for (final playlist in playlists)
                      GlassTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: _Avatar(
                          icon: PlaylistStyle.iconFor(playlist.iconKey),
                          color: PlaylistStyle.colorFor(playlist.colorValue),
                        ),
                        title: Text(playlist.name),
                        subtitle: Text(context.s.videoCount(playlist.count)),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final message = context.s.movedToPlaylist(
                            playlist.name,
                          );
                          Navigator.pop(context);
                          await library.moveBetweenPlaylists(
                            fromId: fromPlaylistId!,
                            toId: playlist.id,
                            videoIds: videos.map((v) => v.id),
                          );
                          messenger.showSnackBar(
                            glassSnackBar(content: Text(message)),
                          );
                        },
                      ),
                  ],
                  _Label(context.s.deviceFolders),
                  for (final folder in folders)
                    GlassTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      leading: _Avatar(
                        icon: AppIcons.folder_rounded,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      title: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        folder.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _moveToFolder(context, library, folder.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToFolder(
    BuildContext context,
    LibraryController library,
    String path,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    Navigator.pop(context);

    final result = await library.moveVideosToFolder(videos, path);
    final failed = videos.length - result.moved;

    messenger.showSnackBar(
      glassSnackBar(
        content: Text(
          failed == 0
              ? s.movedCount(result.moved)
              : '${s.partialMove(result.moved, failed)}'
                    '${result.failure?.message == null ? '' : ' — ${result.failure!.message}'}',
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppTheme.thumbRadius,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
