import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_sheet.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/playlist_style.dart';
import '../../data/models/playlist.dart';
import '../../state/library_controller.dart';

/// Gives a playlist its own colour and icon, so it is recognisable at a glance
/// in the Folders screen.
Future<void> showPlaylistStyleSheet(BuildContext context, Playlist playlist) {
  return showAppSheet<void>(
    context,
    hasOwnScroll: true,
    builder: (_) => _PlaylistStyleSheet(playlistId: playlist.id),
  );
}

class _PlaylistStyleSheet extends StatelessWidget {
  const _PlaylistStyleSheet({required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final playlist = library.playlistById(playlistId);
    if (playlist == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = PlaylistStyle.colorFor(playlist.colorValue);
    final icon = PlaylistStyle.iconFor(playlist.iconKey);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: AppTheme.thumbRadius,
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Label(context.s.colorLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final option in PlaylistStyle.colors)
                    _ColorDot(
                      color: option,
                      // ignore: deprecated_member_use
                      selected: color.toARGB32() == option.toARGB32(),
                      onTap: () => library.setPlaylistStyle(
                        playlist.id,
                        // ignore: deprecated_member_use
                        colorValue: option.toARGB32(),
                      ),
                    ),
                ],
              ),
            ),
            _Label(context.s.iconLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in PlaylistStyle.icons.entries)
                    _IconTile(
                      icon: entry.value,
                      color: color,
                      selected: icon == entry.value,
                      onTap: () => library.setPlaylistStyle(
                        playlist.id,
                        iconKey: entry.key,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: TextButton.icon(
                onPressed: () => library.setPlaylistStyle(
                  playlist.id,
                  clearColor: true,
                  clearIcon: true,
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(context.s.resetToDefault),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.thumbRadius,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppTheme.thumbRadius,
          border: selected ? Border.all(color: color, width: 1.6) : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected
              ? color
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
