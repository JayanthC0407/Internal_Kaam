import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_menu.dart';

/// The corporate dashboard's main navigation destinations, in menu order —
/// declaration order *is* the order the sidebar and drawer list them, so
/// [home] stays first.
///
/// Only [home] and [tradeFinance] have a built surface today; every other
/// destination renders the corporate shell's own placeholder panel (see
/// `CorpDashboardScreen._buildDestination`) so the sidebar, header and
/// session handling stay live while those modules are built out.
enum CorpNavDestination {
  home('Home', Icons.home_outlined),
  accounts('Accounts', Icons.account_balance_outlined),
  loan('Loan', Icons.savings_outlined),
  transfer('Transfer', Icons.swap_horiz_rounded),
  tradeFinance('Trade Finance', Icons.public_rounded),
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
  /// destinations' names, except [tradeFinance]'s Letter of Credit options,
  /// which nest three levels deep (Trade Finance ▸ Import/Export Letter of
  /// Credit ▸ option) — see [fromNavId] and [lcActionFromNavId].
  ///
  /// [lcPermissions] hides options the signed-in user's `me/components`
  /// does not entitle them to, and hides [tradeFinance] entirely when none
  /// are allowed — same rule the old per-destination Trade Finance tree
  /// used, carried over onto the shared nav widget.
  static List<DashboardNavItem> navItems(LcPermissions lcPermissions) {
    final items = <DashboardNavItem>[];
    for (final destination in values) {
      if (destination == tradeFinance) {
        final item = _tradeFinanceItem(lcPermissions);
        if (item != null) items.add(item);
      } else {
        items.add(DashboardNavItem(
          id: destination.name,
          label: destination.label,
          icon: destination.icon,
        ));
      }
    }
    return items;
  }

  /// Trade Finance ▸ Import/Export Letter of Credit ▸ option — the "Letter
  /// of Credit" level of the source menu tree is dropped since it has only
  /// the one child. Null when the user has no Trade Finance entitlements at
  /// all, so the whole destination disappears from the menu.
  static DashboardNavItem? _tradeFinanceItem(LcPermissions permissions) {
    final groups = [
      for (final group in LcMenuGroup.values)
        if (group.allowedActions(permissions).isNotEmpty)
          DashboardNavItem(
            id: '${tradeFinance.name}.${group.name}',
            label: group.label,
            icon: group.icon,
            children: [
              for (final action in group.allowedActions(permissions))
                DashboardNavItem(
                  id: '${tradeFinance.name}.${group.name}.${action.name}',
                  label: action.label,
                  icon: action.icon,
                ),
            ],
          ),
    ];
    if (groups.isEmpty) return null;
    return DashboardNavItem(
      id: tradeFinance.name,
      label: tradeFinance.label,
      icon: tradeFinance.icon,
      children: groups,
    );
  }

  /// The destination a tapped nav id belongs to — a plain name for every
  /// destination but [tradeFinance], whose ids nest (`tradeFinance`,
  /// `tradeFinance.<group>`, `tradeFinance.<group>.<action>`).
  static CorpNavDestination? fromNavId(String id) {
    for (final destination in values) {
      if (id == destination.name || id.startsWith('${destination.name}.')) {
        return destination;
      }
    }
    return null;
  }

  /// The Letter of Credit option a [tradeFinance] leaf id selects.
  ///
  /// Only leaf ids ever reach `onSelected` — tapping the root or a group
  /// row just expands it (`DashboardNavContent._onItemTap`) — so this only
  /// needs the id's last segment, which is unique across every action.
  static LcMenuAction? lcActionFromNavId(String id) {
    final tail = id.split('.').last;
    for (final action in LcMenuAction.values) {
      if (action.name == tail) return action;
    }
    return null;
  }
}
