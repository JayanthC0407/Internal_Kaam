import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// OBDX's Accounts → Current & Savings menu on one page
/// (`retail.json:7-53`, labels `nls/menu.js:42-64, 587`), opened from the
/// side menu's Current & Savings entry, like the Payments and Credit Cards
/// pages. Current & Savings Accounts opens the account list (its details
/// and transactions are inside it); Cheque Book Request, Debit Cards and
/// Sweep-In are built; the rest wait under Coming soon. Evidence:
/// docs/obdx/features/debit-cards.md §1, cheque-book-request.md, sweep-in.md.
class CurrentSavingsHubScreen extends StatelessWidget {
  const CurrentSavingsHubScreen({
    super.key,
    required this.onAccountsTap,
    required this.onChequeBookTap,
    required this.onDebitCardsTap,
    required this.onSweepInTap,
  });

  final VoidCallback onAccountsTap;
  final VoidCallback onChequeBookTap;
  final VoidCallback onDebitCardsTap;
  final VoidCallback onSweepInTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleHubPage(
      title: l10n.casaMenuTitle,
      subtitle: l10n.casaHubSubtitle,
      tiles: [
        PayOptionTile(
          icon: Icons.account_balance_wallet_outlined,
          title: l10n.casaAccountsTitle,
          subtitle: l10n.casaAccountsDesc,
          onTap: onAccountsTap,
        ),
        PayOptionTile(
          icon: Icons.menu_book_rounded,
          title: l10n.casaChequeBookRequest,
          subtitle: l10n.cbrDesc,
          onTap: onChequeBookTap,
        ),
        PayOptionTile(
          icon: Icons.credit_card_rounded,
          title: l10n.dcTitle,
          subtitle: l10n.dcDesc,
          onTap: onDebitCardsTap,
        ),
        PayOptionTile(
          icon: Icons.sync_alt_rounded,
          title: l10n.casaSweepIn,
          subtitle: l10n.swpDesc,
          onTap: onSweepInTap,
        ),
      ],
      // OBDX's order: Cheque Status Inquiry, Stop/Unblock Cheque.
      comingSoon: [
        (Icons.manage_search_rounded, l10n.casaChequeStatusInquiry),
        (Icons.block_rounded, l10n.casaStopUnblockCheque),
      ],
    );
  }
}
