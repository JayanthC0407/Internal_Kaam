import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// The OBDX Calculators menu on one page (`retail.json:737-760`, labels
/// `nls/menu.js:275-279`), opened from the side menu's single Calculators
/// entry and the Home Calculator action. All four are built
/// (docs/obdx/features/calculators.md).
class CalculatorsHubScreen extends StatelessWidget {
  const CalculatorsHubScreen({
    super.key,
    required this.onTdTap,
    required this.onLoanInstallmentTap,
    required this.onLoanEligibilityTap,
    required this.onForexTap,
  });

  final VoidCallback onTdTap;
  final VoidCallback onLoanInstallmentTap;
  final VoidCallback onLoanEligibilityTap;
  final VoidCallback onForexTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // OBDX menu order: Term Deposit, Loan Installment, Loan Eligibility, Forex.
    return ModuleHubPage(
      title: l10n.calcTitle,
      subtitle: l10n.calcHubSubtitle,
      tiles: [
        PayOptionTile(icon: Icons.savings_outlined, title: l10n.calcTd, subtitle: l10n.calcTdDesc, onTap: onTdTap),
        PayOptionTile(
          icon: Icons.request_quote_outlined,
          title: l10n.calcLoanInstallment,
          subtitle: l10n.calcLoanInstallmentDesc,
          onTap: onLoanInstallmentTap,
        ),
        PayOptionTile(
          icon: Icons.fact_check_outlined,
          title: l10n.calcLoanEligibility,
          subtitle: l10n.calcLoanEligibilityDesc,
          onTap: onLoanEligibilityTap,
        ),
        PayOptionTile(
          icon: Icons.currency_exchange_rounded,
          title: l10n.calcForex,
          subtitle: l10n.calcForexDesc,
          onTap: onForexTap,
        ),
      ],
    );
  }
}
