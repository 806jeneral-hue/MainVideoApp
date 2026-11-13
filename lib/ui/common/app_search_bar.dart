import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/services/recent_searches_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'glass.dart';

// ---------------------------------------------------------------------------
// Search constants
// ---------------------------------------------------------------------------
const Duration kSearchDebounceDuration = Duration(milliseconds: 300);

// Debug logging flag. Keep false in production.
const bool kSearchDebugLog = false;

void _log(String msg) {
  if (kSearchDebugLog) {
    // ignore: avoid_print
    debugPrint('[AppSearchBar] $msg');
  }
}

/// A self-contained search bar that manages its own [TextEditingController]
/// and [FocusNode].
///
/// Features:
/// - Built-in debouncing ([kSearchDebounceDuration]).
/// - Optional recent searches panel when focused and empty ([recentStorageKey]).
/// - Safe keyboard management with single source of truth.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.isOpen,
    required this.hint,
    required this.onChanged,
    required this.onClosed,
    this.initialQuery,
    this.recentStorageKey,
  });

  final bool isOpen;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClosed;
  final String? initialQuery;
  final String? recentStorageKey;

  @override
  AppSearchBarState createState() => AppSearchBarState();
}

class AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _shouldAutofocus = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode();
    _shouldAutofocus =
        widget.isOpen && (widget.initialQuery == null || widget.initialQuery!.isEmpty);

    _focusNode.addListener(_onFocusOrTextChanged);
    _controller.addListener(_onFocusOrTextChanged);
    _log('initState isOpen=${widget.isOpen}');
  }

  void _onFocusOrTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      _log('didUpdateWidget: opened');
      _shouldAutofocus = true;
    } else if (oldWidget.isOpen && !widget.isOpen) {
      _log('didUpdateWidget: closed');
      _debounceTimer?.cancel();
      _shouldAutofocus = false;
      _focusNode.unfocus();
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusOrTextChanged);
    _controller.removeListener(_onFocusOrTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _log('dispose');
    super.dispose();
  }

  // ----------------------------------------------------------------- public API

  /// Whether the search bar is currently visible.
  bool get isOpen => widget.isOpen;

  /// Hides the soft keyboard while keeping the search bar open and the query intact.
  void hideKeyboard() {
    _log('hideKeyboard()');
    _shouldAutofocus = false;
    _focusNode.unfocus();
  }

  /// Saves [query] (or current text) to recent searches if configured.
  void saveQueryToRecent([String? query]) {
    final key = widget.recentStorageKey;
    final q = (query ?? _controller.text).trim();
    if (key != null && q.isNotEmpty) {
      RecentSearchesService.addRecent(key, q);
    }
  }

  /// Handles back-button presses for the page's [PopScope.onPopInvokedWithResult].
  bool handlePop() {
    if (_focusNode.hasFocus) {
      _log('handlePop → hide keyboard');
      _shouldAutofocus = false;
      _focusNode.unfocus();
      return true;
    }
    if (widget.isOpen) {
      _log('handlePop → close search');
      _debounceTimer?.cancel();
      _shouldAutofocus = false;
      _focusNode.unfocus();
      _controller.clear();
      widget.onClosed();
      return true;
    }
    return false;
  }

  // ----------------------------------------------------------------- private

  void _onChanged(String value) {
    _log('onChanged: "$value"');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(kSearchDebounceDuration, () {
      if (mounted) {
        widget.onChanged(value);
      }
    });
  }

  void _onSubmitted(String value) {
    _log('onSubmitted: "$value"');
    _debounceTimer?.cancel();
    widget.onChanged(value);
    saveQueryToRecent(value);
    _shouldAutofocus = false;
    _focusNode.unfocus();
  }

  void _onClearTapped() {
    _debounceTimer?.cancel();
    if (_controller.text.isEmpty) {
      // Field is already empty: treat the button as a close.
      _shouldAutofocus = false;
      _focusNode.unfocus();
      widget.onClosed();
    } else {
      _log('clear text');
      _controller.clear();
      widget.onChanged('');
      // Keep focus so the user can type a new query immediately.
    }
  }

  void _onRecentTapped(String query) {
    _debounceTimer?.cancel();
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    widget.onChanged(query);
    saveQueryToRecent(query);
    _shouldAutofocus = false;
    _focusNode.unfocus();
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    _log('build isOpen=${widget.isOpen}');

    final showRecent = widget.isOpen &&
        widget.recentStorageKey != null &&
        _focusNode.hasFocus &&
        _controller.text.trim().isEmpty;

    final recentList = showRecent
        ? RecentSearchesService.getRecent(widget.recentStorageKey!)
        : const <String>[];

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: widget.isOpen
          ? Padding(
              padding: const EdgeInsets.only(top: AppTheme.space16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: _shouldAutofocus,
                    hint: widget.hint,
                    onChanged: _onChanged,
                    onSubmitted: _onSubmitted,
                    onClearTapped: _onClearTapped,
                  ),
                  if (showRecent && recentList.isNotEmpty)
                    _RecentSearchesPanel(
                      recentQueries: recentList,
                      onTapQuery: _onRecentTapped,
                      onRemoveQuery: (query) async {
                        await RecentSearchesService.removeRecent(
                          widget.recentStorageKey!,
                          query,
                        );
                        if (mounted) setState(() {});
                      },
                      onClearAll: () async {
                        await RecentSearchesService.clearRecent(
                          widget.recentStorageKey!,
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Searches Panel
// ---------------------------------------------------------------------------

class _RecentSearchesPanel extends StatelessWidget {
  const _RecentSearchesPanel({
    required this.recentQueries,
    required this.onTapQuery,
    required this.onRemoveQuery,
    required this.onClearAll,
  });

  final List<String> recentQueries;
  final ValueChanged<String> onTapQuery;
  final ValueChanged<String> onRemoveQuery;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.90)
            : theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.history_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.s.recentSearches,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              InkWell(
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(8),
                onTap: onClearAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    context.s.clearAll,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final query in recentQueries)
                _RecentSearchChip(
                  query: query,
                  onTap: () => onTapQuery(query),
                  onRemove: () => onRemoveQuery(query),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 10,
            end: 4,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.search_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    AppIcons.close_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private field widget — purely presentational
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearTapped,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _log('_SearchField build');

    return GlassSurface(
      radius: AppTheme.pillRadius,
      floating: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Icon(
              AppIcons.search_rounded,
              size: 22,
              color: theme.colorScheme.primary,
            ),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: IconButton(
                  onPressed: onClearTapped,
                  icon: Icon(
                    value.text.isEmpty
                        ? AppIcons.close_rounded
                        : AppIcons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  splashRadius: 18,
                  tooltip: value.text.isEmpty ? 'إغلاق البحث' : 'مسح',
                ),
              );
            },
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
