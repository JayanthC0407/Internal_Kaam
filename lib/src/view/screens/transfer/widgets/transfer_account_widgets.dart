import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/own_account_transfer.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/transfer/transfer_theme.dart';

/// Option 2 — Transfer From card with Change button and balance row.
class TransferFromAccountCard extends StatelessWidget {
  const TransferFromAccountCard({
    super.key,
    required this.account,
    required this.onChange,
    this.leadingIcon = Icons.account_balance_rounded,
    this.showBalance = true,
  });

  final CasaAccount account;
  final VoidCallback onChange;
  final IconData leadingIcon;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final balance = account.displayBalance;
    final balanceText = balance == null
        ? null
        : MoneyFormat.format(
            balance.amount,
            currencyCode: balance.currency ?? account.currencyCode,
          );

    return Container(
      decoration: TransferTheme.elevatedCard(context),
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: TransferTheme.accountIconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  leadingIcon,
                  color: brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TransferTheme.compactTitle(account.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TransferTheme.accountName(context),
                    ),
                    Text(
                      TransferTheme.maskLastFour(account.displayNumber),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TransferTheme.accountMask(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TransferChangeButton(onPressed: onChange, label: l10n.change),
            ],
          ),
          if (showBalance && balanceText != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: TransferTheme.rowDivider),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  l10n.balance,
                  style: TransferTheme.caption(context),
                ),
                const Spacer(),
                Text(
                  balanceText,
                  style: TransferTheme.accountName(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferChangeButton extends StatelessWidget {
  const _TransferChangeButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Material(
      color: brand,
      borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile Change picker — list sheet (Figma card + Change, not a web dropdown).
class TransferAccountPicker {
  TransferAccountPicker._();

  static Future<CasaAccount?> show({
    required BuildContext context,
    required String title,
    required List<CasaAccount> accounts,
    CasaAccount? selected,
  }) {
    if (accounts.isEmpty) return Future<CasaAccount?>.value();
    final brand = HomeColors.brand(context);
    return showModalBottomSheet<CasaAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.6;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(ctx).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: HomeColors.card(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TransferTheme.rowDivider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: TransferTheme.stepTitle(ctx)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final isSelected = selected?.id == account.id;
                      return Material(
                        color: isSelected
                            ? brand.withValues(alpha: 0.06)
                            : HomeColors.bg(ctx),
                        borderRadius:
                            BorderRadius.circular(TransferTheme.cardRadius),
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(account),
                          borderRadius:
                              BorderRadius.circular(TransferTheme.cardRadius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        TransferTheme.compactTitle(
                                          account.title,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TransferTheme.accountName(ctx),
                                      ),
                                      Text(
                                        TransferTheme.maskLastFour(
                                          account.displayNumber,
                                        ),
                                        style: TransferTheme.accountMask(ctx),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? brand
                                      : HomeColors.navInactive(ctx),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TransferAccountSummaryRow extends StatelessWidget {
  const TransferAccountSummaryRow({
    super.key,
    required this.fromAccount,
    required this.toAccount,
  });

  final CasaAccount fromAccount;
  final CasaAccount toAccount;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.all(TransferTheme.cardPadding),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
        border: Border.all(color: TransferTheme.cardBorderMuted),
      ),
      child: Row(
        children: [
          Flexible(
            child: _AccountChip(
              account: fromAccount,
              icon: Icon(Icons.account_balance_rounded, color: brand, size: 20),
              iconBg: TransferTheme.accountIconBg,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _AccountChip(
              account: toAccount,
              alignEnd: true,
              icon: CircleAvatar(
                radius: 20,
                backgroundColor: TransferTheme.rowDivider,
                child: Icon(
                  Icons.person_rounded,
                  color: HomeColors.textSecondary(context),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.icon,
    this.iconBg,
    this.alignEnd = false,
  });

  final CasaAccount account;
  final Widget icon;
  final Color? iconBg;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TransferTheme.accountName(context);
    final numberStyle = TransferTheme.caption(context);

    final texts = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          TransferTheme.compactTitle(account.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        Text(
          TransferTheme.maskLastFour(account.displayNumber),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: numberStyle,
        ),
      ],
    );

    final iconWidget = iconBg != null
        ? Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(child: icon),
          )
        : icon;

    return Row(
      children: [
        if (!alignEnd) ...[
          iconWidget,
          const SizedBox(width: 8),
        ],
        Flexible(child: texts),
        if (alignEnd) ...[
          const SizedBox(width: 8),
          iconWidget,
        ],
      ],
    );
  }
}

/// Option 2 — exchange rate card with indicative footer band.
class TransferExchangeRateBox extends StatelessWidget {
  const TransferExchangeRateBox({
    super.key,
    required this.title,
    required this.rateLabel,
    required this.rateValue,
    required this.calculatedLabel,
    required this.calculatedValue,
    required this.indicativeNote,
    this.visible = true,
  });

  final String title;
  final String rateLabel;
  final String rateValue;
  final String calculatedLabel;
  final String calculatedValue;
  final String indicativeNote;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TransferTheme.exchangeCardBg,
          borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TransferTheme.stepTitle(context),
                  ),
                  const SizedBox(height: 12),
                  _RateLine(
                    label: rateLabel,
                    value: rateValue,
                    showInfo: true,
                  ),
                  const SizedBox(height: 8),
                  _RateLine(
                    label: calculatedLabel,
                    value: calculatedValue,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: TransferTheme.exchangeFooterBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                indicativeNote,
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  color: TransferTheme.exchangeAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine({
    required this.label,
    required this.value,
    this.showInfo = false,
  });

  final String label;
  final String value;
  final bool showInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TransferTheme.caption(context),
                ),
              ),
              if (showInfo) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: HomeColors.textSecondary(context),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TransferTheme.caption(context).copyWith(
              fontWeight: FontWeight.w400,
              color: HomeColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Option 2 — receipt-style review rows.
class TransferReviewRow extends StatelessWidget {
  const TransferReviewRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
    this.subValueColor,
    this.boldValue = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final Color? valueColor;
  final Color? subValueColor;
  final bool boldValue;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final secondary = HomeColors.textSecondary(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: subValue == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: secondary),
              const SizedBox(width: 10),
              Padding(
                padding: EdgeInsets.only(top: subValue == null ? 0 : 1),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TransferTheme.caption(context).copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: boldValue
                          ? TransferTheme.fieldFilled(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 22 / 16,
                            )
                          : (valueColor != null
                              ? TransferTheme.fieldFilled(context).copyWith(
                                  color: valueColor,
                                )
                              : TransferTheme.reviewValue(context)),
                    ),
                    if (subValue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subValue!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TransferTheme.caption(context).copyWith(
                          color: subValueColor ?? secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: TransferTheme.rowDivider),
      ],
    );
  }
}

/// Option 2 — large amount input with currency pill (step 2).
class TransferAmountInput extends StatelessWidget {
  const TransferAmountInput({
    super.key,
    required this.controller,
    required this.currency,
    required this.currencies,
    required this.onCurrencyChanged,
  });

  final TextEditingController controller;
  final String currency;
  final List<String> currencies;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final menuItems = [
      if (currency.isNotEmpty && !currencies.contains(currency)) currency,
      ...currencies,
    ];
    final selected = menuItems.contains(currency) ? currency : null;
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: brand, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currency,
            style: TransferTheme.fieldFilled(context).copyWith(
              fontWeight: FontWeight.w500,
              height: 1,
              color: HomeColors.textSecondary(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                style: TransferTheme.amountLarge(context),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F5),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                menuMaxHeight: 280,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: Color(0xFF111322),
                ),
                dropdownColor: Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: HomeColors.textPrimary(context),
                ),
                items: [
                  for (final c in menuItems)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(color: Color(0xFF111322)),
                      ),
                    ),
                ],
                onChanged: menuItems.isEmpty
                    ? null
                    : (v) {
                        if (v != null) onCurrencyChanged(v);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White or muted card used to group Option 2 amount / settings sections.
class TransferSoftCard extends StatelessWidget {
  const TransferSoftCard({
    super.key,
    required this.child,
    this.color,
  });

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? HomeColors.card(context),
        borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
        border: Border.all(color: const Color(0xFFDCDFEA)),
      ),
      child: child,
    );
  }
}

/// Web Figma exchange-rate panel (mint fill, two columns).
class TransferWebExchangeBox extends StatelessWidget {
  const TransferWebExchangeBox({
    super.key,
    required this.title,
    required this.rateLabel,
    required this.rateValue,
    required this.calculatedLabel,
    required this.calculatedValue,
    required this.indicativeNote,
    this.visible = true,
  });

  final String title;
  final String rateLabel;
  final String rateValue;
  final String calculatedLabel;
  final String calculatedValue;
  final String indicativeNote;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: TransferTheme.webFxBg,
        borderRadius: BorderRadius.circular(TransferTheme.cardRadius),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: TransferTheme.exchangeAccent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rateLabel, style: TransferTheme.fieldLabel(context)),
                    const SizedBox(height: 4),
                    Text(
                      rateValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      calculatedLabel,
                      style: TransferTheme.fieldLabel(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      calculatedValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(indicativeNote, style: TransferTheme.balanceCaption(context)),
        ],
      ),
    );
  }
}

/// Native [DropdownButton] — never a bottom sheet or modal picker.
class TransferWebSelect<T> extends StatelessWidget {
  const TransferWebSelect({
    super.key,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.helper,
  });

  final List<T> items;
  final T? value;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? hint;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final resolvedItems = [
      if (value != null && !items.any((e) => e == value)) value as T,
      ...items,
    ];
    final selected =
        value != null && resolvedItems.any((e) => e == value) ? value : null;

    final field = InputDecorator(
      decoration: TransferTheme.inputDecoration(context),
      isEmpty: selected == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          isDense: true,
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TransferTheme.fieldValue(context),
                ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 24,
            color: HomeColors.textSecondary(context),
          ),
          style: TransferTheme.fieldFilled(context),
          dropdownColor: HomeColors.card(context),
          borderRadius: BorderRadius.circular(TransferTheme.fieldRadius),
          menuMaxHeight: 320,
          items: [
            for (final item in resolvedItems)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelFor(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TransferTheme.fieldFilled(context),
                ),
              ),
          ],
          onChanged: resolvedItems.isEmpty
              ? null
              : (v) {
                  if (v != null) onChanged(v);
                },
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(label!, style: TransferTheme.webLabel(context)),
          const SizedBox(height: 8),
        ],
        SizedBox(height: TransferTheme.inputHeight, child: field),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(helper!, style: TransferTheme.balanceCaption(context)),
        ],
      ],
    );
  }
}

/// Success receipt used inside the Transfer tab (web) and the mobile route.
class TransferSuccessContent extends StatelessWidget {
  const TransferSuccessContent({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final TransferConfirmationSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final result = snapshot.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: brand,
              size: compact ? 32 : 40,
            ),
          ),
        ),
        SizedBox(height: compact ? 16 : 20),
        Text(
          l10n.transferSuccessTitle,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TransferTheme.stepTitle(context).copyWith(
            fontSize: compact ? 18 : 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.transferSuccessMessage,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TransferTheme.bodySecondary(context),
        ),
        const SizedBox(height: 24),
        TransferReviewRow(
          icon: Icons.tag_rounded,
          label: l10n.hostReferenceNumber,
          value: result.externalReferenceNumber?.isNotEmpty == true
              ? result.externalReferenceNumber!
              : result.referenceNumber,
        ),
        if (snapshot.fromMeta.isNotEmpty)
          TransferReviewRow(
            icon: Icons.account_balance_rounded,
            label: l10n.transferSummaryFrom,
            value: snapshot.fromMeta,
            subValue: snapshot.fromMask,
          ),
        if (snapshot.toMeta.isNotEmpty)
          TransferReviewRow(
            icon: Icons.person_outline_rounded,
            label: l10n.transferSummaryTo,
            value: snapshot.toMeta,
            subValue: snapshot.toMask,
          ),
        if (snapshot.amountText.isNotEmpty)
          TransferReviewRow(
            icon: Icons.send_rounded,
            label: l10n.youSend,
            value: snapshot.amountText,
            boldValue: true,
          ),
        if (snapshot.whenText.isNotEmpty)
          TransferReviewRow(
            icon: Icons.schedule_rounded,
            label: l10n.timing,
            value: snapshot.whenText,
            showDivider: snapshot.note.isNotEmpty,
          ),
        if (snapshot.note.isNotEmpty)
          TransferReviewRow(
            icon: Icons.notes_rounded,
            label: l10n.note,
            value: snapshot.note,
            showDivider: false,
          ),
      ],
    );
  }
}
