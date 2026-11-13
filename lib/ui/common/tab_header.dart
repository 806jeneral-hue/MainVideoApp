import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../settings/settings_button.dart';
import 'glass.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

/// The header of a main tab: settings and search together at the start, the
/// title at the far end, and optionally one button for sort and layout — all
/// floating glass on a single row.
///
/// Search opens under the row, only while it is in use, so the header costs
/// no extra height the rest of the time.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    required this.searching,
    required this.searchController,
    required this.searchHint,
    required this.onQueryChanged,
    required this.onToggleSearch,
    required this.onSortAndLayout,
    this.onOpenFile,
    this.searchFocusNode,
    this.onSearchSubmitted,
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
  final bool searching;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleSearch;

  /// Null hides the button, for lists with nothing to sort.
  final VoidCallback? onSortAndLayout;

  /// Optional file / archive picker button.
  final VoidCallback? onOpenFile;

  /// Focus node for the search field (controls keyboard without autofocus loop).
  final FocusNode? searchFocusNode;

  /// Optional callback when the user taps the Search action on the keyboard.
  final ValueChanged<String>? onSearchSubmitted;

  /// Selection mode state and callbacks
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
          tooltip: searching ? s.closeSearch : s.search,
          icon: searching
              ? AppIcons.close_rounded
              : AppIcons.search_rounded,
          selected: searching,
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
            padding: const EdgeInsetsDirectional.only(
              start: AppTheme.space12,
            ),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: (!selectionMode && searching)
                ? Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space16),
                    child: GlassSearchField(
                      controller: searchController,
                      hint: searchHint,
                      onChanged: onQueryChanged,
                      focusNode: searchFocusNode,
                      onSubmitted: onSearchSubmitted,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The tab's name, pushed to the far end of the row. The classic look marks
/// it with a short accent bar in front, like a bookmark.
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
        // The bar sits before the name in reading order, whatever the
        // language: on the left of a Latin title.
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

/// Glass search field. It only changes how searching looks; the query goes
/// to whatever list the page already filters.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      radius: AppTheme.pillRadius,
      floating: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        onSubmitted: (value) {
          focusNode?.unfocus();
          onSubmitted?.call(value);
        },
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          prefixIcon: AppIcon(
            AppIcons.search_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
