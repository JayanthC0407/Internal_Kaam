import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Home / dashboard palette — resolves from the active [ThemeData].
class HomeColors {
  const HomeColors._();

  static AppColors of(BuildContext context) => AppColors.of(context);

  static Color bg(BuildContext context) => of(context).scaffoldBg;

  static Color backgroundSecondary(BuildContext context) =>
      of(context).backgroundSecondary;

  static Color textPrimary(BuildContext context) => of(context).textPrimary;

  static Color textSecondary(BuildContext context) => of(context).textSecondary;

  static Color brand(BuildContext context) => of(context).brand;

  static Color brandDark(BuildContext context) => of(context).brandDark;

  static Color card(BuildContext context) => of(context).cardBg;

  static Color surface(BuildContext context) => of(context).surface;

  static Color surfaceSecondary(BuildContext context) =>
      of(context).surfaceSecondary;

  static Color divider(BuildContext context) => of(context).divider;

  static Color navInactive(BuildContext context) => of(context).navInactive;

  static Color success(BuildContext context) => of(context).success;

  static Color warning(BuildContext context) => of(context).warning;

  static Color error(BuildContext context) => of(context).error;

  static Color info(BuildContext context) => of(context).info;
}