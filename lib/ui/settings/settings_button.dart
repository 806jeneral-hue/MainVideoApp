import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../common/glass.dart';
import 'settings_page.dart';
import '../../core/theme/app_icons.dart';

/// The gear that opens Settings, in the same corner of every main tab's
/// header.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.size = 46});

  final double size;

  /// Width an [AppBar] needs for [SettingsButton.leading].
  static const double leadingWidth = AppTheme.pageMargin + 42 + AppTheme.space8;

  /// Sized and inset for an [AppBar]'s leading slot, so it lines up with the
  /// page margin like the header buttons on Home.
  static Widget leading() => const Padding(
    padding: EdgeInsetsDirectional.only(start: AppTheme.pageMargin),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: SettingsButton(size: 42),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: AppIcons.settings_outlined,
      tooltip: context.s.settings,
      size: size,
      iconSize: size * 0.48,
      onPressed: () => SettingsPage.open(context),
    );
  }
}
