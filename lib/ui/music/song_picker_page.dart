import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../state/music_controller.dart';
import '../common/app_icon.dart';
import '../common/empty_state.dart';
import '../common/glass_controls.dart';
import 'widgets/album_art.dart';

/// Picks songs to put in a playlist: every song on the phone, searchable,
/// tick as many as wanted. Returns the chosen ids, or null when backed out.
class SongPickerPage extends StatefulWidget {
  const SongPickerPage({
    super.key,
    required this.title,
    this.excluded = const {},
  });

  final String title;

  /// Songs already in the playlist, left out of the list.
  final Set<String> excluded;

  @override
  State<SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends State<SongPickerPage> {
  final List<String> _selected = [];
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final s = context.s;
    final q = _query.trim().toLowerCase();
    final songs = [
      for (final song in music.songs)
        if (!widget.excluded.contains(song.id) &&
            (q.isEmpty ||
                song.title.toLowerCase().contains(q) ||
                song.artist.toLowerCase().contains(q)))
          song,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: s.searchMusic,
                prefixIcon: const AppIcon(AppIcons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : GlassFab(
              // In the order they were ticked.
              onPressed: () => Navigator.pop(context, List.of(_selected)),
              icon: const Icon(AppIcons.check_rounded),
              label: Text(s.addCount(_selected.length)),
            ),
      body: songs.isEmpty
          ? EmptyState(
              icon: AppIcons.music_note_rounded,
              title: s.nothingToAdd,
              message: s.nothingToAddBody,
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _PickerTile(
                  song: song,
                  selected: _selected.contains(song.id),
                  onTap: () => setState(() {
                    if (!_selected.remove(song.id)) _selected.add(song.id);
                  }),
                );
              },
            ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.song,
    required this.selected,
    required this.onTap,
  });

  final Song song;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              activeColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 4),
            AlbumArt(song: song, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist.isEmpty ? context.s.unknownArtist : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
