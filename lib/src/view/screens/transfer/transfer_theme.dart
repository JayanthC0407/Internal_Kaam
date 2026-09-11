import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Figma transfer flow design tokens (Option 1 + Option 2).
enum TransferDesignVariant { option1, option2 }

/// Default mobile transfer layout — Figma Option 2 (card-based).
const TransferDesignVariant kTransferDesignVariant =
    TransferDesignVariant.option2;

class TransferTheme {
  const TransferTheme._();

  static const double progressHeight = 3;
  static const double progressGap = 4;
  static const double screenPadding = 16;
  static const double sectionGap = 16;
  static const double cardRadius = 12;
  static const double fieldRadius = 8;
  static const double buttonHeight = 48;
  static const double buttonRadius = 8;
  static const double inputHeight = 44;
  static const double typeTileGap = 12;
  static const double cardPadding = 13;

  static double horizontalPadding(BuildContext context) {
    return Responsive.of(context).fontScale(phone: 16, tablet: 24, desktop: 32);
  }

  static double contentMaxWidth(BuildContext context) {
    final r = Responsive.of(context);
    if (r.isDesktop) return 1100;
    if (r.useWideLayout) return 960;
    return double.infinity;
  }

  /// Transfer pane on web/desktop — fills the Home content column.
  static double webPaneMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) return 1100;
    if (width >= 1100) return 960;
    return 840;
  }

  static bool useWebTwoColumn(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  static const Color reviewBannerBg = Color(0xFFFFF6E8);
  static const Color reviewBannerBar = Color(0xFFE0A106);
  static const Color exchangeCardBg = Color(0xFFE3EBEE);
  static const Color exchangeFooterBg = Color(0x1A00796B);
  static const Color exchangeAccent = Color(0xFF005E53);
  static const Color accountIconBg = Color(0x3300796B);
  static const Color cardBorderMuted = Color(0xFFBDC9C5);
  static const Color balanceHint = Color(0xFF7D89B0);
  static const Color rowDivider = Color(0xFFE1E3E4);
  static const Color mutedCardBg = Color(0xFFF9F9FB);
  static const Color webFxBg = Color(0x26005C51);
  static const double webFormMaxWidth = 1100;
  static const Color webRadioSelected = Color(0xFF2563EB);
  static const Color webCancelBg = Color(0xFF404968);
  static const Color webLink = Color(0xFF2563EB);

  static Color successBannerBg(BuildContext context) =>
      HomeColors.brand(context).withValues(alpha: 0.10);

  static Color successBannerBar(BuildContext context) =>
      HomeColors.brand(context);

  static Color accentLink(BuildContext context) => HomeColors.brand(context);

  static Color progressInactive(BuildContext context) => Colors.white;

  /// Figma Mobile transfer type: Regular / Medium / Semibold.
  /// Bold (w700) is only the 14px app-bar title and the 24px amount.
  static TextStyle _text(BuildContext context) => TextStyle(
        color: HomeColors.textPrimary(context),
        decoration: TextDecoration.none,
      );

  static TextStyle pageTitle(BuildContext context) {
    final size =
        Responsive.of(context).fontScale(phone: 20, tablet: 24, desktop: 24);
    return _text(context).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: HomeColors.textPrimary(context),
    );
  }

  static TextStyle appBarTitle(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle stepTitle(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle fieldLabel(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: HomeColors.textSecondary(context),
      );

  static TextStyle caption(BuildContext context) => _text(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        color: HomeColors.textSecondary(context),
      );

  static TextStyle accountName(BuildContext context) => _text(context).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle accountMask(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: HomeColors.textSecondary(context),
      );

  static TextStyle webPageTitle(BuildContext context) => pageTitle(context);

  static TextStyle webLabel(BuildContext context) => caption(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      );

  static TextStyle webValue(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle fieldValue(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 22 / 14,
        color: AppColors.of(context).inputHint,
      );

  static TextStyle fieldFilled(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle bodySecondary(BuildContext context) =>
      _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: HomeColors.textSecondary(context),
      );

  static TextStyle sectionHeading(BuildContext context) => stepTitle(context);

  static TextStyle reviewValue(BuildContext context) => _text(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: HomeColors.textPrimary(context),
      );

  static TextStyle amountLarge(BuildContext context) {
    final size = Responsive.of(context).fontScale(phone: 24, tablet: 28);
    return _text(context).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1,
      color: HomeColors.textPrimary(context),
    );
  }

  static TextStyle buttonLabel(BuildContext context) => _text(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
      );

  static const Size webButtonMinSize = Size(96, 40);

  static ButtonStyle primaryButton(
    BuildContext context, {
    bool compact = false,
  }) {
    final brand = HomeColors.brand(context);
    return FilledButton.styleFrom(
      minimumSize: compact ? webButtonMinSize : const Size(0, buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 20,
        vertical: compact ? 10 : 12,
      ),
      backgroundColor: brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: brand.withValues(alpha: 0.55),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      textStyle: buttonLabel(context).copyWith(
        fontSize: compact ? 14 : 16,
        fontWeight: compact ? FontWeight.w700 : FontWeight.w500,
        color: Colors.white,
      ),
    );
  }

  static ButtonStyle secondaryButton(
    BuildContext context, {
    bool compact = false,
  }) {
    final colors = AppColors.of(context);
    return FilledButton.styleFrom(
      minimumSize: compact ? webButtonMinSize : const Size(88, buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 20,
        vertical: compact ? 10 : 12,
      ),
      backgroundColor: colors.secondaryButtonBg,
      foregroundColor: colors.textPrimary,
      disabledBackgroundColor: colors.secondaryButtonBg.withValues(alpha: 0.7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      textStyle: buttonLabel(context).copyWith(fontSize: compact ? 14 : 15),
    );
  }

  static ButtonStyle textAction(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: HomeColors.brand(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      textStyle: buttonLabel(context).copyWith(fontSize: 14),
    );
  }

  static BoxDecoration panel(BuildContext context) {
    return BoxDecoration(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: HomeColors.divider(context)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  static TextStyle balanceCaption(BuildContext context) =>
      _text(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: balanceHint,
      );

  static InputDecoration inputDecoration(
    BuildContext context, {
    String? hint,
    String? prefixText,
  }) {
    final colors = AppColors.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: colors.inputBorder),
    );
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      hintStyle: fieldValue(context),
      filled: true,
      fillColor: colors.inputBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.brand),
      ),
    );
  }

  static InputDecoration underlineDecoration(
    BuildContext context, {
    String? hint,
    String? prefixText,
    String? helperText,
  }) {
    final colors = AppColors.of(context);
    final enabled = UnderlineInputBorder(
      borderSide: BorderSide(color: colors.inputBorder),
    );
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      helperText: helperText,
      helperStyle: _text(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: HomeColors.textSecondary(context),
      ),
      hintStyle: fieldValue(context),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      border: enabled,
      enabledBorder: enabled,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.brand, width: 1.5),
      ),
    );
  }

  static InputDecorationTheme underlineInputTheme(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = UnderlineInputBorder(
      borderSide: BorderSide(color: colors.inputBorder),
    );
    return InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      border: enabled,
      enabledBorder: enabled,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.brand, width: 1.5),
      ),
    );
  }

  static BoxDecoration formCard(BuildContext context, {bool white = false}) {
    final colors = AppColors.of(context);
    return BoxDecoration(
      color: white ? HomeColors.card(context) : colors.inputBackground,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.85)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration elevatedCard(BuildContext context) => BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: const Color(0xFFB9C0D4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      );

  static String maskLastFour(String displayNumber) {
    final digits = displayNumber.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 4) return digits;
    return '••••${digits.substring(digits.length - 4)}';
  }

  /// Web form mask matching Figma (`xxxxxxxxxxxxx0680`).
  static String webMask(String displayNumber) {
    final digits = displayNumber.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 4) return digits;
    return '${'x' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }

  /// Collapses accidental duplicated titles from OBDX nickname/product fields.
  static String compactTitle(String title) {
    final t = title.trim();
    if (t.length < 16) return t;
    final mid = t.length ~/ 2;
    if (t.substring(0, mid) == t.substring(mid)) {
      return t.substring(0, mid).trim();
    }
    return t;
  }
}
