import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/permission_service.dart';
import '../../../state/library_controller.dart';
import '../../common/empty_state.dart';
import '../../../core/theme/app_icons.dart';

/// Shown while the library is being scanned, or when permission is missing.
class LibraryStatusView extends StatelessWidget {
  const LibraryStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);

    if (library.status == LibraryStatus.denied) {
      return EmptyState(
        icon: AppIcons.lock_outline_rounded,
        title: context.s.accessNeeded,
        message:
            'Main Video reads the videos already on this device. Nothing is '
            'uploaded anywhere.',
        action: Wrap(
          spacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => library.load(force: true),
              child: Text(context.s.grantAccess),
            ),
            TextButton(
              onPressed: PermissionService.openSettings,
              child: Text(context.s.openSettings),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                value: library.scanProgress > 0 && library.scanProgress < 1
                    ? library.scanProgress
                    : null,
                color: context.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              library.scanMessage.isEmpty
                  ? context.s.gettingReady
                  : library.scanMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
