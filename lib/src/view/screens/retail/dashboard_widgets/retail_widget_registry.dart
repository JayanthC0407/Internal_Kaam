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
        'financial-summary': () => const RetailAccountsWidget(),
        'recent-account-transactions': () =>
            const RetailRecentTransactionsWidget(),
        'spend-summary': () => const RetailSpendSummaryWidget(),
        'loan-summary': () => const RetailLoanSummaryWidget(),
        'quick-links': () => const RetailQuickLinksWidget(),
      };
}
