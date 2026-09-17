import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/trashed_video.dart';
import '../../state/library_controller.dart';
import '../common/empty_state.dart';
import '../common/glass_dialog.dart';
import '../common/glass_snack_bar.dart';
import '../../core/theme/app_icons.dart';

/// What is waiting in the recycle bin, with a way to put it back or erase it.
class RecycleBinPage extends StatelessWidget {
  const RecycleBinPage({super.key});

  /// Matches `SettingsRepository.recycleBinDays`.
  static const int keepDays = 30;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final items = library.trashedVideos;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.recycleBin),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmpty(context, library),
              child: Text(
                context.s.emptyBin,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: AppIcons.delete_outline_rounded,
              title: context.s.recycleBinEmpty,
              message: context.s.recycleBinEmptyBody,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _BinTile(item: items[index], library: library),
            ),
    );
  }

  Future<void> _confirmEmpty(
    BuildContext context,
    LibraryController library,
  ) async {
    final s = context.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: Text(s.emptyBin),
        content: Text(s.emptyBinConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.deleteForever),
          ),
        ],
      ),
    );
    if (confirmed == true) await library.emptyRecycleBin();
  }
}

class _BinTile extends StatelessWidget {
  const _BinTile({required this.item, required this.library});

  final TrashedVideo item;
  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppTheme.thumbRadius,
                ),
                child: Icon(AppIcons.movie_outlined, color: context.muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Fmt.fileSize(item.sizeBytes)}  ·  '
                      '${s.daysLeft(item.daysLeft(RecycleBinPage.keepDays))}',
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
                tooltip: s.restore,
                icon: const Icon(AppIcons.restore_rounded),
                color: context.accent,
                onPressed: () => _restore(context),
              ),
              IconButton(
                tooltip: s.deleteForever,
                icon: const Icon(AppIcons.delete_forever_rounded),
                color: Colors.redAccent,
                onPressed: () => library.deleteFromBinForever(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final error = await library.restoreFromBin(item);
    messenger.showSnackBar(glassSnackBar(content: Text(error ?? s.restored)));
  }
}
