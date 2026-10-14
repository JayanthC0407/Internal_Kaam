import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';

import 'app_colors.dart';

/// Brand colour themes from the design system. Each one ships a light and a
/// dark variant; light/dark is still chosen separately through [ThemeMode].
///
/// Order is the order the pickers show them in. [name] is what gets
/// persisted, so do not rename values without a migration.
enum AppThemePalette {
  /// Cyan on neutral greys — the original Demobank theme.
  cyan,

  /// Burnt orange on slate (design file "Dark-1").
  orange,

  /// Indigo on deep indigo (design file "Dark-2").
  indigo;

  static const AppThemePalette fallback = AppThemePalette.cyan;

  /// Parses a stored [name]; unknown or empty values fall back to cyan so an
  /// old install or a removed palette never breaks start-up.
  static AppThemePalette parse(String? raw) {
    for (final palette in values) {
      if (palette.name == raw) return palette;
    }
    return fallback;
  }

  /// Full colour set for this palette at [brightness].
  AppColors colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case AppThemePalette.cyan:
        return dark ? AppColors.dark : AppColors.light;
      case AppThemePalette.orange:
        return dark ? AppColors.darkOrange : AppColors.lightOrange;
      case AppThemePalette.indigo:
        return dark ? AppColors.darkIndigo : AppColors.lightIndigo;
    }
  }

  /// Localized name shown in the theme pickers.
  String label(AppLocalizations l10n) {
    switch (this) {
      case AppThemePalette.cyan:
        return l10n.paletteCyan;
      case AppThemePalette.orange:
        return l10n.paletteOrange;
      case AppThemePalette.indigo:
        return l10n.paletteIndigo;
    }
  }

  /// Representative colour for swatches in the theme pickers.
  Color get swatch {
    switch (this) {
      case AppThemePalette.cyan:
        return AppColors.cyan700;
      case AppThemePalette.orange:
        return AppColors.orange700;
      case AppThemePalette.indigo:
        return AppColors.indigo700;
    }
  }
}
