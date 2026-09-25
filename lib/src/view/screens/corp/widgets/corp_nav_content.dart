import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';

/// The corporate dashboard's main navigation destinations, in menu order —
/// declaration order *is* the order the sidebar and drawer list them, so
/// [home] stays first.
///
/// Only [home] has a built surface today; every other destination renders
/// the corporate shell's own placeholder panel (see
/// `CorpDashboardScreen._buildDestination`) so the sidebar, header and
/// session handling stay live while those modules are built out.
enum CorpNavDestination {
  home('Home', Icons.home_outlined),
  accounts('Accounts', Icons.account_balance_outlined),
  loan('Loan', Icons.savings_outlined),
  transfer('Transfer', Icons.swap_horiz_rounded),
  bill('Bill', Icons.receipt_long_outlined),
  statements('Statements', Icons.description_outlined),
  creditCard('Credit Card', Icons.credit_card_outlined),
  insurance('Insurance', Icons.shield_outlined);

  const CorpNavDestination(this.label, this.icon);

  // TODO(l10n): move these labels into AppLocalizations once translated
  // strings exist for every supported locale (the Retail nav has the same
  // pending TODO for its own product labels).
  final String label;
  final IconData icon;

  /// The Corporate side-menu entries, for the shared
  /// [DashboardNavigationSidebar] / [DashboardNavDrawer]. Ids are the
  /// destinations' names — see [fromNavId].
  static List<DashboardNavItem> get navItems => [
        for (final destination in values)
          DashboardNavItem(
            id: destination.name,
            label: destination.label,
            icon: destination.icon,
          ),
      ];

  static CorpNavDestination? fromNavId(String id) {
    for (final destination in values) {
      if (destination.name == id) return destination;
    }
    return null;
  }
}
