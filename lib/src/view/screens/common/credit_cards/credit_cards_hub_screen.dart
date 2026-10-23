import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// The OBDX Credit Cards menu on one page (`retail.json:258-330`, labels
/// `nls/menu.js:262-272`), opened from the side menu's single Credit Cards
/// entry. Credit Cards and Transactions are built; the card actions are
/// Access Denied in UAT (docs/obdx/features/credit-cards.md §1), so they
/// wait under Coming soon.
class CreditCardsHubScreen extends StatelessWidget {
  const CreditCardsHubScreen({super.key, required this.onCreditCardsTap, required this.onTransactionsTap});

  final VoidCallback onCreditCardsTap;
  final VoidCallback onTransactionsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleHubPage(
      title: l10n.ccTitle,
      subtitle: l10n.ccModuleSubtitle,
      tiles: [
        PayOptionTile(
          icon: Icons.credit_card_rounded,
          title: l10n.ccTitle,
          subtitle: l10n.ccListDesc,
          onTap: onCreditCardsTap,
        ),
        PayOptionTile(
          icon: Icons.receipt_long_rounded,
          title: l10n.ccTransactions,
          subtitle: l10n.ccTransactionsDesc,
          onTap: onTransactionsTap,
        ),
      ],
      comingSoon: [
        (Icons.article_outlined, l10n.ccCardDetails),
        (Icons.payments_outlined, l10n.ccCardPayment),
        (Icons.pin_outlined, l10n.ccRequestPin),
        (Icons.block_rounded, l10n.ccBlockUnblock),
        (Icons.cancel_outlined, l10n.ccCancelCard),
        (Icons.autorenew_rounded, l10n.ccAutoPay),
        (Icons.password_rounded, l10n.ccResetPin),
        (Icons.add_card_rounded, l10n.ccAddOn),
      ],
    );
  }
}
