import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';

/// Loads [AppLocalizations] for the active app locale (no [BuildContext]).
class AppLocalizationsHelper {
  AppLocalizationsHelper._();

  static Future<AppLocalizations> current() {
    return AppLocalizations.delegate.load(
      Locale(AppLocaleHolder.instance.languageCode),
    );
  }
}
