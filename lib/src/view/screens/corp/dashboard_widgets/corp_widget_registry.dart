import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_forecast_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_snapshot_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_withdrawal_live_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cashflow_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_currency_exposure_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_financial_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_pickup_points_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_live_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_live_widgets.dart';
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

        // Loans (module `loans`), on live data: `loan/v1/loan` and each
        // loan's detail call, shared by the four account widgets, and
        // `processManagement` for the tracker (see
        // `corp_widget_data_providers.dart`).
        'loan-summary': () => const CorpLiveLoanSummaryWidget(),
        'loan-application-tracker': () =>
            const CorpLiveLoanApplicationTrackerWidget(),
        'loan-installments-due': () => const CorpLiveLoanInstallmentsWidget(),
        'loan-portfolio': () => const CorpLiveLoanPortfolioWidget(),
        // The design's "Loan and Finance Summary" table.
        'loans-overview': () => const CorpLiveLoansOverviewWidget(),

        // Term deposits (module `term-deposits`), live: `td/v1/deposit`.
        'td-accounts-overview': () => const CorpLiveTdAccountsOverviewWidget(),
        'td-summary': () => const CorpLiveTdSummaryWidget(),

        // Cash management (module `cash-management`). The withdrawal
        // summary is live (`collections/CW`); the widgets capture shows no
        // call behind the other three, so they keep their sample figures
        // and "Sample data" tag.
        'cash-withdrawal-summary': () =>
            const CorpLiveCashWithdrawalSummaryWidget(),
        'cash-flow-forecast': () => const CorpCashFlowForecastWidget(),
        'cash-flow-snapshot': () => const CorpCashFlowSnapshotWidget(),
        // No OBDX catalog entry; the name is the app's own.
        'cashflow-summary': () => const CorpCashflowSummaryWidget(),
      };

  /// Sizes — half the row, the two-column arrangement both dashboards use
  /// (see [DashboardGridLayout.twoColumns]); saving 6 gives the web client
  /// two columns too.
  ///
  /// Account Summary, the Loan and Finance Summary and the TD Summary are
  /// the exceptions — multi-column tables, too cramped at half width — and
  /// so is the Cash Flow Forecast's chart; they span both columns. Pickup
  /// Points has no catalog entry at all, so the app's sizes are
  /// authoritative here.
  @override
  Map<String, DashboardWidgetSpec> get specs => const {
        'account-financial-summary': _half,
        'account-quick-links': _half,
        'currency-exposure': _half,
        'pickup-point-collections': _half,
        'account-summary': DashboardWidgetSpec(large: 12),
        'loan-summary': _half,
        'loan-application-tracker': _half,
        'loan-installments-due': _half,
        'loan-portfolio': _half,
        // An eight-column table, like Account Summary.
        'loans-overview': DashboardWidgetSpec(large: 12),
        'td-accounts-overview': _half,
        // A chart beside a table.
        'td-summary': DashboardWidgetSpec(large: 12),
        // A year of bars wants the whole width.
        'cash-flow-forecast': DashboardWidgetSpec(large: 12),
        'cash-flow-snapshot': _half,
        'cashflow-summary': _half,
        'cash-withdrawal-summary': _half,
      };

  static const _half = DashboardWidgetSpec(large: 6, medium: 12);

  /// The accounts card, which always leads the Corporate dashboard and is
  /// not a catalog widget. It counts toward the widget limit.
  @override
  int get fixedTileCount => 1;
}
