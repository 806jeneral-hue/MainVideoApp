import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../state/music_controller.dart';
import '../../state/playback_controller.dart';
import '../common/app_icon.dart';
import '../common/glass.dart';
import '../common/glass_dialog.dart';
import '../common/glass_snack_bar.dart';
import 'music_actions.dart';

/// Which songs of a list are ticked, while a selection is open.
class SongSelection extends ChangeNotifier {
  final Set<String> _ids = {};

  bool get active => _ids.isNotEmpty;
  int get count => _ids.length;
  bool contains(String id) => _ids.contains(id);

  List<Song> pick(List<Song> songs) => [
    for (final song in songs)
      if (_ids.contains(song.id)) song,
  ];

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _ids.addAll(ids);
    notifyListeners();
  }

  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}

/// Owns a [SongSelection] for one page and rebuilds it as ticks change.
class SongSelectionScope extends StatefulWidget {
  const SongSelectionScope({super.key, required this.builder});

  final Widget Function(BuildContext context, SongSelection selection) builder;

  @override
  State<SongSelectionScope> createState() => _SongSelectionScopeState();
}

class _SongSelectionScopeState extends State<SongSelectionScope> {
  final SongSelection _selection = SongSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Back closes the selection first, like it does for videos.
    canPop: !_selection.active,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _selection.clear();
    },
    child: ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => widget.builder(context, _selection),
    ),
  );
}

/// What can be done to the ticked songs, in a floating bar shaped like the
/// one the videos use.
class SongSelectionBar extends StatelessWidget {
  const SongSelectionBar({
    super.key,
    required this.selected,
    required this.onDone,
    required this.queueTitle,
    this.playlistId,
  });

  final List<Song> selected;
  final VoidCallback onDone;
  final String queueTitle;

  /// Set inside a playlist, which adds "remove from this playlist".
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final music = context.read<MusicController>();
    final playback = context.read<PlaybackController>();
    final empty = selected.isEmpty;
    final allFavorite =
        !empty && selected.every((song) => music.isFavorite(song.id));

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
              children: [
                _Action(
                  icon: AppIcons.play_arrow_rounded,
                  label: s.play,
                  onTap: empty
                      ? null
                      : () {
                          playSongs(context, selected, title: queueTitle);
                          onDone();
                        },
                ),
                _Action(
                  icon: AppIcons.queue_play_next_rounded,
                  label: s.playNextShort,
                  onTap: empty
                      ? null
                      : () {
                          playback.playNext(selected, queueTitle: queueTitle);
                          ScaffoldMessenger.of(context).showSnackBar(
                            glassSnackBar(content: Text(s.willPlayNext)),
                          );
                          onDone();
                        },
                ),
                _Action(
                  icon: AppIcons.playlist_add_rounded,
                  label: s.addTo,
                  onTap: empty
                      ? null
                      : () async {
                          await showAddToMusicPlaylistSheet(context, selected);
                          onDone();
                        },
                ),
                _Action(
                  icon: allFavorite
                      ? AppIcons.favorite_rounded
                      : AppIcons.favorite_border_rounded,
                  label: allFavorite ? s.unfavorite : s.favorite,
                  onTap: empty
                      ? null
                      : () async {
                          for (final song in selected) {
                            if (music.isFavorite(song.id) == allFavorite) {
                              await music.toggleFavorite(song.id);
                            }
                          }
                          onDone();
                        },
                ),
                if (playlistId != null)
                  _Action(
                    icon: AppIcons.playlist_remove_rounded,
                    label: s.remove,
                    onTap: empty
                        ? null
                        : () async {
                            for (final song in selected) {
                              await music.removeFromPlaylist(
                                playlistId!,
                                song.id,
                              );
                            }
                            onDone();
                          },
                  ),
                _Action(
                  icon: AppIcons.delete_outline_rounded,
                  label: s.delete,
                  destructive: true,
                  onTap: empty
                      ? null
                      : () => _confirmDelete(context, music, selected, onDone),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  MusicController music,
  List<Song> songs,
  VoidCallback onDone,
) async {
  final s = context.s;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: Text(s.deleteSongsTitle(songs.length)),
      content: Text(s.deleteSongsBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  for (final song in songs) {
    await music.deleteSong(song);
  }
  onDone();
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
    final base = destructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.onSurface;
    final color = onTap != null ? base : base.withValues(alpha: 0.35);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
