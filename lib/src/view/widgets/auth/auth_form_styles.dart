import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Shared input / label styling aligned with the login screen.
abstract final class AuthFormStyles {
  static const double fieldRadius = 8;
  static const double buttonRadius = 8;
  static const EdgeInsets fieldContentPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 13);

  static TextStyle fieldLabel(AppColors colors, {bool compact = false}) {
return TextStyle(
      fontFamily: 'Rubik',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
      height: 1.2,
    );
  }

  static TextStyle pageTitle(AppColors colors, {required bool wide}) {
    return TextStyle(
      fontFamily: 'Rubik',
      fontSize: wide ? 40 : 36,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
      height: 1.05,
    );
  }

  static TextStyle pageSubtitle(AppColors colors) {
    return TextStyle(
      fontFamily: 'Rubik',
      fontSize: 14,
      color: colors.textSecondary,
      height: 1.4,
    );
  }

  static InputDecoration inputDecoration({
    required AppColors colors,
    String? hintText,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
hintStyle: TextStyle(
        fontFamily: 'Rubik',
        color: colors.inputHint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: colors.inputBackground,
      contentPadding: fieldContentPadding,
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colors.brand),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colors.error),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(
          color: colors.inputBorder.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  static ButtonStyle primaryButton(AppColors colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: colors.brand.withValues(alpha: 0.6),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
      elevation: 0,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Rubik',
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
