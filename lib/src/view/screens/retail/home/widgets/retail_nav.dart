import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';

enum WebPayeeDestination { manage, add, addDemandDraft, addPeerToPeer }

/// "Accounts" ▸ CASA / Loans / Term Deposits — each opens a screen in
/// the dashboard's content area, next to the side menu.
enum WebAccountsDestination { casa, loans, termDeposits }

/// The Retail dashboard's side-menu entries, for the shared
/// [DashboardNavigationSidebar] / [DashboardNavDrawer].
///
/// The top-level ids map to the dashboard's tab indices ([tabIds]); the
/// Accounts children to [WebAccountsDestination].
class RetailNav {
  const RetailNav._();

  static const home = 'home';
  static const insights = 'insights';
  static const transfer = 'transfer';
  static const rewards = 'rewards';
  static const more = 'more';
  static const accounts = 'accounts';
  static const accountsCasa = 'accounts.casa';
  static const accountsLoans = 'accounts.loans';
  static const accountsTermDeposits = 'accounts.termDeposits';

  /// OBDX Accounts → Certificates (Interest, Balance, TDS): a module page.
  static const accountsCertificates = 'accounts.certificates';

  /// OBDX Accounts → Nominations.
  static const accountsNominations = 'accounts.nominations';
  static const creditCards = 'creditCards';
  static const billPayments = 'billPayments';

  /// Tab index → id, for the dashboard's first five tabs — the same
  /// indices the phone's bottom bar uses.
  static const tabIds = [home, insights, transfer, rewards, more];

  static List<DashboardNavItem> items(AppLocalizations l10n) => [
        DashboardNavItem(
          id: home,
          label: l10n.home,
          icon: Icons.home_rounded,
        ),
        DashboardNavItem(
          id: insights,
          label: l10n.insights,
          icon: Icons.pie_chart_outline_rounded,
        ),
        DashboardNavItem(
          id: transfer,
          label: l10n.menuPayments,
          icon: Icons.swap_horiz_rounded,
          // OBDX's Payments. One entry, no submenu: it opens the Payments
          // hub, which lays out every transfer on one page.
        ),
        // Rewards, Mailbox, Service Requests and Calculators live in More,
        // not here.
        DashboardNavItem(
          id: accounts,
          label: l10n.accounts,
          icon: Icons.account_balance_outlined,
          children: [
            // TODO(l10n): sub-item labels.
            const DashboardNavItem(
              id: accountsCasa,
              label: 'Current & Savings',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const DashboardNavItem(
              id: accountsLoans,
              label: 'Loans & Finances',
              icon: Icons.request_quote_outlined,
            ),
            DashboardNavItem(
              id: accountsTermDeposits,
              label: l10n.menuTermDeposits,
              icon: Icons.savings_outlined,
            ),
            DashboardNavItem(
              id: accountsNominations,
              label: l10n.nomTitle,
              icon: Icons.family_restroom_rounded,
            ),
            DashboardNavItem(
              id: accountsCertificates,
              label: l10n.certMenuTitle,
              icon: Icons.workspace_premium_outlined,
            ),
          ],
        ),
        // OBDX's Credit Cards menu (before Bill Payments, as in OBDX). One
        // entry, no submenu, like Payments: it opens a page with the whole
        // module.
        DashboardNavItem(
          id: creditCards,
          label: l10n.ccTitle,
          icon: Icons.credit_card_rounded,
        ),
        // OBDX's Bill Payments menu; one entry opening its module page.
        DashboardNavItem(
          id: billPayments,
          label: l10n.billPaymentsTitle,
          icon: Icons.receipt_long_rounded,
        ),
        // Last, after Accounts: a catch-all reads best at the end. It also
        // holds Rewards, Mailbox, Service Requests and Calculators.
        DashboardNavItem(
          id: more,
          label: l10n.more,
          icon: Icons.more_horiz_rounded,
        ),
      ];

  static DashboardNavFooter footer(AppLocalizations l10n) => DashboardNavFooter(
        label: l10n.security,
        icon: Icons.lock_outline_rounded,
      );
}
