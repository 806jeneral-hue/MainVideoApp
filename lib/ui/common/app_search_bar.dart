import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'glass.dart';

// ---------------------------------------------------------------------------
// Debug logging flag.
// Set to true to print focus / keyboard / viewInsets events to the console.
// Keep false in production — this is a compile-time constant so the compiler
// strips every if-block when it is false.
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
/// **Usage contract**
/// - The *page* owns a [GlobalKey<AppSearchBarState>] and calls
///   [AppSearchBarState.open] / [AppSearchBarState.close] imperatively.
/// - The page does NOT manage focus, controllers, or keyboard state.
/// - Callbacks [onChanged] and [onClosed] notify the page of query and
///   close events.
///
/// **Focus safety**
/// - Only [autofocus: true] is used when the field is first inserted.
///   [requestFocus] is never called manually.
/// - [unfocus] is called only inside [onSubmitted], [close], and when the
///   user taps the clear/close button — never from [build], listeners, or
///   post-frame callbacks.
/// - No [WidgetsBindingObserver] / [didChangeMetrics].
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.onClosed,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClosed;

  @override
  AppSearchBarState createState() => AppSearchBarState();
}

class AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    if (kSearchDebugLog) {
      _focusNode.addListener(_onFocusChange);
    }
    _log('initState');
  }

  void _onFocusChange() {
    _log('focus changed → hasFocus=${_focusNode.hasFocus}');
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
  bool get isOpen => _open;

  /// Opens the search bar. The field will gain focus through [autofocus: true]
  /// the first time it is built — no manual [requestFocus] call needed.
  void open() {
    if (_open) return;
    _log('open()');
    setState(() => _open = true);
  }

  /// Closes the search bar, clears the text, unfocuses, and fires [onClosed].
  void close() {
    if (!_open) return;
    _log('close()');
    _focusNode.unfocus();
    _controller.clear();
    setState(() => _open = false);
    widget.onClosed();
  }

  /// Hides the soft keyboard while keeping the search bar open and the query intact.
  /// Call this when the user plays a result or the page navigates away.
  void hideKeyboard() {
    _log('hideKeyboard()');
    _focusNode.unfocus();
  }

  /// Handles back-button presses for the page's [PopScope.onPopInvokedWithResult].
  ///
  /// - If the keyboard is open: hides it, returns true (consumes the pop).
  /// - If search is open: closes it, returns true.
  /// - Otherwise: returns false (let the pop proceed normally).
  bool handlePop() {
    if (_focusNode.hasFocus) {
      _log('handlePop → hide keyboard');
      _focusNode.unfocus();
      return true;
    }
    if (_open) {
      _log('handlePop → close search');
      close();
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
    _focusNode.unfocus();
    // Do not call onChanged again; the query is already up to date.
  }

  void _onClearTapped() {
    if (_controller.text.isEmpty) {
      // Field is already empty: treat the button as a close.
      close();
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
    _log('build open=$_open');

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _open
          ? Padding(
              padding: const EdgeInsets.only(top: AppTheme.space16),
              child: _SearchField(
                controller: _controller,
                focusNode: _focusNode,
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
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearTapped,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
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
        // autofocus: true causes the keyboard to open exactly once when the
        // field is first inserted into the tree. No manual requestFocus needed.
        autofocus: true,
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
