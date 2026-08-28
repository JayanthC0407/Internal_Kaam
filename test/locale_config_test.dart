import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';

void main() {
  test('LocaleConfig lists six supported languages', () {
    expect(LocaleConfig.supportedLocales, hasLength(6));
    expect(LocaleConfig.supportedLanguageCodes,
        containsAll(['en', 'ar', 'fr', 'it', 'uz', 'ru']));
  });

  test('LocaleConfig displayName returns localized labels', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(LocaleConfig.displayName(l10n, 'ar'), 'Arabic');
    expect(LocaleConfig.displayName(l10n, 'fr'), 'French');
  });

  test('obdxLocaleQueryParam maps en to en-US for OBDX', () {
    expect(LocaleConfig.obdxLocaleQueryParam('en'), 'en-US');
    expect(LocaleConfig.obdxLocaleQueryParam('fr'), 'fr-FR');
  });
}
