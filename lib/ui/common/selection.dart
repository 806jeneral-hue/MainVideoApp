import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../folders/add_to_playlist_sheet.dart';
import '../video/move_to_sheet.dart';

/// Multi-select state shared by every screen that lists videos.
///
/// A long press starts a selection; tapping then toggles rows instead of
/// opening them.
mixin VideoSelection<T extends StatefulWidget> on State<T> {
  final Set<String> selectedIds = {};
  bool selectionMode = false;

  /// True while the finger that started the selection is still down, so a
  /// drag from that same press keeps adding videos instead of scrolling.
  bool dragArmed = false;

  bool isSelected(Video video) => selectedIds.contains(video.id);

  /// Entered by a long press. The press has already won the gesture arena, so
  /// the list will not scroll under the finger that follows.
  void startSelection(Video video) {
    Haptics.medium();
    setState(() {
      selectionMode = true;
      dragArmed = true;
      selectedIds
        ..clear()
        ..add(video.id);
    });
  }

  /// A drag passing over a video during that same press.
  void addToSelection(String id) {
    if (selectedIds.contains(id)) return;
    setState(() => selectedIds.add(id));
  }

  void endDragSelection() {
    if (!dragArmed) return;
    setState(() => dragArmed = false);
  }

  void toggleSelection(Video video) {
    Haptics.light();
    setState(() {
      if (!selectedIds.remove(video.id)) selectedIds.add(video.id);
      if (selectedIds.isEmpty) selectionMode = false;
    });
  }

  void selectAll(List<Video> videos) {
    setState(() {
      selectionMode = true;
      selectedIds
        ..clear()
        ..addAll(videos.map((v) => v.id));
    });
  }

  void clearSelection() {
    setState(() {
      selectionMode = false;
      dragArmed = false;
      selectedIds.clear();
    });
  }

  /// Drops ids that no longer exist, e.g. after a bulk delete.
  void pruneSelection(List<Video> videos) {
    final present = videos.map((v) => v.id).toSet();
    selectedIds.removeWhere((id) => !present.contains(id));
    if (selectedIds.isEmpty && selectionMode) {
      selectionMode = false;
      dragArmed = false;
    }
  }

  List<Video> selectedVideos(List<Video> from) =>
      from.where((v) => selectedIds.contains(v.id)).toList();
}

/// The app bar shown while a selection is active.
AppBar buildSelectionAppBar({
  required BuildContext context,
  required int count,
  required VoidCallback onClose,
  required VoidCallback onSelectAll,
}) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close_rounded),
      onPressed: onClose,
      tooltip: context.s.cancel,
    ),
    title: Text(context.s.selectedCount(count)),
    actions: [
      IconButton(
        icon: const Icon(Icons.select_all_rounded),
        onPressed: onSelectAll,
        tooltip: context.s.selectAll,
      ),
      const SizedBox(width: 6),
    ],
  );
}

/// Bulk actions for the current selection.
class SelectionActionsBar extends StatelessWidget {
  const SelectionActionsBar({
    super.key,
    required this.selected,
    required this.onDone,
    this.playlistId,
  });

  final List<Video> selected;
  final VoidCallback onDone;

  /// Set when the selection came from inside a playlist, which unlocks
  /// "remove from this playlist" and makes Move a playlist-to-playlist move.
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryController>();
    final theme = Theme.of(context);
    final allFavorite =
        selected.isNotEmpty && selected.every((v) => library.isFavorite(v.id));

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: allFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: allFavorite ? context.s.unfavorite : context.s.favorite,
                onTap: selected.isEmpty
                    ? null
                    : () async {
                        await library.setFavorites(
                          selected.map((v) => v.id),
                          !allFavorite,
                        );
                        onDone();
                      },
              ),
              _Action(
                icon: Icons.playlist_add_rounded,
                label: context.s.addTo,
                onTap: selected.isEmpty
                    ? null
                    : () async {
                        await showAddToPlaylistSheet(
                          context,
                          selected.map((v) => v.id).toList(),
                        );
                        onDone();
                      },
              ),
              _Action(
                icon: Icons.visibility_off_outlined,
                label: context.s.hideVideo,
                onTap: selected.isEmpty
                    ? null
                    : () async {
                        await library.setVideosHidden(
                          selected.map((v) => v.id),
                          true,
                        );
                        onDone();
                      },
              ),
              _Action(
                icon: Icons.drive_file_move_outline,
                label: context.s.move,
                onTap: selected.isEmpty
                    ? null
                    : () async {
                        await showMoveToSheet(
                          context,
                          selected,
                          fromPlaylistId: playlistId,
                        );
                        onDone();
                      },
              ),
              if (playlistId != null)
                _Action(
                  icon: Icons.playlist_remove_rounded,
                  label: context.s.remove,
                  onTap: selected.isEmpty
                      ? null
                      : () async {
                          await library.removeManyFromPlaylist(
                            playlistId!,
                            selected.map((v) => v.id),
                          );
                          onDone();
                        },
                ),
              _Action(
                icon: Icons.delete_outline_rounded,
                label: context.s.delete,
                destructive: true,
                onTap: selected.isEmpty
                    ? null
                    : () => _confirmBulkDelete(
                        context,
                        library,
                        selected,
                        onDone,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmBulkDelete(
  BuildContext context,
  LibraryController library,
  List<Video> selected,
  VoidCallback onDone,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // Captured before awaiting: the context may be gone by the time the delete
  // finishes and the result needs a message.
  final s = context.s;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.s.deleteManyTitle(selected.length)),
      content: Text(context.s.deleteManyBody),
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

  final result = await library.deleteVideos(selected);
  onDone();

  final failed = selected.length - result.deleted;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failed == 0
            ? s.deletedCount(result.deleted)
            : '${s.partialDelete(result.deleted, failed)}'
                  '${result.failure?.message == null ? '' : ' — ${result.failure!.message}'}',
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final base = destructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.onSurface;
    final color = enabled ? base : base.withValues(alpha: 0.35);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
