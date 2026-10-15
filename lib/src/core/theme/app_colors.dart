import 'package:flutter/material.dart';

/// Semantic design-system colors for light and dark themes.
///
/// The raw palette is kept here so widgets do not need to know individual
/// hex values. Prefer semantic fields (brand, success, surface, etc.) in UI.
///
/// There is one [AppColors] per brand palette and brightness — cyan
/// ([light] / [dark]), orange ([lightOrange] / [darkOrange]) and indigo
/// ([lightIndigo] / [darkIndigo]). Use `AppThemePalette.colors` to pick one.
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
    required this.brandTint,
    required this.brandSubtle,
    required this.brandMuted,
    required this.brandGradient,
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

  /// Bright accent of the active palette. Named after the original cyan
  /// theme; on the orange/indigo palettes it holds their 400 shade.
  final Color accentCyan;

  /// Soft accent of the active palette (see [accentCyan]).
  final Color accentCyanSoft;

  /// Palette-aware alias of [accentCyan].
  Color get accent => accentCyan;

  /// Palette-aware alias of [accentCyanSoft].
  Color get accentSoft => accentCyanSoft;

  /// Palest brand tint (the 50 shade) — fill behind brand-coloured icons
  /// and badges.
  final Color brandTint;

  /// Light brand tint (the 100 shade) — inactive carousel dots and similar.
  final Color brandSubtle;

  /// Mid brand tint (the 300 shade) — non-highlighted chart bars.
  final Color brandMuted;

  /// Hero gradient for balance cards, login header and similar surfaces.
  final LinearGradient brandGradient;

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

  // Orange palette (design system "Dark-1").
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange300 = Color(0xFFFDBA74);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);
  static const orange800 = Color(0xFF9A3412);
  static const orange900 = Color(0xFF7C2D12);
  static const orange950 = Color(0xFF431407);

  // Indigo palette (design system "Dark-2").
  static const indigo50 = Color(0xFFEEF2FF);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo200 = Color(0xFFC7D2FE);
  static const indigo300 = Color(0xFFA5B4FC);
  static const indigo400 = Color(0xFF818CF8);
  static const indigo500 = Color(0xFF6366F1);
  static const indigo600 = Color(0xFF4F46E5);
  static const indigo700 = Color(0xFF4338CA);
  static const indigo800 = Color(0xFF3730A3);
  static const indigo900 = Color(0xFF312E81);
  static const indigo950 = Color(0xFF1E1B4B);

  /// indigo500 nudged darker so white button labels reach 4.5:1 while the
  /// colour still reads at 3:1 on the dark indigo cards.
  static const indigoOnDark = Color(0xFF5B5BEA);

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

  // Slate palette — the neutrals of the orange theme.
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  // Indigo-tinted neutrals — the neutrals of the indigo theme, sampled
  // from the design file and filled in between.
  static const ink50 = Color(0xFFF8F8FC);
  static const ink100 = Color(0xFFF4F4FA);
  static const ink200 = Color(0xFFE4E4EF);
  static const ink300 = Color(0xFFC7C8E3);
  static const ink400 = Color(0xFF9A9BC4);
  static const ink500 = Color(0xFF6E7092);
  static const ink600 = Color(0xFF4B4C6E);
  static const ink700 = Color(0xFF3E3C66);
  static const ink800 = Color(0xFF2E2C4B);
  static const ink900 = Color(0xFF17162E);
  static const ink950 = Color(0xFF131329);

  // Semantic colors from the designer specification.
  static const primary = cyan700;
  static const successColor = Color(0xFF16A34A);
  static const warningColor = Color(0xFFF59E0B);
  static const errorColor = Color(0xFFDC2626);
  static const infoColor = Color(0xFF0284C7);

  /// Kept as an alias so existing code can migrate safely.
  static const brandSeed = primary;

  // Hero gradients. Cyan keeps its original stops; orange and indigo follow
  // their design files (bright top-left fading to the 950 shade).
  static const cyanLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan700, cyan600, cyan500, cyan400],
  );

  static const cyanDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan950, cyan900, cyan800, cyan700],
  );

  static const orangeLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange700, orange600, orange500, orange400],
  );

  static const orangeDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange700, orange800, orange900, orange950],
  );

  static const indigoLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo700, indigo600, indigo500, indigo400],
  );

  static const indigoDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo700, indigo800, indigo900, indigo950],
  );

  // ---------------------------------------------------------------------
  // Cyan (original theme — values unchanged).
  // ---------------------------------------------------------------------

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
    brandTint: teal50,
    brandSubtle: teal100,
    brandMuted: cyan300,
    brandGradient: cyanLightGradient,
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
    brandTint: teal50,
    brandSubtle: teal100,
    brandMuted: cyan300,
    brandGradient: cyanDarkGradient,
  );

  // ---------------------------------------------------------------------
  // Orange on slate.
  // Dark: slate-900 chrome/cards as in the design file, orange-700 brand
  // (5.2:1 under white labels, 3.4:1 on the cards).
  // Light: same orange-700 brand on white with slate neutrals.
  // ---------------------------------------------------------------------

  static const lightOrange = AppColors(
    scaffoldBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: slate100,
    backgroundSecondary: slate50,
    textPrimary: slate900,
    textSecondary: slate600,
    brand: orange700,
    brandDark: orange800,
    brandLight: orange500,
    inputBorder: slate200,
    inputBackground: slate100,
    inputHint: slate500,
    secondaryButtonBg: slate100,
    divider: slate200,
    navInactive: slate500,
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: orange50,
    accentCyan: orange400,
    accentCyanSoft: orange100,
    brandTint: orange50,
    brandSubtle: orange100,
    brandMuted: orange300,
    brandGradient: orangeLightGradient,
  );

  static const darkOrange = AppColors(
    scaffoldBg: slate950,
    cardBg: slate900,
    surface: slate900,
    surfaceSecondary: slate800,
    backgroundSecondary: slate900,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: slate300,
    brand: orange700,
    brandDark: orange950,
    brandLight: orange600,
    inputBorder: slate700,
    inputBackground: slate800,
    inputHint: slate400,
    secondaryButtonBg: slate800,
    divider: slate700,
    navInactive: slate400,
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: orange950,
    accentCyan: orange400,
    accentCyanSoft: orange900,
    brandTint: orange50,
    brandSubtle: orange100,
    brandMuted: orange300,
    brandGradient: orangeDarkGradient,
  );

  // ---------------------------------------------------------------------
  // Indigo on deep indigo.
  // Dark: indigo-950 chrome/cards as in the design file. indigo-700 is
  // too dark to read there (2.0:1), so the dark brand is [indigoOnDark].
  // Light: indigo-700 brand on white with indigo-tinted neutrals.
  // ---------------------------------------------------------------------

  static const lightIndigo = AppColors(
    scaffoldBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: ink100,
    backgroundSecondary: ink50,
    textPrimary: ink900,
    textSecondary: ink600,
    brand: indigo700,
    brandDark: indigo800,
    brandLight: indigo500,
    inputBorder: ink200,
    inputBackground: ink100,
    inputHint: ink500,
    secondaryButtonBg: ink100,
    divider: ink200,
    navInactive: ink500,
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: indigo50,
    accentCyan: indigo400,
    accentCyanSoft: indigo100,
    brandTint: indigo50,
    brandSubtle: indigo100,
    brandMuted: indigo300,
    brandGradient: indigoLightGradient,
  );

  static const darkIndigo = AppColors(
    scaffoldBg: ink950,
    cardBg: indigo950,
    surface: indigo950,
    surfaceSecondary: ink800,
    backgroundSecondary: indigo950,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: ink300,
    brand: indigoOnDark,
    brandDark: indigo950,
    brandLight: indigo500,
    inputBorder: ink700,
    inputBackground: ink800,
    inputHint: ink400,
    secondaryButtonBg: ink800,
    divider: ink700,
    navInactive: ink400,
    success: successColor,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
    otpBoxFilled: indigo950,
    accentCyan: indigo400,
    accentCyanSoft: indigo900,
    brandTint: indigo50,
    brandSubtle: indigo100,
    brandMuted: indigo300,
    brandGradient: indigoDarkGradient,
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
    Color? brandTint,
    Color? brandSubtle,
    Color? brandMuted,
    LinearGradient? brandGradient,
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
      brandTint: brandTint ?? this.brandTint,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      brandMuted: brandMuted ?? this.brandMuted,
      brandGradient: brandGradient ?? this.brandGradient,
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
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      brandGradient:
          LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
    );
  }
}
