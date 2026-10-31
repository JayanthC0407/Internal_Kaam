import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_menu.dart';

/// The corporate dashboard's main navigation destinations, in menu order —
/// declaration order *is* the order the sidebar and drawer list them, so
/// [home] stays first.
///
/// Built surfaces: [home], [tradeFinance], and the modules shared with
/// Retail (Accounts, Loan, Term Deposits, Transfer, Bill, Credit Card,
/// Service Requests, Mailbox, Calculators, More — see `CorpSharedModules`).
/// The [inMore] ones open from More rather than the side menu.
/// [statements] and [insurance] still render the corporate shell's
/// placeholder panel (see `CorpDashboardScreen._buildDestination`).
enum CorpNavDestination {
  home('Home', Icons.home_outlined),
  accounts('Accounts', Icons.account_balance_outlined),
  loan('Loan', Icons.savings_outlined),
  termDeposits('Term Deposits', Icons.account_balance_wallet_outlined),
  transfer('Transfer', Icons.swap_horiz_rounded),
  tradeFinance('Trade Finance', Icons.public_rounded),

  /// OBDX's Credit Facility Management (see [CfPage]).
  creditFacility('Credit Facility Management', Icons.account_tree_outlined),
  bill('Bill', Icons.receipt_long_outlined),
  statements('Statements', Icons.description_outlined),
  creditCard('Credit Card', Icons.credit_card_outlined),
  insurance('Insurance', Icons.shield_outlined),
  serviceRequests('Service Requests', Icons.support_agent_rounded),
  mailbox('Mailbox', Icons.mail_outline_rounded),
  calculators('Calculators', Icons.calculate_outlined),

  /// Last, like Retail's: the same More page (services hub), which also
  /// holds Mailbox, Service Requests and Calculators.
  more('More', Icons.more_horiz_rounded);

  /// Reached from More (and the bell for Mailbox), not listed in the side
  /// menu — as on Retail.
  static const inMore = {serviceRequests, mailbox, calculators};

  const CorpNavDestination(this.label, this.icon);

  // TODO(l10n): move these labels into AppLocalizations once translated
  // strings exist for every supported locale (the Retail nav has the same
  // pending TODO for its own product labels).
  final String label;
  final IconData icon;

  /// The Corporate side-menu entries, for the shared
  /// [DashboardNavigationSidebar] / [DashboardNavDrawer]. Ids are the
  /// destinations' names, except [tradeFinance]'s options, which nest four
  /// levels deep (Trade Finance ▸ Letter of Credit / Bank Guarantee ▸
  /// group ▸ option) — see [fromNavId], [lcActionFromNavId] and
  /// [navIdForLcAction].
  ///
  /// [lcPermissions] hides options the signed-in user's `me/components`
  /// does not entitle them to, and hides [tradeFinance] entirely when none
  /// are allowed — same rule the old per-destination Trade Finance tree
  /// used, carried over onto the shared nav widget.
  static List<DashboardNavItem> navItems(
    LcPermissions lcPermissions, {
    CfPermissions cfPermissions = const CfPermissions(),
  }) {
    final items = <DashboardNavItem>[];
    for (final destination in values) {
      if (inMore.contains(destination)) continue;
      if (destination == tradeFinance) {
        final item = _tradeFinanceItem(lcPermissions);
        if (item != null) items.add(item);
      } else if (destination == creditFacility) {
        final item = _creditFacilityItem(cfPermissions);
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

  /// Trade Finance ▸ section ▸ group ▸ option. A section or group the user
  /// has nothing allowed in is dropped; null when nothing at all is
  /// allowed, so the whole destination disappears from the menu.
  static DashboardNavItem? _tradeFinanceItem(LcPermissions permissions) {
    final sections = <DashboardNavItem>[];
    for (final section in TfMenuSection.values) {
      final groups = <DashboardNavItem>[];
      for (final group in section.groups) {
        final allowed = group.allowedActions(permissions);
        if (allowed.isEmpty) continue;
        if (group.isPlaceholder) {
          // One placeholder option: a plain row, not a one-child folder.
          groups.add(DashboardNavItem(
            id: navIdForLcAction(allowed.single),
            label: group.label,
            icon: group.icon,
          ));
          continue;
        }
        groups.add(DashboardNavItem(
          id: '${tradeFinance.name}.${section.name}.${group.name}',
          label: group.label,
          icon: group.icon,
          children: [
            for (final action in allowed)
              DashboardNavItem(
                id: navIdForLcAction(action),
                label: action.label,
                icon: action.icon,
              ),
          ],
        ));
      }
      if (groups.isEmpty) continue;
      sections.add(DashboardNavItem(
        id: '${tradeFinance.name}.${section.name}',
        label: section.label,
        icon: section.icon,
        children: groups,
      ));
    }
    if (sections.isEmpty) return null;
    return DashboardNavItem(
      id: tradeFinance.name,
      label: tradeFinance.label,
      icon: tradeFinance.icon,
      children: sections,
    );
  }

  /// Credit Facility Management ▸ Credit Facility ▸ the allowed pages; null
  /// when none is allowed.
  static DashboardNavItem? _creditFacilityItem(CfPermissions permissions) {
    final pages = [for (final p in CfPage.values) if (p.allowedBy(permissions)) p];
    if (pages.isEmpty) return null;
    return DashboardNavItem(
      id: creditFacility.name,
      label: creditFacility.label,
      icon: creditFacility.icon,
      children: [
        DashboardNavItem(
          id: '${creditFacility.name}.credit',
          label: CfPage.creditFacilityGroup,
          icon: Icons.request_quote_outlined,
          children: [
            for (final p in pages) DashboardNavItem(id: navIdForCfPage(p), label: p.label, icon: p.icon),
          ],
        ),
      ],
    );
  }

  /// The menu id of a Credit Facility page: `creditFacility.credit.<page>`.
  static String navIdForCfPage(CfPage page) => '${creditFacility.name}.credit.${page.name}';

  /// The Credit Facility page a leaf id selects.
  static CfPage? cfPageFromNavId(String id) {
    final tail = id.split('.').last;
    for (final page in CfPage.values) {
      if (page.name == tail) return page;
    }
    return null;
  }

  /// The menu id of a Trade Finance option's row:
  /// `tradeFinance.<section>.<group>.<action>`.
  static String navIdForLcAction(LcMenuAction action) =>
      '${tradeFinance.name}.${action.group.section.name}.'
      '${action.group.name}.${action.name}';

  /// The destination a tapped nav id belongs to — a plain name for every
  /// destination but [tradeFinance], whose ids nest (`tradeFinance`,
  /// `tradeFinance.<section>`, `….<group>`, `….<action>`).
  static CorpNavDestination? fromNavId(String id) {
    for (final destination in values) {
      if (id == destination.name || id.startsWith('${destination.name}.')) {
        return destination;
      }
    }
    return null;
  }

  /// The Trade Finance option a [tradeFinance] leaf id selects.
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
