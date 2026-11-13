import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'glass.dart';

// ---------------------------------------------------------------------------
// Debug logging flag.
// Set to true to print focus / keyboard / viewInsets events to the console.
// Keep false in production.
// ---------------------------------------------------------------------------
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
/// **Single Source of Truth**
/// - The open/close state is driven by [isOpen].
/// - The parent page owns the boolean (e.g. `_isSearchOpen`) and passes it
///   consistently to both [AppSearchBar] and [TabHeader].
/// - [onClosed] is called whenever search is dismissed (via back button,
///   empty clear button tap, etc.) so the parent can update its state.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.isOpen,
    required this.hint,
    required this.onChanged,
    required this.onClosed,
    this.initialQuery,
  });

  final bool isOpen;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClosed;
  final String? initialQuery;

  @override
  AppSearchBarState createState() => AppSearchBarState();
}

class AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _shouldAutofocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode();
    _shouldAutofocus =
        widget.isOpen && (widget.initialQuery == null || widget.initialQuery!.isEmpty);
    if (kSearchDebugLog) {
      _focusNode.addListener(_onFocusChange);
    }
    _log('initState isOpen=${widget.isOpen}');
  }

  void _onFocusChange() {
    _log('focus changed → hasFocus=${_focusNode.hasFocus}');
  }

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      _log('didUpdateWidget: opened');
      _shouldAutofocus = true;
    } else if (oldWidget.isOpen && !widget.isOpen) {
      _log('didUpdateWidget: closed');
      _shouldAutofocus = false;
      _focusNode.unfocus();
      _controller.clear();
    }
  }

  @override
  void dispose() {
    if (kSearchDebugLog) {
      _focusNode.removeListener(_onFocusChange);
    }
    _controller.dispose();
    _focusNode.dispose();
    _log('dispose');
    super.dispose();
  }

  // ----------------------------------------------------------------- public API

  /// Whether the search bar is currently visible.
  bool get isOpen => widget.isOpen;

  /// Hides the soft keyboard while keeping the search bar open and the query intact.
  /// Call this when the user plays a result or navigates away.
  void hideKeyboard() {
    _log('hideKeyboard()');
    _shouldAutofocus = false;
    _focusNode.unfocus();
  }

  /// Handles back-button presses for the page's [PopScope.onPopInvokedWithResult].
  ///
  /// - If the keyboard is open: hides it, returns true (consumes the pop).
  /// - If search is open: closes it via [onClosed], returns true.
  /// - Otherwise: returns false (let the pop proceed normally).
  bool handlePop() {
    if (_focusNode.hasFocus) {
      _log('handlePop → hide keyboard');
      _shouldAutofocus = false;
      _focusNode.unfocus();
      return true;
    }
    if (widget.isOpen) {
      _log('handlePop → close search');
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
    widget.onChanged(value);
  }

  void _onSubmitted(String value) {
    _log('onSubmitted: "$value"');
    _shouldAutofocus = false;
    _focusNode.unfocus();
  }

  void _onClearTapped() {
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

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    _log('build isOpen=${widget.isOpen}');

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: widget.isOpen
          ? Padding(
              padding: const EdgeInsets.only(top: AppTheme.space16),
              child: _SearchField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: _shouldAutofocus,
                hint: widget.hint,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
                onClearTapped: _onClearTapped,
              ),
            )
          : const SizedBox(width: double.infinity),
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
              return IconButton(
                onPressed: onClearTapped,
                icon: Icon(
                  value.text.isEmpty ? AppIcons.close_rounded : AppIcons.close_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                splashRadius: 18,
                tooltip: value.text.isEmpty ? 'إغلاق البحث' : 'مسح',
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
