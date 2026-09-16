import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/video.dart';
import '../common/video_thumbnail.dart';

/// Everything known about one file (phase 6).
class VideoInfoPage extends StatelessWidget {
  const VideoInfoPage({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.s.videoInfoTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          Center(
            child: VideoThumbnail(
              video: video,
              width: MediaQuery.sizeOf(context).width - 36,
              height: (MediaQuery.sizeOf(context).width - 36) * 9 / 16,
              borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
              showDuration: false,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            video.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          _InfoCard(
            rows: [
              _Row(context.s.infoName, video.title),
              _Row(context.s.infoType, video.fileType),
              _Row(context.s.infoResolution, video.resolution),
              _Row(context.s.infoLength, Fmt.durationMs(video.durationMs)),
              _Row(context.s.infoSize, Fmt.fileSize(video.sizeBytes)),
              _Row(context.s.infoFolder, video.folderName),
              _Row(
                context.s.infoDateAdded,
                Fmt.dateTime(video.dateAdded, context.s),
              ),
              _Row(
                context.s.infoDateModified,
                Fmt.dateTime(video.dateModified, context.s),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PathCard(path: video.path),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 116,
                      child: Text(
                        rows[i].label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i != rows.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.s.infoPath,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    path,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.s.copyPath,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: path));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Path copied')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
