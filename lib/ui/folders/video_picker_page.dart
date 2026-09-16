import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/collection_prefs.dart';
import '../../data/models/video.dart';
import '../../state/library_controller.dart';
import '../common/empty_state.dart';
import '../common/video_thumbnail.dart';

/// Multi-select picker used when adding videos to a playlist. Videos can be
/// picked from anywhere on the device, not just one folder (phase 3).
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

class _VideoPickerPageState extends State<VideoPickerPage> {
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    final available = library.visibleVideos
        .where((v) => !widget.excluded.contains(v.id))
        .toList();
    final q = _query.trim().toLowerCase();
    final videos = library.orderVideos(
      CollectionKey.home,
      q.isEmpty
          ? available
          : available.where((v) => v.title.toLowerCase().contains(q)).toList(),
    );

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
                hintText: context.s.searchVideos,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.pop(context, _selected.toList()),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.s.addCount(_selected.length)),
            ),
      body: videos.isEmpty
          ? EmptyState(
              icon: Icons.movie_outlined,
              title: context.s.nothingToAdd,
              message: context.s.nothingToAddBody,
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return _PickerTile(
                  video: video,
                  selected: _selected.contains(video.id),
                  onTap: () => setState(() {
                    if (!_selected.remove(video.id)) _selected.add(video.id);
                  }),
                );
              },
            ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final Video video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            VideoThumbnail(video: video, width: 96, height: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${Fmt.fileSize(video.sizeBytes)}  ·  ${video.folderName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
