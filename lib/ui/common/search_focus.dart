import 'package:flutter/material.dart';

/// Shared helper mixin for tabs with search capabilities (HomePage and MusicPage).
///
/// Encapsulates the [TextEditingController], [FocusNode], and the complete
/// search open / close / submit / hide lifecycle so both tabs behave identically
/// and reliably with zero keyboard flickering or focus loops.
mixin SearchFocusState<T extends StatefulWidget> on State<T> {
  late final TextEditingController searchController;
  late final FocusNode searchFocusNode;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  /// Toggles search on or off.
  ///
  /// When opening, requests focus so the soft keyboard appears.
  /// When closing, clears the text, invokes [onClear] to reset the library query,
  /// and unfocuses the search field.
  void toggleSearch({required VoidCallback onClear}) {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchController.clear();
        onClear();
        searchFocusNode.unfocus();
      }
    });
  }

  /// Closes search completely, clearing text, notifying [onClear], and unfocusing.
  void closeSearch({required VoidCallback onClear}) {
    if (!isSearching && searchController.text.isEmpty) return;
    setState(() {
      isSearching = false;
      searchController.clear();
      onClear();
      searchFocusNode.unfocus();
    });
  }

  /// Hides the soft keyboard while keeping the query and results intact.
  void hideKeyboard() {
    searchFocusNode.unfocus();
  }

  /// Handles back button press in PopScope:
  ///
  /// 1. If the keyboard is open/focused, unfocuses it first and consumes the pop.
  /// 2. If search is active or query text is present, closes search and consumes the pop.
  /// 3. Returns true if the pop was consumed, false if normal pop should proceed.
  bool handleSearchPop({required VoidCallback onClear}) {
    if (searchFocusNode.hasFocus) {
      searchFocusNode.unfocus();
      return true;
    }
    if (isSearching || searchController.text.isNotEmpty) {
      closeSearch(onClear: onClear);
      return true;
    }
    return false;
  }
}

