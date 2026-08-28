import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';

/// Supported app locales — keep in sync with `lib/l10n/app_*.arb` files.
class LocaleConfig {
  LocaleConfig._();

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('fr'),
    Locale('it'),
    Locale('uz'),
    Locale('ru'),
  ];

  static const supportedLanguageCodes = ['en', 'ar', 'fr', 'it', 'uz', 'ru'];

  /// Short language code for app state / Accept-Language mapping input.
  static String apiLocaleCode(Locale locale) => locale.languageCode;

  /// OBDX `?locale=` value — digx-ui / Postman use region tags (e.g. `en-US`),
  /// not bare `en`.
  static String obdxLocaleQueryParam(String languageCode) {
    return switch (languageCode) {
      'en' => 'en-US',
      'ar' => 'ar',
      'fr' => 'fr-FR',
      'it' => 'it-IT',
      'uz' => 'uz-UZ',
      'ru' => 'ru-RU',
      _ => languageCode,
    };
  }

  /// HTTP `Accept-Language` for OBDX APIs.
  static String acceptLanguageHeader(String languageCode) {
    if (languageCode == 'en') {
      return 'en-US,en;q=0.9';
    }
    final query = obdxLocaleQueryParam(languageCode);
    return '$query,$languageCode;q=0.9,en;q=0.8';
  }

  static String displayName(AppLocalizations l10n, String languageCode) {
    return switch (languageCode) {
      'en' => l10n.english,
      'ar' => l10n.arabic,
      'fr' => l10n.french,
      'it' => l10n.italian,
      'uz' => l10n.uzbek,
      'ru' => l10n.russian,
      _ => languageCode,
    };
  }
}
