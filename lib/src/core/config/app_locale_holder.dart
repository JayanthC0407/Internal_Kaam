import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';

/// Runtime locale for Dio (outside the widget tree).
///
/// Updated when the user changes language in app settings.
class AppLocaleHolder {
  AppLocaleHolder._();

  static final AppLocaleHolder instance = AppLocaleHolder._();

  String _languageCode = 'en';

  String get languageCode => _languageCode;

  void update(Locale locale) {
    final code = LocaleConfig.apiLocaleCode(locale);
    _languageCode =
        LocaleConfig.supportedLanguageCodes.contains(code) ? code : 'en';
  }
}
