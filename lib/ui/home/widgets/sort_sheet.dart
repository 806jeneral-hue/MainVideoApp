import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/app_sheet.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/collection_prefs.dart';
import '../../../data/models/enums.dart';
import '../../../state/library_controller.dart';
import '../../common/glass_controls.dart';
import '../../../core/theme/app_icons.dart';

/// Sort options for one particular list.
///
/// Each folder, playlist, favourites and the home screen keeps its own order,
/// so this always edits the collection it was opened from — including the
/// hand-made order built by dragging rows.
Future<void> showSortSheet(
  BuildContext context,
  CollectionKey collection, {
  bool allowManual = true,

  /// Adds the list / grid choice at the top, for headers that fold both into
  /// one button.
  bool showViewMode = false,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _SortSheet(
      collection: collection,
      allowManual: allowManual,
      showViewMode: showViewMode,
    ),
  );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({
    required this.collection,
    required this.allowManual,
    required this.showViewMode,
  });

  final CollectionKey collection;
  final bool allowManual;
  final bool showViewMode;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final prefs = library.prefsFor(collection);

    final fields = SortField.values
        .where((f) => allowManual || f != SortField.manual)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showViewMode) ...[
            GlassSheetTitle(context.s.viewLayout),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageMargin,
                AppTheme.space4,
                AppTheme.pageMargin,
                AppTheme.space16,
              ),
              child: GlassSegmented<ViewMode>(
                segments: [
                  GlassSegment(
                    value: ViewMode.list,
                    icon: AppIcons.view_agenda_rounded,
                    label: context.s.listView,
                  ),
                  GlassSegment(
                    value: ViewMode.compact,
                    icon: AppIcons.view_list_rounded,
                    label: context.s.compactView,
                  ),
                  GlassSegment(
                    value: ViewMode.grid,
                    icon: AppIcons.grid_view_rounded,
                    label: context.s.gridView,
                  ),
                ],
                selected: library.viewMode,
                onChanged: library.setViewMode,
              ),
            ),
          ],
          GlassSheetTitle(context.s.sortBy),
          for (final field in fields)
            GlassTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: Icon(
                field == SortField.manual
                    ? AppIcons.drag_indicator_rounded
                    : AppIcons.sort_rounded,
                color: prefs.sortField == field ? context.accent : null,
              ),
              title: Text(field.label(context.s)),
              subtitle: field == SortField.manual
                  ? Text(context.s.sortCustomHint)
                  : null,
              selected: prefs.sortField == field,
              trailing: prefs.sortField == field
                  ? Icon(AppIcons.check_rounded, color: context.accent)
                  : null,
              onTap: () {
                library.setSortFor(collection, field);
                Navigator.pop(context);
              },
            ),
          if (prefs.sortField.hasDirection) ...[
            const SizedBox(height: AppTheme.space12),
            GlassSheetTitle(context.s.order),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageMargin,
                AppTheme.space4,
                AppTheme.pageMargin,
                AppTheme.space8,
              ),
              child: GlassSegmented<bool>(
                segments: [
                  GlassSegment(
                    value: true,
                    icon: AppIcons.south_rounded,
                    label: context.s.descending,
                  ),
                  GlassSegment(
                    value: false,
                    icon: AppIcons.north_rounded,
                    label: context.s.ascending,
                  ),
                ],
                selected: prefs.descending,
                onChanged: (_) => library.toggleSortDirectionFor(collection),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
