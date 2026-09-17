import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_controller.dart';
import '../common/empty_state.dart';
import '../../core/theme/app_icons.dart';

/// Phase 3 — which real device folders are scanned, and which are hidden.
///
/// "All folders" is the default: the allow-list stays empty until the user
/// deliberately narrows it down.
class ScanFoldersPage extends StatelessWidget {
  const ScanFoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final folders = library.allFolders;
    final scanAll = library.scanFolders.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.scanFoldersTitle),
        actions: [
          if (!scanAll)
            TextButton(
              onPressed: () => library.setScanFolders(const []),
              child: Text(context.s.selectAll),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: folders.isEmpty
          ? EmptyState(
              icon: AppIcons.folder_off_outlined,
              title: context.s.noFoldersFound,
              message: context.s.noFoldersFoundBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: Text(
                    scanAll
                        ? context.s.scanningEverything
                        : context.s.scanningSome(
                            library.scanFolders.length,
                            folders.length,
                          ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ),
                for (final folder in folders)
                  _FolderCheck(
                    name: folder.name,
                    path: folder.path,
                    count: folder.count,
                    scanned: library.isFolderScanned(folder.path),
                    hidden: library.isFolderHidden(folder.path),
                    onScannedChanged: (value) => _setScanned(
                      library,
                      folders.map((f) => f.path).toList(),
                      folder.path,
                      value,
                    ),
                    onHiddenChanged: (_) =>
                        library.toggleHiddenFolder(folder.path),
                  ),
              ],
            ),
    );
  }

  /// Unchecking a folder while "all" is active turns the implicit list into an
  /// explicit one containing everything except that folder.
  void _setScanned(
    LibraryController library,
    List<String> allPaths,
    String path,
    bool value,
  ) {
    final current = library.scanFolders.isEmpty
        ? List<String>.from(allPaths)
        : List<String>.from(library.scanFolders);

    if (value) {
      if (!current.contains(path)) current.add(path);
    } else {
      current.remove(path);
    }

    // Back to the implicit "everything" state once all are checked again.
    if (current.length == allPaths.length) {
      library.setScanFolders(const []);
      return;
    }
    library.setScanFolders(current);
  }
}

class _FolderCheck extends StatelessWidget {
  const _FolderCheck({
    required this.name,
    required this.path,
    required this.count,
    required this.scanned,
    required this.hidden,
    required this.onScannedChanged,
    required this.onHiddenChanged,
  });

  final String name;
  final String path;
  final int count;
  final bool scanned;
  final bool hidden;
  final ValueChanged<bool> onScannedChanged;
  final ValueChanged<bool> onHiddenChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          child: Row(
            children: [
              Checkbox(
                value: scanned,
                activeColor: context.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (value) => onScannedChanged(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: hidden ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${context.s.videoCount(count)}  ·  $path',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: hidden ? context.s.unhideFolder : context.s.hideFolder,
                icon: Icon(
                  hidden
                      ? AppIcons.visibility_off_rounded
                      : AppIcons.visibility_outlined,
                  size: 20,
                  color: hidden ? context.accent : muted,
                ),
                onPressed: () => onHiddenChanged(!hidden),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
