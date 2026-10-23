import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// The OBDX Bill Payments menu on one page (`retail.json:470-503`, labels
/// `nls/menu.js:531-537`), opened from the side menu's single Bill Payments
/// entry. Billers, Add Billers and Bill Payment History are built
/// (docs/obdx/features/bill-payments.md §1); the rest wait under Coming
/// soon.
class BillPaymentsHubScreen extends StatelessWidget {
  const BillPaymentsHubScreen({
    super.key,
    required this.onBillersTap,
    required this.onAddBillerTap,
    required this.onHistoryTap,
  });

  final VoidCallback onBillersTap;
  final VoidCallback onAddBillerTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleHubPage(
      title: l10n.billPaymentsTitle,
      subtitle: l10n.billsModuleSubtitle,
      tiles: [
        PayOptionTile(
          icon: Icons.storefront_outlined,
          title: l10n.billersTitle,
          subtitle: l10n.billersDesc,
          onTap: onBillersTap,
        ),
        PayOptionTile(
          icon: Icons.add_business_outlined,
          title: l10n.billersAdd,
          subtitle: l10n.billersAddDesc,
          onTap: onAddBillerTap,
        ),
        PayOptionTile(
          icon: Icons.history_rounded,
          title: l10n.billHistoryTitle,
          subtitle: l10n.billHistoryDesc,
          onTap: onHistoryTap,
        ),
      ],
      comingSoon: [
        (Icons.star_border_rounded, l10n.billFavorites),
        (Icons.bolt_rounded, l10n.billQuickBillPay),
        (Icons.phone_android_rounded, l10n.billQuickRecharge),
      ],
    );
  }
}
