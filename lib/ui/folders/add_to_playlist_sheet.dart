import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_controller.dart';

/// Adds one or more videos to a playlist, creating one on the spot if needed
/// (phase 3 — videos can come from anywhere, not just one folder).
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  List<String> videoIds,
) {
  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) => _AddToPlaylistSheet(videoIds: videoIds),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.videoIds});

  final List<String> videoIds;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);
    final playlists = library.playlists;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Text(
                videoIds.length == 1
                    ? context.s.addToPlaylist
                    : context.s.addVideosToPlaylist(videoIds.length),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                child: Icon(Icons.add_rounded),
              ),
              title: Text(context.s.newPlaylist),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              onTap: () async {
                final name = await promptForPlaylistName(context);
                if (name == null) return;
                await library.createPlaylist(name, videoIds: videoIds);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            if (playlists.isNotEmpty) const Divider(height: 18),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final already = videoIds.every(
                    (id) => playlist.videoIds.contains(id),
                  );

                  return ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppTheme.thumbRadius,
                      ),
                      child: const Icon(Icons.queue_music_rounded, size: 20),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text(context.s.videoCount(playlist.count)),
                    trailing: already
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTheme.accent,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    onTap: already
                        ? null
                        : () async {
                            await library.addToPlaylist(playlist.id, videoIds);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.s.addedTo(playlist.name)),
                              ),
                            );
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared "name your playlist" dialog.
Future<String?> promptForPlaylistName(
  BuildContext context, {
  String initial = '',
  String? title,
  String? actionLabel,
}) async {
  final controller = TextEditingController(text: initial);

  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title ?? context.s.newPlaylist),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: context.s.playlistName),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(actionLabel ?? context.s.create),
        ),
      ],
    ),
  );

  final trimmed = name?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
