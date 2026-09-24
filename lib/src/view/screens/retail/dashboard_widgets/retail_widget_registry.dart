import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';

/// The Retail dashboard's `componentName` → widget map.
///
/// The names come from the OBDX catalog's retail-eligible entries; the
/// widgets are the ones the Retail dashboard already renders. Five of the
/// catalog's 41 retail-eligible components have a Flutter implementation —
/// everything else the user selects draws a named placeholder, exactly as
/// on Corporate.
///
/// Note `financial-summary` (module `accounts`, retail) is a different
/// component from Corporate's `account-financial-summary`, which is why
/// each user type gets its own registry rather than sharing one map.
class RetailWidgetRegistry extends DashboardWidgetRegistry {
  const RetailWidgetRegistry();

  @override
  Map<String, Widget Function()> get builders => {
        // ── Names seen on a real retail user's saved dashboard ──────────
        //
        // These come from the configuration the host actually returns, not
        // from the catalog. An earlier version of this map was derived from
        // the catalog's retail-eligible entries and matched almost none of
        // them, so the whole dashboard rendered as placeholders.
        'casa-account-card': () => const RetailCasaAccountsWidget(),
        'casa-balance-card': () => const RetailAccountsWidget(),
        'loans-account-card': () => const RetailLoanAccountsWidget(),
        'loans-balance-card': () => const RetailLoanSummaryWidget(),
        'dashboard-quick-links': () => const RetailQuickLinksWidget(),
        'credit-card': () => const RetailCreditCardsWidget(),

        // ── Catalog names for the same widgets ──────────────────────────
        //
        // Kept alongside: a user whose dashboard was built from the catalog
        // rather than these host names should still render.
        'financial-summary': () => const RetailAccountsWidget(),
        'recent-account-transactions': () =>
            const RetailRecentTransactionsWidget(),
        'spend-summary': () => const RetailSpendSummaryWidget(),
        'loan-summary': () => const RetailLoanSummaryWidget(),
        'quick-links': () => const RetailQuickLinksWidget(),
        'offers': () => const RetailOffersWidget(),
      };

  /// Every widget the fixed Retail dashboard renders, in its original
  /// order — the layout used when the user has no saved configuration.
  ///
  /// Keeping this beside the map is what guarantees the default and the
  /// personalized paths draw the same set: if a widget is added to one it
  /// has to be added here too, or it is plainly missing.
  static const defaultComponents = <String>[
    'financial-summary',
    'quick-links',
    'loan-summary',
    'spend-summary',
    'recent-account-transactions',
    'offers',
  ];
}
