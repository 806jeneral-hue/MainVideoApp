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
