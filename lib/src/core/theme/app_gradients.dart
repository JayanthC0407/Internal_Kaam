import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Brand gradients from the designer's light and dark specifications.
abstract final class AppGradients {
  /// Cyan light gradient. Kept for existing references; prefer [primary],
  /// which follows the active palette.
  static const lightPrimary = AppColors.cyanLightGradient;

  /// Cyan dark gradient. Kept for existing references; prefer [primary].
  static const darkPrimary = AppColors.cyanDarkGradient;

  /// Hero gradient for the active palette and brightness.
  static LinearGradient primary(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    if (colors != null) return colors.brandGradient;
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary
        : lightPrimary;
  }
}
