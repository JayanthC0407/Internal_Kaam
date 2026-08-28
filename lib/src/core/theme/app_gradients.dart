import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Brand gradients from the designer's light and dark specifications.
abstract final class AppGradients {
  static const lightPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.cyan700,
      AppColors.cyan600,
      AppColors.cyan500,
      AppColors.cyan400,
    ],
  );

  static const darkPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.cyan950,
      AppColors.cyan900,
      AppColors.cyan800,
      AppColors.cyan700,
    ],
  );

  static LinearGradient primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary
        : lightPrimary;
  }
}
