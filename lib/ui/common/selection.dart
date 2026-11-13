import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/enums.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../folders/add_to_playlist_sheet.dart';
import '../video/move_to_sheet.dart';
import '../../core/theme/app_theme.dart';
import 'glass.dart';
import 'glass_dialog.dart';
import 'glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';
import '../../state/playback_controller.dart';

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

  // ----------------------------------------------------------------- drag state
  // Ordered video list captured when a drag session begins. Used to compute
  // the [anchor..current] selection range so dragging backward deselects rows.
  List<Video> _dragVideos = [];

  // Index of the item where the current drag session started.
  int _dragAnchorIndex = -1;

  // Timestamp of the last long-press activation, used to suppress the trailing
  // pointer-up tap so an item is not immediately deselected upon releasing the hold.
  int _lastLongPressMs = 0;

  // IDs added solely by the current drag (not pre-existing before the drag).
  // Only these are eligible to be removed when the finger reverses direction.
  final Set<String> _dragAddedIds = {};

  bool isSelected(Video video) => selectedIds.contains(video.id);

  /// Entered by a long press or action sheet. Records the anchor position and
  /// the ordered video list so subsequent hover events can compute a range.
  void startSelection(Video video, [int index = -1, List<Video>? orderedVideos]) {
    _lastLongPressMs = DateTime.now().millisecondsSinceEpoch;
    final list = orderedVideos ?? _dragVideos;
    final idx = index >= 0
        ? index
        : (list.isNotEmpty ? list.indexWhere((v) => v.id == video.id) : 0);
    Haptics.medium();
    setState(() {
      selectionMode = true;
      dragArmed = true;
      _dragAnchorIndex = idx >= 0 ? idx : 0;
      _dragVideos = list;
      _dragAddedIds
        ..clear()
        ..add(video.id);
      selectedIds.add(video.id);
    });
  }

  /// Sets the ordered videos list so range calculations always have access
  /// to the full list even if drag started without explicit list pass.
  void setDragVideos(List<Video> videos) {
    _dragVideos = videos;
  }

  /// Called by [DragSelectArea] every time the finger enters a new tile.
  ///
  /// In 1D view modes (List, Compact), [columns] is 1, and the range spans
  /// linearly between anchor and current index.
  ///
  /// In 2D view modes (Grid), [columns] is > 1 (e.g. 2, 3, or 4), and the
  /// selection computes a 2D bounding box [minRow..maxRow, minCol..maxCol]
  /// corresponding to the actual layout on screen.
  ///
  /// In both modes:
  /// - Selects every item inside the active range/box.
  /// - Deselects items that this drag session added but are now outside the
  ///   active range/box (reverse-drag behaviour). Pre-existing selections are untouched.
  void addToSelection(
    String id,
    int index, [
    List<Video>? videos,
    int columns = 1,
  ]) {
    if (videos != null && videos.isNotEmpty) {
      _dragVideos = videos;
    }
    if (_dragVideos.isEmpty) return;

    if (_dragAnchorIndex < 0) {
      _dragAnchorIndex =
          index >= 0 ? index : _dragVideos.indexWhere((v) => v.id == id);
      if (_dragAnchorIndex < 0) _dragAnchorIndex = 0;
    }

    final effectiveCols = columns > 0 ? columns : 1;
    final Set<int> inRangeIndices;

    if (effectiveCols <= 1) {
      final lo = math.min(_dragAnchorIndex, index);
      final hi = math.max(_dragAnchorIndex, index);
      inRangeIndices = {
        for (int i = lo; i <= hi && i < _dragVideos.length; i++) i,
      };
    } else {
      final anchorRow = _dragAnchorIndex ~/ effectiveCols;
      final anchorCol = _dragAnchorIndex % effectiveCols;
      final currentRow = index ~/ effectiveCols;
      final currentCol = index % effectiveCols;

      final minRow = math.min(anchorRow, currentRow);
      final maxRow = math.max(anchorRow, currentRow);
      final minCol = math.min(anchorCol, currentCol);
      final maxCol = math.max(anchorCol, currentCol);

      inRangeIndices = <int>{};
      for (int r = minRow; r <= maxRow; r++) {
        for (int c = minCol; c <= maxCol; c++) {
          final idx = r * effectiveCols + c;
          if (idx < _dragVideos.length) {
            inRangeIndices.add(idx);
          }
        }
      }
    }

    setState(() {
      // Deselect drag-added items that have fallen outside the new range.
      final toRemove = _dragAddedIds
          .where((dragId) {
            final idx = _dragVideos.indexWhere((v) => v.id == dragId);
            return idx < 0 || !inRangeIndices.contains(idx);
          })
          .toList();
      for (final r in toRemove) {
        _dragAddedIds.remove(r);
        selectedIds.remove(r);
      }

      // Select every item now inside the range.
      for (final idx in inRangeIndices) {
        final vid = _dragVideos[idx];
        if (selectedIds.add(vid.id)) {
          _dragAddedIds.add(vid.id);
        }
      }
    });
  }

  void endDragSelection() {
    setState(() {
      dragArmed = false;
      _dragAddedIds.clear();
      _dragAnchorIndex = -1;
    });
  }

  void toggleSelection(Video video) {
    if (DateTime.now().millisecondsSinceEpoch - _lastLongPressMs < 350) {
      return;
    }
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

  /// Clears all selected IDs but stays in selection mode so the user can
  /// re-pick individual items without having to long-press again.
  void deselectAll() {
    setState(() {
      selectedIds.clear();
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
///
/// When [count] equals [total], the select-all button switches to a
/// "deselect all" action so the user can uncheck everything without closing
/// the selection mode.
AppBar buildSelectionAppBar({
  required BuildContext context,
  required int count,
  required int total,
  required VoidCallback onClose,
  required VoidCallback onSelectAll,
  required VoidCallback onDeselectAll,
  VoidCallback? onToggleViewMode,
  ViewMode? currentViewMode,
}) {
  final allSelected = total > 0 && count >= total;
  // Floating glass buttons, the same as every other header in the app.
  return AppBar(
    leadingWidth: AppTheme.pageMargin + 42 + AppTheme.space8,
    leading: Padding(
      padding: const EdgeInsetsDirectional.only(start: AppTheme.pageMargin),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GlassIconButton(
          icon: AppIcons.close_rounded,
          tooltip: context.s.cancel,
          size: 42,
          iconSize: 21,
          onPressed: onClose,
        ),
      ),
    ),
    title: Text(context.s.selectedCount(count)),
    actions: [
      if (onToggleViewMode != null && currentViewMode != null)
        HeaderAction(
          tooltip: switch (currentViewMode) {
            ViewMode.list => context.s.compactView,
            ViewMode.compact => context.s.gridView,
            ViewMode.grid => context.s.listView,
          },
          icon: Icon(switch (currentViewMode) {
            ViewMode.list => AppIcons.view_list_rounded,
            ViewMode.compact => AppIcons.grid_view_rounded,
            ViewMode.grid => AppIcons.view_agenda_rounded,
          }),
          onPressed: onToggleViewMode,
        ),
      HeaderAction(
        icon: Icon(
          allSelected
              ? AppIcons.checklist_rounded
              : AppIcons.select_all_rounded,
        ),
        onPressed: allSelected ? onDeselectAll : onSelectAll,
        tooltip: allSelected ? context.s.deselectAll : context.s.selectAll,
      ),
      const SizedBox(width: AppTheme.pageMargin),
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
    final allFavorite =
        selected.isNotEmpty && selected.every((v) => library.isFavorite(v.id));

    // A floating glass bar, shaped like the main navigation it replaces
    // while the selection is open.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space20,
          AppTheme.space4,
          AppTheme.space20,
          AppTheme.space12,
        ),
        child: GlassSurface(
          radius: BorderRadius.circular(34),
          floating: true,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Action(
                  icon: allFavorite
                      ? AppIcons.favorite_rounded
                      : AppIcons.favorite_border_rounded,
                  label: allFavorite
                      ? context.s.unfavorite
                      : context.s.favorite,
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
                  icon: AppIcons.playlist_add_rounded,
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
                  icon: AppIcons.visibility_off_outlined,
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
                  icon: AppIcons.drive_file_move_outline,
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
                    icon: AppIcons.playlist_remove_rounded,
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
                  icon: AppIcons.delete_outline_rounded,
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
  final playback = context.read<PlaybackController>();
  // Captured before awaiting: the context may be gone by the time the delete
  // finishes and the result needs a message.
  final s = context.s;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialog(
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

  if (playback.hasSession && result.deleted > 0) {
    for (final v in selected) {
      await playback.removePlayable(v.id);
    }
  }

  final failed = selected.length - result.deleted;
  messenger.showSnackBar(
    glassSnackBar(
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
