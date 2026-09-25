import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';

enum WebPayeeDestination { manage, add, addDemandDraft, addPeerToPeer }

/// "Accounts" ▸ CASA / Loans — both open a screen in the dashboard's
/// content area, next to the side menu.
enum WebAccountsDestination { casa, loans }

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
          label: l10n.transfer,
          icon: Icons.swap_horiz_rounded,
        ),
        DashboardNavItem(
          id: rewards,
          label: l10n.rewards,
          icon: Icons.card_giftcard_rounded,
        ),
        DashboardNavItem(
          id: accounts,
          label: l10n.accounts,
          icon: Icons.account_balance_outlined,
          children: const [
            // TODO(l10n): sub-item labels.
            DashboardNavItem(
              id: accountsCasa,
              label: 'CASA',
              icon: Icons.account_balance_wallet_outlined,
            ),
            DashboardNavItem(
              id: accountsLoans,
              label: 'Loans',
              icon: Icons.request_quote_outlined,
            ),
          ],
        ),
        // Last, after Accounts: a catch-all reads best at the end.
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
