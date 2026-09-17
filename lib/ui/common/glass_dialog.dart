import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The app's dialog: frosted glass with the same blur, fill and edge as the
/// bottom sheets, in place of Material's flat surface.
///
/// It takes what the app's dialogs use from [AlertDialog] — a title, the
/// content and the actions — so swapping one for the other changes nothing
/// but the look.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
  });

  final Widget title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppTheme.radiusSheet);

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space24,
        vertical: AppTheme.space24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppTheme.floatingShadow(theme.brightness),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              // Stronger than the sheets' blur and a much thinner fill, so the
              // page behind reads through as frosted glass rather than the
              // dialog looking like a white card.
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.06),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.48),
                          ],
                  ),
                  borderRadius: radius,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space24,
                    AppTheme.space24,
                    AppTheme.space24,
                    AppTheme.space16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DefaultTextStyle.merge(
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        child: title,
                      ),
                      if (content != null) ...[
                        const SizedBox(height: AppTheme.space12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: DefaultTextStyle.merge(
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: context.muted,
                                height: 1.45,
                              ),
                              child: content!,
                            ),
                          ),
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space20),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: AppTheme.space8,
                          overflowSpacing: AppTheme.space8,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
