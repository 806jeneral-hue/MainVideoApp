import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/song.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../../state/music_controller.dart';
import '../common/app_icon.dart';
import '../common/empty_state.dart';
import '../common/glass.dart';
import '../common/glass_controls.dart';
import '../common/video_thumbnail.dart';
import 'widgets/album_art.dart';

/// Picks songs and videos to put in a music playlist: searchable across both,
/// tick as many as wanted. Videos will play as audio in the music player.
class SongPickerPage extends StatefulWidget {
  const SongPickerPage({
    super.key,
    required this.title,
    this.excluded = const {},
  });

  final String title;

  /// IDs already in the playlist, left out of the list.
  final Set<String> excluded;

  @override
  State<SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends State<SongPickerPage>
    with SingleTickerProviderStateMixin {
  final List<String> _selected = [];
  final TextEditingController _search = TextEditingController();
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final library = context.watch<LibraryController>();
    final s = context.s;
    final normQ = TextNormalizer.normalize(_query);

    final songs = [
      for (final song in music.songs)
        if (normQ.isEmpty ||
            TextNormalizer.normalize(
              '${song.title} ${song.artist} ${song.album} ${song.path.split(RegExp(r"[/\\]")).last}',
            ).contains(normQ))
          song,
    ];

    final availableVideos = library.visibleVideos;
    final videos = normQ.isEmpty
        ? availableVideos
        : availableVideos.where((v) {
            final fileName = v.path.split(RegExp(r'[/\\]')).last;
            final target =
                TextNormalizer.normalize('${v.title} $fileName ${v.folderName}');
            return target.contains(normQ);
          }).toList();

    final currentTabIsSongs = _tabController.index == 0;
    final currentTabSelectableIds = currentTabIsSongs
        ? {
            for (final song in songs)
              if (!widget.excluded.contains(song.id)) song.id,
          }
        : {
            for (final v in videos)
              if (!widget.excluded.contains(v.id)) v.id,
          };
    final allCurrentTabSelected = currentTabSelectableIds.isNotEmpty &&
        currentTabSelectableIds.every(_selected.contains);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          HeaderAction(
            tooltip: allCurrentTabSelected ? s.deselectAll : s.selectAll,
            icon: Icon(
              allCurrentTabSelected
                  ? AppIcons.checklist_rounded
                  : AppIcons.select_all_rounded,
            ),
            onPressed: currentTabSelectableIds.isEmpty
                ? null
                : () {
                    setState(() {
                      if (allCurrentTabSelected) {
                        _selected.removeWhere(
                          (id) => currentTabSelectableIds.contains(id),
                        );
                      } else {
                        for (final id in currentTabSelectableIds) {
                          if (!_selected.contains(id)) _selected.add(id);
                        }
                      }
                    });
                  },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: s.search,
                    prefixIcon: const AppIcon(AppIcons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: context.accent,
                labelColor: context.accent,
                unselectedLabelColor: context.muted,
                tabs: [
                  Tab(
                    icon: const Icon(AppIcons.music_note_rounded, size: 18),
                    text: '${s.songs} (${songs.length})',
                  ),
                  Tab(
                    icon: const Icon(AppIcons.movie_outlined, size: 18),
                    text: '${s.videos} (${videos.length})',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : GlassFab(
              // In the order they were ticked.
              onPressed: () => Navigator.pop(context, List.of(_selected)),
              icon: const Icon(AppIcons.check_rounded),
              label: Text(s.addCountBadge(_selected.length)),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Songs List
          songs.isEmpty
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
                    final isAlreadyAdded = widget.excluded.contains(song.id);
                    return _SongPickerTile(
                      song: song,
                      selected: _selected.contains(song.id),
                      alreadyAdded: isAlreadyAdded,
                      onTap: isAlreadyAdded
                          ? null
                          : () => setState(() {
                                if (!_selected.remove(song.id)) {
                                  _selected.add(song.id);
                                }
                              }),
                    );
                  },
                ),

          // Videos List (playable as audio in music playlist)
          videos.isEmpty
              ? EmptyState(
                  icon: AppIcons.movie_outlined,
                  title: s.nothingToAdd,
                  message: s.nothingToAddBody,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isAlreadyAdded = widget.excluded.contains(video.id);
                    return _VideoMusicPickerTile(
                      video: video,
                      selected: _selected.contains(video.id),
                      alreadyAdded: isAlreadyAdded,
                      onTap: isAlreadyAdded
                          ? null
                          : () => setState(() {
                                if (!_selected.remove(video.id)) {
                                  _selected.add(video.id);
                                }
                              }),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _SongPickerTile extends StatelessWidget {
  const _SongPickerTile({
    required this.song,
    required this.selected,
    required this.alreadyAdded,
    required this.onTap,
  });

  final Song song;
  final bool selected;
  final bool alreadyAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: alreadyAdded || selected,
            onChanged: onTap != null ? (_) => onTap!() : null,
            activeColor:
                alreadyAdded ? theme.colorScheme.outline : context.accent,
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
                Row(
                  children: [
                    if (alreadyAdded) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          s.alreadyAdded,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        song.artist.isEmpty
                            ? context.s.unknownArtist
                            : song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (alreadyAdded) {
      return Opacity(
        opacity: 0.55,
        child: content,
      );
    }

    return InkWell(
      onTap: onTap,
      child: content,
    );
  }
}

class _VideoMusicPickerTile extends StatelessWidget {
  const _VideoMusicPickerTile({
    required this.video,
    required this.selected,
    required this.alreadyAdded,
    required this.onTap,
  });

  final Video video;
  final bool selected;
  final bool alreadyAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: alreadyAdded || selected,
            onChanged: onTap != null ? (_) => onTap!() : null,
            activeColor:
                alreadyAdded ? theme.colorScheme.outline : context.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 4),
          VideoThumbnail(video: video, width: 80, height: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (alreadyAdded) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          s.alreadyAdded,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        '${Fmt.fileSize(video.sizeBytes)}  ·  ${video.folderName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (alreadyAdded) {
      return Opacity(
        opacity: 0.55,
        child: content,
      );
    }

    return InkWell(
      onTap: onTap,
      child: content,
    );
  }
}
