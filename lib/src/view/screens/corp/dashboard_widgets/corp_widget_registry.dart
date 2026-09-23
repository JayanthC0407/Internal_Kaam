import 'package:flutter/material.dart';
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
}
