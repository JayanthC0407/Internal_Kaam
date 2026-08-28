import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/view/providers/session_providers.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('en'),
    this.hydrated = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool hydrated;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? hydrated,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      hydrated: hydrated ?? this.hydrated,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._preferences) : super(const AppSettings()) {
    _hydrate();
  }

  final PreferenceHelper _preferences;

  Future<void> _hydrate() async {
    final storedTheme = await _preferences.getThemeMode();
    final storedLocale = await _preferences.getAppLocale();
    final themeMode = _parseThemeMode(storedTheme);
    final locale = Locale(
      storedLocale.isEmpty ? 'en' : storedLocale,
    );
    AppLocaleHolder.instance.update(locale);
    state = AppSettings(
      themeMode: themeMode,
      locale: locale,
      hydrated: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _preferences.setThemeMode(mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    AppLocaleHolder.instance.update(locale);
    state = state.copyWith(locale: locale);
    await _preferences.setAppLocale(locale.languageCode);
  }

  static ThemeMode _parseThemeMode(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(ref.watch(preferenceHelperProvider)),
);
