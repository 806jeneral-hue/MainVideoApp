import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';

/// Paints the background picture chosen in Settings behind every screen.
///
/// The picture is blurred once and cached as its own layer, so scrolling the
/// glass cards over it does not re-run the blur. A soft wash in the page
/// colour keeps text readable on any photo.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (path, blur) = context.select<SettingsController, (String?, double)>(
      (s) => (s.backgroundImage, s.backgroundBlur),
    );
    if (path == null) return child;

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Decode at screen size, not the photo's full resolution.
    final decodeWidth = (media.size.shortestSide * media.devicePixelRatio)
        .round();

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: theme.canvasColor),
        RepaintBoundary(
          child: ImageFiltered(
            enabled: blur > 0,
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: decodeWidth,
              gaplessPlayback: true,
              // A missing file just falls back to the plain page.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(alpha: 0.42)
              : theme.canvasColor.withValues(alpha: 0.38),
        ),
        child,
      ],
    );
  }
}
