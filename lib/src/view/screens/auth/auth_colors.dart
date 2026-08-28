import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Shared palette for authentication flows (login, OTP, biometric).
abstract final class AuthColors {
  static AppColors of(BuildContext context) => AppColors.of(context);

  static Color screenBackground(BuildContext context) => of(context).scaffoldBg;

  static Color backgroundSecondary(BuildContext context) =>
      of(context).backgroundSecondary;

  static Color textPrimary(BuildContext context) => of(context).textPrimary;

  static Color textSecondary(BuildContext context) => of(context).textSecondary;

  static Color inputBorder(BuildContext context) => of(context).inputBorder;

  static Color inputBackground(BuildContext context) =>
      of(context).inputBackground;

  static Color inputHint(BuildContext context) => of(context).inputHint;

  static Color brand(BuildContext context) => of(context).brand;

  static Color brandDark(BuildContext context) => of(context).brandDark;

  static Color secondaryButtonBackground(BuildContext context) =>
      of(context).secondaryButtonBg;

  static Color surfaceLevel0(BuildContext context) => of(context).surface;

  static Color surfaceLevel1(BuildContext context) => of(context).surfaceSecondary;

  static Color success(BuildContext context) => of(context).success;

  static Color warning(BuildContext context) => of(context).warning;

  static Color error(BuildContext context) => of(context).error;

  static Color info(BuildContext context) => of(context).info;

  static Color otpBoxFilled(BuildContext context) => of(context).otpBoxFilled;
}
