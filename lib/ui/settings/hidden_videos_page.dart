import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/library_controller.dart';
import '../common/empty_state.dart';
import '../common/video_thumbnail.dart';
import '../../core/theme/app_icons.dart';

/// The videos the user hid one by one, and a way to bring them back.
class HiddenVideosPage extends StatelessWidget {
  const HiddenVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final videos = library.hiddenVideos;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.hiddenVideos),
        actions: [
          if (videos.isNotEmpty)
            TextButton(
              onPressed: () => library.setVideosHidden(
                videos.map((v) => v.id).toList(),
                false,
              ),
              child: Text(context.s.unhideAll),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: videos.isEmpty
          ? EmptyState(
              icon: AppIcons.visibility_off_outlined,
              title: context.s.noHiddenVideos,
              message: context.s.noHiddenVideosBody,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final theme = Theme.of(context);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                      child: Row(
                        children: [
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
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${Fmt.fileSize(video.sizeBytes)}  ·  ${video.folderName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: context.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: context.s.unhideVideo,
                            icon: const Icon(AppIcons.visibility_rounded),
                            color: context.accent,
                            onPressed: () =>
                                library.toggleVideoHidden(video.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
