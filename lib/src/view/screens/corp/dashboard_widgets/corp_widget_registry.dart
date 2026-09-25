import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_currency_exposure_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_financial_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_pickup_points_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_account_summary_card.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_quick_links_card.dart';

/// The Corporate dashboard's `componentName` → widget map.
class CorpWidgetRegistry extends DashboardWidgetRegistry {
  const CorpWidgetRegistry();

  @override
  Map<String, Widget Function()> get builders => {
        'account-financial-summary': () => const CorpFinancialSummaryWidget(),
        'account-quick-links': () => const CorpQuickLinksCard(),
        'currency-exposure': () => const CorpCurrencyExposureWidget(),
        'pickup-point-collections': () => const CorpPickupPointsWidget(),
        // `account-summary` is the demand-deposits module's per-account
        // grid, which is what our Account Summary card already shows.
        'account-summary': () => const CorpAccountSummaryCard(),
      };

  /// Sizes — half the row, the two-column arrangement both dashboards use
  /// (see [DashboardGridLayout.twoColumns]); saving 6 gives the web client
  /// two columns too.
  ///
  /// Account Summary is the exception: a multi-column table, too cramped
  /// at half width, so it spans both columns. Pickup Points has no catalog
  /// entry at all, so the app's sizes are authoritative here.
  @override
  Map<String, DashboardWidgetSpec> get specs => const {
        'account-financial-summary': _half,
        'account-quick-links': _half,
        'currency-exposure': _half,
        'pickup-point-collections': _half,
        'account-summary': DashboardWidgetSpec(large: 12),
      };

  static const _half = DashboardWidgetSpec(large: 6, medium: 12);
}
