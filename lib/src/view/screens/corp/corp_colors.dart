import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Corporate dashboard palette — resolves from the active [ThemeData] so
/// the corporate surfaces follow the same light/dark theme extension as the
/// rest of the app. Mirrors Retail's `HomeColors`, and adds the few tokens
/// the corporate design needs that Retail has no equivalent for (the
/// cyan-tinted card outline, the selected nav-row fill, and the
/// positive/negative balance colours used by the Account Summary grid).
class CorpColors {
  const CorpColors._();

  static AppColors of(BuildContext context) => AppColors.of(context);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) => of(context).scaffoldBg;

  static Color card(BuildContext context) => of(context).cardBg;

  static Color surface(BuildContext context) => of(context).surface;

  static Color textPrimary(BuildContext context) => of(context).textPrimary;

  static Color textSecondary(BuildContext context) => of(context).textSecondary;

  static Color brand(BuildContext context) => of(context).brand;

  static Color brandLight(BuildContext context) => of(context).brandLight;

  static Color divider(BuildContext context) => of(context).divider;

  static Color navInactive(BuildContext context) => of(context).navInactive;

  /// Cyan-tinted 1px outline the design puts around every dashboard card.
  static Color cardBorder(BuildContext context) => _isDark(context)
      ? of(context).divider
      : of(context).brand.withValues(alpha: 0.22);

  /// Soft glow under the cards / sidebar / header.
  static Color cardShadow(BuildContext context) =>
      of(context).brandLight.withValues(alpha: _isDark(context) ? 0.14 : 0.22);

  /// Fill behind the selected sidebar row.
  static Color navSelectedBg(BuildContext context) =>
      of(context).brand.withValues(alpha: _isDark(context) ? 0.20 : 0.10);

  /// Neutral tile fill for the Quick Links squares.
  static Color tile(BuildContext context) =>
      _isDark(context) ? of(context).surfaceSecondary : of(context).cardBg;

  /// Positive balance in the Account Summary grid.
  static Color positiveBalance(BuildContext context) => of(context).success;

  /// Negative / overdrawn balance in the Account Summary grid.
  static Color negativeBalance(BuildContext context) => of(context).error;

  /// Row fill for the grid's header band.
  static Color tableHeaderBg(BuildContext context) =>
      _isDark(context) ? of(context).surfaceSecondary : Colors.transparent;

  /// Hover fill for an interactive grid row.
  static Color tableRowHover(BuildContext context) =>
      of(context).brand.withValues(alpha: _isDark(context) ? 0.12 : 0.05);
}
