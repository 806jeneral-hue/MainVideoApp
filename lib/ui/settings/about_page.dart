import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Phase 7 — version and a short note about what the app does.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// Kept in step with `version:` in pubspec.yaml.
  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Scaffold(
      appBar: AppBar(title: Text(context.s.about)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 32),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 44,
                color: context.accent,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              context.s.appTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              context.s.version(version),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          const SizedBox(height: 30),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                context.s.aboutBody,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
