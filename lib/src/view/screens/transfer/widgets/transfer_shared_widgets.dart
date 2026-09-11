import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/transfer/transfer_theme.dart';

/// Three-segment wizard progress bar — Figma: 3px segments, 4px gap.
class TransferProgressBar extends StatelessWidget {
  const TransferProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final inactive = TransferTheme.progressInactive(context);
    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < totalSteps - 1 ? TransferTheme.progressGap : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: TransferTheme.progressHeight,
              decoration: BoxDecoration(
                color: active ? brand : inactive,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Figma app bar: gray 24×24 back chip + 14px bold title.
class TransferMobileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TransferMobileAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.bottom,
  });

  final String title;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        44 + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppBar(
      backgroundColor: HomeColors.bg(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 44,
      leadingWidth: 52,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: colors.secondaryButtonBg,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(6),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(Icons.chevron_left_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
      title: Text(title, style: TransferTheme.appBarTitle(context)),
      centerTitle: false,
      titleSpacing: 0,
      bottom: bottom,
    );
  }
}

/// Figma footer: Back (intrinsic) + primary (expanded), h=48, r=8.
class TransferBottomActions extends StatelessWidget {
  const TransferBottomActions({
    super.key,
    required this.onBack,
    required this.onPrimary,
    required this.primaryLabel,
    this.backLabel,
    this.primaryLoading = false,
    this.primaryEnabled = true,
    this.showPrimary = true,
    this.useSafeArea = true,
  });

  final VoidCallback? onBack;
  final VoidCallback? onPrimary;
  final String primaryLabel;
  final String? backLabel;
  final bool primaryLoading;
  final bool primaryEnabled;
  final bool showPrimary;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final backText = backLabel ?? 'Back';
    final pad = TransferTheme.horizontalPadding(context);
    final maxWidth = TransferTheme.contentMaxWidth(context);
    final buttons = Padding(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, useSafeArea ? 8 : 12),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              if (showPrimary)
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, TransferTheme.buttonHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    foregroundColor: brand,
                    side: BorderSide(color: brand),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(TransferTheme.buttonRadius),
                    ),
                    textStyle: TransferTheme.buttonLabel(context),
                  ),
                  child: Text(backText),
                )
              else
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, TransferTheme.buttonHeight),
                      foregroundColor: brand,
                      side: BorderSide(color: brand),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(TransferTheme.buttonRadius),
                      ),
                      textStyle: TransferTheme.buttonLabel(context),
                    ),
                    child: Text(backText),
                  ),
                ),
              if (showPrimary) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        primaryEnabled && !primaryLoading ? onPrimary : null,
                    style: TransferTheme.primaryButton(context),
                    child: primaryLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(primaryLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!useSafeArea) return buttons;
    return SafeArea(top: false, child: buttons);
  }
}

class TransferStepTitle extends StatelessWidget {
  const TransferStepTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: TransferTheme.stepTitle(context));
  }
}

/// Section label inside a step (e.g. Transfer From, Transfer When).
class TransferSectionTitle extends StatelessWidget {
  const TransferSectionTitle(
    this.title, {
    super.key,
    this.heading = false,
    this.compact = false,
  });

  final String title;
  final bool heading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TransferTheme.stepTitle(context),
      ),
    );
  }
}

/// Option 2 — vertical icon tile (New Payer / My Accounts).
class TransferTypeTile extends StatelessWidget {
  const TransferTypeTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final border = selected ? brand : const Color(0xFFB9C0D4);
    return Expanded(
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
              border: Border.all(
                color: border,
                width: selected ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(selected ? 14 : 13),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? brand : HomeColors.textSecondary(context),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TransferTheme.fieldLabel(context).copyWith(
                    color: selected ? brand : HomeColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Option 1 — horizontal radio row (Existing Payer / My Accounts).
class TransferRadioOption extends StatelessWidget {
  const TransferRadioOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final border = selected ? brand : HomeColors.divider(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? brand : HomeColors.divider(context),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.all(3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                    color: selected ? brand : HomeColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option 2 — Now / Later large toggle buttons.
class TransferWhenToggle extends StatelessWidget {
  const TransferWhenToggle({
    super.key,
    required this.nowLabel,
    required this.laterLabel,
    required this.transferNow,
    required this.onNow,
    required this.onLater,
  });

  final String nowLabel;
  final String laterLabel;
  final bool transferNow;
  final VoidCallback onNow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    Widget buildBtn(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
                border: Border.all(
                  color: selected ? brand : TransferTheme.cardBorderMuted,
                  width: selected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  style: TransferTheme.stepTitle(context).copyWith(
                    color: selected ? brand : HomeColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildBtn(nowLabel, transferNow, onNow),
        const SizedBox(width: 16),
        buildBtn(laterLabel, !transferNow, onLater),
      ],
    );
  }
}

/// Tappable dropdown-style field (44px) — Figma account picker row.
class TransferPickerField extends StatelessWidget {
  const TransferPickerField({
    super.key,
    this.label,
    this.value,
    this.hint,
    this.helper,
    this.onTap,
    this.labelStyle,
    this.underline = false,
  });

  final String? label;
  final String? value;
  final String? hint;
  final String? helper;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filled = value?.isNotEmpty == true;
    final row = Row(
      children: [
        Expanded(
          child: Text(
            filled ? value! : (hint ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: filled
                ? TransferTheme.fieldFilled(context)
                : TransferTheme.fieldValue(context),
          ),
        ),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 24,
          color: HomeColors.textSecondary(context),
        ),
      ],
    );

    final field = underline
        ? InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.inputBorder),
                ),
              ),
              child: row,
            ),
          )
        : Material(
            color: colors.inputBackground,
            borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
              child: Ink(
                height: TransferTheme.inputHeight,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(TransferTheme.fieldRadius),
                  border: Border.all(color: colors.inputBorder),
                ),
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                child: row,
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: labelStyle ?? TransferTheme.fieldLabel(context),
          ),
          SizedBox(height: underline ? 4 : 8),
        ],
        field,
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: TransferTheme.balanceCaption(context)),
        ],
      ],
    );
  }
}

/// Unboxed radio used on the web transfer form (Figma node 17:2159).
class TransferPlainRadio extends StatelessWidget {
  const TransferPlainRadio({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final active = selectedColor ?? HomeColors.brand(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? active : Colors.white,
                border: Border.all(
                  color: selected ? active : HomeColors.divider(context),
                ),
              ),
              child: selected
                  ? const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 6, height: 6),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TransferTheme.fieldFilled(context).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransferTextField extends StatelessWidget {
  const TransferTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.webLabel = false,
    this.underline = false,
    this.helperText,
    this.captionLabel = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool webLabel;
  final bool underline;
  final String? helperText;
  final bool captionLabel;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TransferTheme.fieldFilled(context),
      decoration: underline
          ? TransferTheme.underlineDecoration(
              context,
              hint: hint,
              prefixText: prefixText,
              helperText: helperText,
            )
          : TransferTheme.inputDecoration(
              context,
              hint: hint,
              prefixText: prefixText,
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: captionLabel
                ? TransferTheme.caption(context)
                : (webLabel || underline
                    ? TransferTheme.webLabel(context)
                    : TransferTheme.caption(context).copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                      )),
          ),
          SizedBox(height: underline ? 4 : 8),
        ],
        if (underline)
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: TransferTheme.underlineInputTheme(context),
            ),
            child: field,
          )
        else
          SizedBox(
            height: TransferTheme.inputHeight,
            child: field,
          ),
      ],
    );
  }
}

class TransferChargesCheck extends StatelessWidget {
  const TransferChargesCheck({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.web = false,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool web;

  @override
  Widget build(BuildContext context) {
    final active =
        web ? TransferTheme.webRadioSelected : HomeColors.brand(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: IgnorePointer(
                child: Checkbox(
                  value: value,
                  onChanged: (_) {},
                  activeColor: active,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: HomeColors.divider(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  label,
                  style: TransferTheme.caption(context).copyWith(
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
