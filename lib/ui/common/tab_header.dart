import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
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
  });

  final String title;
  final bool searching;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleSearch;

  /// Null hides the button, for lists with nothing to sort.
  final VoidCallback? onSortAndLayout;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

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
          Row(
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
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: searching
                ? Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space16),
                    child: GlassSearchField(
                      controller: searchController,
                      hint: searchHint,
                      onChanged: onQueryChanged,
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
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      radius: AppTheme.pillRadius,
      floating: true,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
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
