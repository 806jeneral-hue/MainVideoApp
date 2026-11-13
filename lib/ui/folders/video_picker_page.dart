import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/enums.dart';
import '../../data/models/song.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../../state/music_controller.dart';
import '../common/app_icon.dart';
import '../common/empty_state.dart';
import '../common/glass.dart';
import '../common/glass_controls.dart';
import '../common/video_thumbnail.dart';
import '../music/widgets/album_art.dart';

/// Multi-select picker used when adding media (videos and songs) to a playlist.
/// Media can be picked from anywhere on the device with seamless tabs.
class VideoPickerPage extends StatefulWidget {
  const VideoPickerPage({
    super.key,
    required this.title,
    this.excluded = const {},
  });

  final String title;
  final Set<String> excluded;

  @override
  State<VideoPickerPage> createState() => _VideoPickerPageState();
}

class _VideoPickerPageState extends State<VideoPickerPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  late final TabController _tabController;
  String _query = '';
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicController>().ensureLoaded();
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
    final library = context.watch<LibraryController>();
    final music = context.watch<MusicController>();
    final s = context.s;

    // Filter videos (matching search query and folder filter)
    var allVideos = library.visibleVideos;
    if (_selectedFolder != null) {
      allVideos = allVideos
          .where((v) => v.folderPath == _selectedFolder)
          .toList(growable: false);
    }
    final normQ = TextNormalizer.normalize(_query);
    final videos = library.orderVideos(
      CollectionKey.home,
      normQ.isEmpty
          ? allVideos
          : allVideos.where((v) {
              final fileName = v.path.split(RegExp(r'[/\\]')).last;
              final target =
                  TextNormalizer.normalize('${v.title} $fileName ${v.folderName}');
              return target.contains(normQ);
            }).toList(),
    );

    // Filter songs (matching search query: title, artist, album, file name)
    final songs = [
      for (final song in music.songs)
        if (normQ.isEmpty ||
            TextNormalizer.normalize(
              '${song.title} ${song.artist} ${song.album} ${song.path.split(RegExp(r"[/\\]")).last}',
            ).contains(normQ))
          song,
    ];

    // Compute selectable unadded items for active tab
    final currentTabIsVideos = _tabController.index == 0;
    final currentTabSelectableIds = currentTabIsVideos
        ? {
            for (final v in videos)
              if (!widget.excluded.contains(v.id)) v.id,
          }
        : {
            for (final song in songs)
              if (!widget.excluded.contains(song.id)) song.id,
          };
    final allCurrentTabSelected = currentTabSelectableIds.isNotEmpty &&
        currentTabSelectableIds.every(_selected.contains);

    final showFolderChips = currentTabIsVideos && library.folders.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          HeaderAction(
            tooltip: switch (library.nextViewMode) {
              ViewMode.list => s.listView,
              ViewMode.compact => s.compactView,
              ViewMode.grid => s.gridView,
            },
            icon: Icon(switch (library.nextViewMode) {
              ViewMode.list => AppIcons.view_agenda_rounded,
              ViewMode.compact => AppIcons.view_list_rounded,
              ViewMode.grid => AppIcons.grid_view_rounded,
            }),
            onPressed: library.toggleViewMode,
          ),
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
                        _selected.removeAll(currentTabSelectableIds);
                      } else {
                        _selected.addAll(currentTabSelectableIds);
                      }
                    });
                  },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showFolderChips ? 144 : 104),
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
              if (showFolderChips)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    scrollDirection: Axis.horizontal,
                    itemCount: library.folders.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        final isAll = _selectedFolder == null;
                        return ChoiceChip(
                          label: Text(s.allVideos),
                          selected: isAll,
                          onSelected: (_) =>
                              setState(() => _selectedFolder = null),
                        );
                      }
                      final folder = library.folders[idx - 1];
                      final isSelected = _selectedFolder == folder.path;
                      return ChoiceChip(
                        label: Text(folder.name),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _selectedFolder = isSelected ? null : folder.path;
                        }),
                      );
                    },
                  ),
                ),
              TabBar(
                controller: _tabController,
                indicatorColor: context.accent,
                labelColor: context.accent,
                unselectedLabelColor: context.muted,
                tabs: [
                  Tab(
                    icon: const Icon(AppIcons.movie_outlined, size: 18),
                    text: '${s.videos} (${videos.length})',
                  ),
                  Tab(
                    icon: const Icon(AppIcons.music_note_rounded, size: 18),
                    text: '${s.songs} (${songs.length})',
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
              onPressed: () => Navigator.pop(context, _selected.toList()),
              icon: const Icon(AppIcons.check_rounded),
              label: Text(s.addCountBadge(_selected.length)),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Videos List / Grid
          videos.isEmpty
              ? EmptyState(
                  icon: AppIcons.movie_outlined,
                  title: s.nothingToAdd,
                  message: s.nothingToAddBody,
                )
              : library.viewMode == ViewMode.grid
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                            ? 4
                            : (MediaQuery.sizeOf(context).width >= 600 ? 3 : 2),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final isAlreadyAdded =
                            widget.excluded.contains(video.id);
                        return _VideoPickerGridTile(
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
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final isAlreadyAdded =
                            widget.excluded.contains(video.id);
                        return _VideoPickerTile(
                          video: video,
                          dense: library.viewMode == ViewMode.compact,
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

          // Songs / Audio List
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
        ],
      ),
    );
  }
}

class _VideoPickerTile extends StatelessWidget {
  const _VideoPickerTile({
    required this.video,
    required this.selected,
    required this.alreadyAdded,
    required this.onTap,
    this.dense = false,
  });

  final Video video;
  final bool selected;
  final bool alreadyAdded;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 4 : 8,
      ),
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
          VideoThumbnail(
            video: video,
            width: dense ? 64 : 96,
            height: dense ? 44 : 58,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.displayName,
                  maxLines: dense ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
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

class _VideoPickerGridTile extends StatelessWidget {
  const _VideoPickerGridTile({
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

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoThumbnail(
            video: video,
            width: double.infinity,
            height: double.infinity,
          ),
          // Gradient shadow for text
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          // Checkbox top-start
          PositionedDirectional(
            top: 4,
            start: 4,
            child: Material(
              type: MaterialType.transparency,
              child: Checkbox(
                value: alreadyAdded || selected,
                onChanged: onTap != null ? (_) => onTap!() : null,
                activeColor:
                    alreadyAdded ? theme.colorScheme.outline : context.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          // Title at bottom
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: Text(
              video.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // If already added, overlay + badge
          if (alreadyAdded)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.alreadyAdded,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (alreadyAdded) {
      return Opacity(opacity: 0.65, child: card);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
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
          AlbumArt(song: song, size: 48),
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
