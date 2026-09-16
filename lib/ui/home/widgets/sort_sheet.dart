import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/app_sheet.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/collection_prefs.dart';
import '../../../data/models/enums.dart';
import '../../../state/library_controller.dart';

/// Sort options for one particular list.
///
/// Each folder, playlist, favourites and the home screen keeps its own order,
/// so this always edits the collection it was opened from — including the
/// hand-made order built by dragging rows.
Future<void> showSortSheet(
  BuildContext context,
  CollectionKey collection, {
  bool allowManual = true,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) =>
        _SortSheet(collection: collection, allowManual: allowManual),
  );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.collection, required this.allowManual});

  final CollectionKey collection;
  final bool allowManual;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);
    final prefs = library.prefsFor(collection);

    final fields = SortField.values
        .where((f) => allowManual || f != SortField.manual)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Text(
              'Sort by',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final field in fields)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: Icon(
                field == SortField.manual
                    ? Icons.drag_indicator_rounded
                    : Icons.sort_rounded,
                color: prefs.sortField == field ? context.accent : null,
              ),
              title: Text(field.label(context.s)),
              subtitle: field == SortField.manual
                  ? Text(context.s.sortCustomHint)
                  : null,
              trailing: prefs.sortField == field
                  ? Icon(Icons.check_rounded, color: context.accent)
                  : null,
              onTap: () {
                library.setSortFor(collection, field);
                Navigator.pop(context);
              },
            ),
          if (prefs.sortField.hasDirection) ...[
            const Divider(height: 24, indent: 22, endIndent: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.s.order,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.south, size: 16),
                        label: Text(context.s.descending),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.north, size: 16),
                        label: Text(context.s.ascending),
                      ),
                    ],
                    selected: {prefs.descending},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      if (value.first != prefs.descending) {
                        library.toggleSortDirectionFor(collection);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
