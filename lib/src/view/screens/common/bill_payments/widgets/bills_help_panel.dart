import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// The designer's Bill Payments help cards (UI designs 2026-10-27): an icon
/// tile beside a title and paragraphs. Designer copy, with "Demo Bank" in
/// place of the mock's "Futura Bank".
class BillsHelpPanel extends StatelessWidget {
  const BillsHelpPanel({super.key, required this.title, required this.paragraphs, this.action});

  /// "Pay bills hassle free", on Billers.
  factory BillsHelpPanel.pay(AppLocalizations l10n) => BillsHelpPanel(
        title: l10n.billsHelpPayTitle,
        paragraphs: [l10n.billsHelpPayBody1, l10n.billsHelpPayBody2, l10n.billsHelpPayBody3],
      );

  /// "Decided to make online bill payment? Great!", on Add Billers and
  /// on Billers while there are none.
  factory BillsHelpPanel.add(AppLocalizations l10n, {Widget? action}) => BillsHelpPanel(
        title: l10n.billsHelpAddTitle,
        paragraphs: [l10n.billsHelpAddBody1, l10n.billsHelpAddBody2],
        action: action,
      );

  final String title;
  final List<String> paragraphs;

  /// E.g. Add Billers, under the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return PayCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: brand.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.currency_rupee_rounded, color: brand),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                ),
                for (final p in paragraphs) ...[
                  const SizedBox(height: 10),
                  Text(p, style: TextStyle(fontSize: 13.5, height: 1.45, color: HomeColors.textSecondary(context))),
                ],
                if (action != null) ...[const SizedBox(height: 14), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
