import 'package:flutter/material.dart';

/// Hands each bottom-navigation tab the scroll controller the shell owns for
/// it, so tapping the tab you are already on can send that list back to the
/// top.
///
/// Pages look it up with [maybeOf]; when it is absent — a pushed route rather
/// than a tab — they fall back to their own controller.
class TabScroll extends InheritedWidget {
  const TabScroll({super.key, required this.controller, required super.child});

  final ScrollController controller;

  static ScrollController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabScroll>()?.controller;

  /// Whether [context] is inside one of the main tabs rather than a page
  /// opened on top of them. Safe to call from event handlers.
  static bool isTab(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabScroll>() != null;

  @override
  bool updateShouldNotify(TabScroll oldWidget) =>
      oldWidget.controller != controller;
}

/// Sends a list back to the top, if it is attached and not already there.
Future<void> scrollToTop(ScrollController controller) async {
  if (!controller.hasClients) return;
  if (controller.offset <= 0) return;
  await controller.animateTo(
    0,
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );
}

/// Allows tabs inside [HomeShell] to replace the bottom navigation bar with an
/// active selection actions bar without resizing the page or cutting content.
class TabSelectionBridge extends InheritedWidget {
  const TabSelectionBridge({
    super.key,
    required this.selectionBarNotifier,
    required super.child,
  });

  final ValueNotifier<Widget?> selectionBarNotifier;

  static ValueNotifier<Widget?>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabSelectionBridge>()?.selectionBarNotifier;

  static void set(BuildContext context, Widget? bar) {
    final notifier = context
        .getInheritedWidgetOfExactType<TabSelectionBridge>()
        ?.selectionBarNotifier;
    if (notifier != null && notifier.value != bar) {
      notifier.value = bar;
    }
  }

  @override
  bool updateShouldNotify(TabSelectionBridge oldWidget) =>
      oldWidget.selectionBarNotifier != selectionBarNotifier;
}
