import 'package:flutter/material.dart';

import 'strings.dart';

export 'enum_labels.dart';
export 'bookmark_strings.dart';
export 'music_strings.dart';
export 'player_strings.dart';

export 'strings.dart';

/// Delivers the right [Strings] for the active locale, and gives every widget
/// a short way to reach them: `context.s`.
class AppLocalizations {
  const AppLocalizations._();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<Strings> delegate = _StringsDelegate();

  static Strings stringsFor(Locale locale) =>
      locale.languageCode == 'ar' ? const StringsAr() : const StringsEn();
}

class _StringsDelegate extends LocalizationsDelegate<Strings> {
  const _StringsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<Strings> load(Locale locale) async =>
      AppLocalizations.stringsFor(locale);

  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  /// The translated strings for the current locale.
  Strings get s => Localizations.of<Strings>(this, Strings)!;

  /// True while the interface is laid out right to left.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
