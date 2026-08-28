import 'package:flutter/material.dart';

/// Semantic design-system colors for light and dark themes.
///
/// The raw palette is kept here so widgets do not need to know individual
/// hex values. Prefer semantic fields (brand, success, surface, etc.) in UI.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.surface,
    required this.surfaceSecondary,
    required this.backgroundSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.brandDark,
    required this.brandLight,
    required this.inputBorder,
    required this.inputBackground,
    required this.inputHint,
    required this.secondaryButtonBg,
    required this.divider,
    required this.navInactive,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.otpBoxFilled,
    required this.accentCyan,
    required this.accentCyanSoft,
  });

  // Existing semantic fields retained for compatibility.
  final Color scaffoldBg;
  final Color cardBg;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color brandDark;
  final Color inputBorder;
  final Color inputBackground;
  final Color inputHint;
  final Color secondaryButtonBg;
  final Color divider;
  final Color navInactive;
  final Color error;
  final Color otpBoxFilled;

  // New design-system semantic fields.
  final Color backgroundSecondary;
  final Color surfaceSecondary;
  final Color brandLight;
  final Color success;
  final Color warning;
  final Color info;
  final Color accentCyan;
  final Color accentCyanSoft;

  // Cyan palette.
  static const cyan50 = Color(0xFFECFEFF);
  static const cyan100 = Color(0xFFCFFAFE);
  static const cyan200 = Color(0xFFA5F3FC);
  static const cyan300 = Color(0xFF67E8F9);
  static const cyan400 = Color(0xFF22D3EE);
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan600 = Color(0xFF0891B2);
  static const cyan700 = Color(0xFF0E7490);
  static const cyan800 = Color(0xFF155E75);
  static const cyan900 = Color(0xFF164E63);
  static const cyan950 = Color(0xFF083344);

  // Teal palette.
  static const teal50 = Color(0xFFF0FDFA);
  static const teal100 = Color(0xFFCCFBF1);
  static const teal200 = Color(0xFF99F6E4);
  static const teal300 = Color(0xFF5EEAD4);
  static const teal400 = Color(0xFF2DD4BF);
  static const teal500 = Color(0xFF14B8A6);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);
  static const teal800 = Color(0xFF115E59);
  static const teal900 = Color(0xFF134E4A);
  static const teal950 = Color(0xFF042F2E);

  // Neutral palette.
  static const neutral50 = Color(0xFFFAFAFA);
  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral300 = Color(0xFFD4D4D4);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252);
  static const neutral700 = Color(0xFF404040);
  static const neutral800 = Color(0xFF262626);
  static const neutral900 = Color(0xFF171717);
  static const neutral950 = Color(0xFF0A0A0A);

  // Semantic colors from the designer specification.
  static const primary = cyan700;
  static const successColor = Color(0xFF16A34A);
  static const warningColor = Color(0xFFF59E0B);
  static const errorColor = Color(0xFFDC2626);
  static const infoColor = Color(0xFF0284C7);

  /// Kept as an alias so existing code can migrate safely.
  static const brandSeed = primary;

  static const light = AppColors(
    scaffoldBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF5F5F5),
    backgroundSecondary: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF525252),
    brand: primary,
    brandDark: cyan800,
    brandLight: cyan500,
    inputBorder: Color(0xFFE5E5E5),
    inputBackground: Color(0xFFF5F5F5),
    inputHint: Color(0xFF737373),
    secondaryButtonBg: Color(0xFFF5F5F5),
    divider: Color(0xFFE5E5E5),
    navInactive: Color(0xFF737373),
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: cyan50,
    accentCyan: cyan400,
    accentCyanSoft: cyan100,
  );

  static const dark = AppColors(
    scaffoldBg: Color(0xFF0A0A0A),
    cardBg: Color(0xFF171717),
    surface: Color(0xFF171717),
    surfaceSecondary: Color(0xFF262626),
    backgroundSecondary: Color(0xFF171717),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD4D4D4),
    brand: primary,
    brandDark: cyan950,
    brandLight: cyan600,
    inputBorder: Color(0xFF404040),
    inputBackground: Color(0xFF262626),
    inputHint: Color(0xFFA3A3A3),
    secondaryButtonBg: Color(0xFF262626),
    divider: Color(0xFF404040),
    navInactive: Color(0xFFA3A3A3),
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: cyan950,
    accentCyan: cyan400,
    accentCyanSoft: cyan900,
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  AppColors copyWith({
    Color? scaffoldBg,
    Color? cardBg,
    Color? surface,
    Color? surfaceSecondary,
    Color? backgroundSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? brandDark,
    Color? brandLight,
    Color? inputBorder,
    Color? inputBackground,
    Color? inputHint,
    Color? secondaryButtonBg,
    Color? divider,
    Color? navInactive,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? otpBoxFilled,
    Color? accentCyan,
    Color? accentCyanSoft,
  }) {
    return AppColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      brandLight: brandLight ?? this.brandLight,
      inputBorder: inputBorder ?? this.inputBorder,
      inputBackground: inputBackground ?? this.inputBackground,
      inputHint: inputHint ?? this.inputHint,
      secondaryButtonBg: secondaryButtonBg ?? this.secondaryButtonBg,
      divider: divider ?? this.divider,
      navInactive: navInactive ?? this.navInactive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      otpBoxFilled: otpBoxFilled ?? this.otpBoxFilled,
      accentCyan: accentCyan ?? this.accentCyan,
      accentCyanSoft: accentCyanSoft ?? this.accentCyanSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      backgroundSecondary:
          Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputHint: Color.lerp(inputHint, other.inputHint, t)!,
      secondaryButtonBg:
          Color.lerp(secondaryButtonBg, other.secondaryButtonBg, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      otpBoxFilled: Color.lerp(otpBoxFilled, other.otpBoxFilled, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentCyanSoft: Color.lerp(accentCyanSoft, other.accentCyanSoft, t)!,
    );
  }
}
