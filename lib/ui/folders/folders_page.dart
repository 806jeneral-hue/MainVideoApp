import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/playlist_style.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/playlist.dart';
import '../../data/models/video.dart';
import '../../data/models/video_folder.dart';
import '../../state/library_controller.dart';
import '../common/empty_state.dart';
import '../common/glass.dart';
import '../common/bottom_fade.dart';
import '../common/tab_scroll.dart';
import '../common/video_thumbnail.dart';
import '../home/widgets/library_status_view.dart';
import '../settings/scan_folders_page.dart';
import '../settings/settings_button.dart';
import 'add_to_playlist_sheet.dart';
import 'collection_page.dart';
import 'playlist_style_sheet.dart';
import '../common/glass_controls.dart';
import '../../core/theme/app_icons.dart';
import '../common/emerge.dart';

/// Folders and playlists live side by side here — phase 3 treats them as the
/// same idea, with Favorites pinned at the top of the same list.
///
/// The List/Grid switch from phase 2 applies here too, using the same setting
/// as every other screen so one tap changes the whole app.
class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    if (library.status != LibraryStatus.ready) {
      return Scaffold(
        appBar: AppBar(title: Text(context.s.folders)),
        body: const LibraryStatusView(),
      );
    }

    final isGrid = library.viewMode == ViewMode.grid;
    final playlists = library.playlists;
    final folders = library.folders;

    final favoriteVideos = library.favoriteVideos;
    final favorites = _Entry(
      icon: AppIcons.favorite_rounded,
      iconColor: context.accent,
      title: context.s.favorites,
      subtitle: context.s.videoCount(favoriteVideos.length),
      cover: favoriteVideos.isEmpty ? null : favoriteVideos.first,
      onOpen: () => _open(context, CollectionPage.favorites()),
    );

    final playlistEntries = [
      for (final playlist in playlists)
        _Entry(
          icon: PlaylistStyle.iconFor(playlist.iconKey),
          iconColor: PlaylistStyle.colorFor(
            playlist.colorValue,
            fallback: Theme.of(context).colorScheme.primary,
          ),
          title: playlist.name,
          subtitle: context.s.videoCount(playlist.count),
          cover: _firstVideoOf(library, playlist),
          pinned: playlist.pinned,
          onOpen: () => _open(context, CollectionPage.playlist(playlist.id)),
          onMenu: () => _playlistMenu(context, library, playlist),
        ),
    ];

    // The shell owns a controller per tab so re-tapping Folders scrolls to
    // top. This list is short, so it gets no fast-scroll handle.
    final scrollController = TabScroll.maybeOf(context);

    final folderEntries = [
      for (final folder in folders)
        _Entry(
          icon: AppIcons.folder_rounded,
          iconColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.7),
          title: folder.name,
          subtitle:
              '${context.s.videoCount(folder.count)}  ·  ${Fmt.fileSize(folder.totalSizeBytes)}',
          cover: folder.videos.isEmpty ? null : folder.videos.first,
          pinned: library.isFolderPinned(folder.path),
          onOpen: () => _open(context, CollectionPage.folder(folder.path)),
          onMenu: () => _folderMenu(context, library, folder),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: SettingsButton.leading(),
        leadingWidth: SettingsButton.leadingWidth,
        title: Text(context.s.folders),
        actions: [
          HeaderAction(
            tooltip: isGrid ? context.s.listView : context.s.gridView,
            icon: Icon(
              isGrid ? AppIcons.view_list_rounded : AppIcons.grid_view_rounded,
            ),
            onPressed: library.toggleViewMode,
          ),
          HeaderAction(
            tooltip: context.s.chooseFoldersToScan,
            icon: const Icon(AppIcons.rule_folder_outlined),
            onPressed: () => _open(context, const ScanFoldersPage()),
          ),
          const SizedBox(width: 16),
        ],
      ),
      // This screen's Scaffold now runs the full height of the window, so the
      // button has to be lifted clear of the navigation bar itself — the outer
      // Scaffold owns that bar and cannot do it for us.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: GlassFab(
          onPressed: () async {
            final name = await promptForPlaylistName(context);
            if (name == null || !context.mounted) return;
            final playlist = await library.createPlaylist(name);
            if (!context.mounted) return;
            _open(context, CollectionPage.playlist(playlist.id));
          },
          icon: const Icon(AppIcons.add_rounded),
          label: Text(context.s.newPlaylist),
        ),
      ),
      body: RefreshIndicator(
        color: context.accent,
        onRefresh: library.refresh,
        child: BottomFade(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              _section(isGrid, [favorites]),
              if (playlistEntries.isNotEmpty) ...[
                _SectionLabel(context.s.playlists),
                _section(isGrid, playlistEntries),
              ],
              _SectionLabel(context.s.deviceFolders),
              if (folderEntries.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: AppIcons.folder_off_outlined,
                      title: context.s.noFoldersToShow,
                      message: context.s.noFoldersToShowBody,
                    ),
                  ),
                )
              else
                _section(isGrid, folderEntries),
              SliverToBoxAdapter(
                child: SizedBox(height: listBottomInset(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _section(bool isGrid, List<_Entry> entries) =>
      isGrid ? _EntryGrid(entries: entries) : _EntryList(entries: entries);

  static Video? _firstVideoOf(LibraryController library, Playlist playlist) {
    for (final id in playlist.videoIds) {
      final video = library.videoById(id);
      if (video != null) return video;
    }
    return null;
  }

  static void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _playlistMenu(
    BuildContext context,
    LibraryController library,
    Playlist playlist,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassTile(
              leading: Icon(
                playlist.pinned
                    ? AppIcons.push_pin_rounded
                    : AppIcons.push_pin_outlined,
                color: playlist.pinned ? context.accent : null,
              ),
              title: Text(
                playlist.pinned ? context.s.unpinFromTop : context.s.pinToTop,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                library.togglePlaylistPin(playlist.id);
              },
            ),
            GlassTile(
              leading: Icon(
                PlaylistStyle.iconFor(playlist.iconKey),
                color: PlaylistStyle.colorFor(playlist.colorValue),
              ),
              title: Text(context.s.colorAndIcon),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showPlaylistStyleSheet(context, playlist);
              },
            ),
            GlassTile(
              leading: const Icon(AppIcons.drive_file_rename_outline_rounded),
              title: Text(context.s.renamePlaylist),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await promptForPlaylistName(
                  context,
                  initial: playlist.name,
                  title: context.s.renamePlaylist,
                  actionLabel: context.s.save,
                );
                if (name != null) {
                  await library.renamePlaylist(playlist.id, name);
                }
              },
            ),
            GlassTile(
              leading: const Icon(
                AppIcons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                context.s.deletePlaylist,
                style: const TextStyle(color: Colors.redAccent),
              ),
              subtitle: Text(context.s.deletePlaylistBody),
              onTap: () async {
                Navigator.pop(sheetContext);
                await library.deletePlaylist(playlist.id);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _folderMenu(
    BuildContext context,
    LibraryController library,
    VideoFolder folder,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  folder.path,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            GlassTile(
              leading: Icon(
                library.isFolderPinned(folder.path)
                    ? AppIcons.push_pin_rounded
                    : AppIcons.push_pin_outlined,
                color: library.isFolderPinned(folder.path)
                    ? context.accent
                    : null,
              ),
              title: Text(
                library.isFolderPinned(folder.path)
                    ? context.s.unpinFromTop
                    : context.s.pinToTop,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                library.toggleFolderPin(folder.path);
              },
            ),
            GlassTile(
              leading: const Icon(AppIcons.visibility_off_outlined),
              title: Text(context.s.hideThisFolder),
              subtitle: Text(context.s.hideThisFolderBody),
              onTap: () {
                Navigator.pop(sheetContext);
                library.toggleHiddenFolder(folder.path);
              },
            ),
            GlassTile(
              leading: const Icon(AppIcons.playlist_add_rounded),
              title: Text(context.s.addAllToPlaylist),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showAddToPlaylistSheet(
                  context,
                  folder.videos.map((v) => v.id).toList(),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// One row / tile on this screen, whichever layout is active.
class _Entry {
  const _Entry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.cover,
    this.onMenu,
    this.pinned = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool pinned;

  /// Video used as the cover art in grid view; null falls back to the icon.
  final Video? cover;
  final VoidCallback onOpen;
  final VoidCallback? onMenu;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverList.builder(
        itemCount: entries.length,
        addRepaintBoundaries: false,
        itemBuilder: (context, index) =>
            EmergeFromBottom(child: _EntryRow(entry: entries[index])),
      ),
    );
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: 0.88,
        ),
        itemCount: entries.length,
        addRepaintBoundaries: false,
        itemBuilder: (context, index) =>
            EmergeFromBottom(child: _EntryTile(entry: entries[index])),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: GlassSurface(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: entry.onOpen,
            onLongPress: entry.onMenu,
            borderRadius: AppTheme.cardRadius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: entry.iconColor.withValues(alpha: 0.14),
                      borderRadius: AppTheme.thumbRadius,
                    ),
                    child: Icon(entry.icon, color: entry.iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (entry.pinned) ...[
                              Icon(
                                AppIcons.push_pin_rounded,
                                size: 13,
                                color: context.accent,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.onMenu != null)
                    IconButton(
                      icon: const Icon(AppIcons.more_vert),
                      onPressed: entry.onMenu,
                      color: context.muted,
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = entry.cover;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onOpen,
        onLongPress: entry.onMenu,
        borderRadius: AppTheme.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth;
                  return Stack(
                    children: [
                      if (cover != null)
                        VideoThumbnail(
                          video: cover,
                          width: side,
                          height: constraints.maxHeight,
                          showDuration: false,
                          borderRadius: AppTheme.cardRadius,
                        )
                      else
                        Container(
                          width: side,
                          height: constraints.maxHeight,
                          decoration: BoxDecoration(
                            color: entry.iconColor.withValues(alpha: 0.14),
                            borderRadius: AppTheme.cardRadius,
                          ),
                          child: Icon(
                            entry.icon,
                            color: entry.iconColor,
                            size: 34,
                          ),
                        ),
                      // A small badge keeps folders and playlists telling
                      // apart even when both show cover art.
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(
                            entry.icon,
                            size: 14,
                            // On cover art the badge always sits on a dark
                            // scrim, so it keeps the light accent.
                            color: cover == null
                                ? Colors.white
                                : AppTheme.accentOnDark,
                          ),
                        ),
                      ),
                      if (entry.onMenu != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(AppIcons.more_vert),
                            color: Colors.white,
                            onPressed: entry.onMenu,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
