import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../settings/settings_button.dart';
import 'glass.dart';
import '../../core/theme/app_icons.dart';

/// The header of a main tab: settings and search at the start, the title at
/// the far end, and optionally a sort-and-layout button — all floating glass
/// on a single row.
///
/// Search state is now fully owned by the page. The header simply accepts an
/// optional [searchBarSlot] widget that it places below the button row (inside
/// an [AnimatedSize] so the header grows/shrinks smoothly). The page builds
/// and passes an [AppSearchBar] when search is open.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.onSortAndLayout,
    required this.searchBarSlot,
    this.onOpenFile,
    this.selectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onCloseSelection,
    this.onSelectAll,
    this.onDeselectAll,
    this.onToggleViewMode,
    this.currentViewMode,
  });

  final String title;

  /// Whether the search button should appear in its "close" / active state.
  final bool searchOpen;

  /// Called when the search icon button is tapped.
  final VoidCallback onToggleSearch;

  /// Null hides the sort-and-layout button, for lists with nothing to sort.
  final VoidCallback? onSortAndLayout;

  /// Optional file / archive picker button.
  final VoidCallback? onOpenFile;

  /// The search bar widget to place below the button row.
  /// Pass [SizedBox.shrink()] (or null) when search is closed.
  /// Pass an [AppSearchBar] instance when open.
  final Widget searchBarSlot;

  /// Selection mode state and callbacks.
  final bool selectionMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onCloseSelection;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onToggleViewMode;
  final ViewMode? currentViewMode;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    final normalRow = Row(
      key: const ValueKey('tab_header_normal_row'),
      children: [
        const SettingsButton(),
        const SizedBox(width: AppTheme.space12),
        GlassIconButton(
          tooltip: searchOpen ? s.closeSearch : s.search,
          icon: searchOpen ? AppIcons.close_rounded : AppIcons.search_rounded,
          selected: searchOpen,
          onPressed: onToggleSearch,
        ),
        if (onOpenFile != null) ...[
          const SizedBox(width: AppTheme.space12),
          GlassIconButton(
            tooltip: 'فتح ملف أو أرشيف مضغوط',
            icon: Icons.folder_zip_rounded,
            onPressed: onOpenFile,
          ),
        ],
        if (onSortAndLayout != null) ...[
          const SizedBox(width: AppTheme.space12),
          GlassIconButton(
            tooltip: s.sortAndLayout,
            icon: AppIcons.swap_vert_rounded,
            onPressed: onSortAndLayout,
          ),
        ],
        // The title fills the rest of the row, pushed to the far end.
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: AppTheme.space12),
            child: _Title(title),
          ),
        ),
      ],
    );

    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final selectionRow = Row(
      key: const ValueKey('tab_header_selection_row'),
      children: [
        GlassIconButton(
          icon: AppIcons.close_rounded,
          tooltip: s.cancel,
          onPressed: onCloseSelection,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppTheme.space12,
              end: AppTheme.space8,
            ),
            child: Text(
              s.selectedCount(selectedCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (onToggleViewMode != null && currentViewMode != null) ...[
          GlassIconButton(
            tooltip: switch (currentViewMode!) {
              ViewMode.list => s.compactView,
              ViewMode.compact => s.gridView,
              ViewMode.grid => s.listView,
            },
            icon: switch (currentViewMode!) {
              ViewMode.list => AppIcons.view_list_rounded,
              ViewMode.compact => AppIcons.grid_view_rounded,
              ViewMode.grid => AppIcons.view_agenda_rounded,
            },
            onPressed: onToggleViewMode,
          ),
          const SizedBox(width: AppTheme.space12),
        ],
        GlassIconButton(
          icon: allSelected
              ? AppIcons.checklist_rounded
              : AppIcons.select_all_rounded,
          tooltip: allSelected ? s.deselectAll : s.selectAll,
          onPressed: allSelected ? onDeselectAll : onSelectAll,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.pageMargin,
        MediaQuery.paddingOf(context).top + AppTheme.space12,
        AppTheme.pageMargin,
        AppTheme.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectionMode ? selectionRow : normalRow,
          ),
          // The search bar slot is provided by the page. When search is closed
          // the page passes SizedBox.shrink() so this collapses to zero height.
          if (!selectionMode) searchBarSlot,
        ],
      ),
    );
  }
}

/// The tab's name, pushed to the far end of the row.
class _Title extends StatelessWidget {
  const _Title(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
    if (!AppTheme.isSolid) return text;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: 5,
            height: 30,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Flexible(child: text),
        ],
      ),
    );
  }
}
