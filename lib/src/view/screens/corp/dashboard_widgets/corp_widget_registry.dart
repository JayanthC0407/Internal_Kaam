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

/// The OBDX `componentName` each Corporate widget is registered under.
///
/// Held here, as named constants, rather than as string literals scattered
/// through [CorpWidgetRegistry], because a component name is the host's to
/// define: it comes from that environment's `moduleComponents.json`, and
/// the same widget can be named differently on another host. Correcting a
/// name is then a one-line change here and nothing else moves.
///
/// Every name below is confirmed against this environment's
/// `moduleComponents.json`, together with the module that owns it and the
/// `segment` it is offered to — all of the widget entries here are
/// `corporateuser`, so none of them can leak onto a Retail dashboard.
class CorpComponentNames {
  const CorpComponentNames._();

  // ── module: corporateDashboard ────────────────────────────────────────

  static const String financialSummary = 'account-financial-summary';
  static const String quickLinks = 'account-quick-links';
  static const String currencyExposure = 'currency-exposure';

  // ── module: cash-management ───────────────────────────────────────────

  static const String pickupPointCollections = 'pickup-point-collections';

  // ── module: demand-deposits ───────────────────────────────────────────

  /// The per-account grid, which is what our Account Summary card shows.
  static const String accountSummary = 'account-summary';

  // ── module: term-deposits ─────────────────────────────────────────────

  /// TD Accounts Overview. Catalog: `large 4 / medium 12`, height 320.
  static const String termDepositOverview = 'td-accounts-overview';

  // ── module: loans ─────────────────────────────────────────────────────

  /// Catalog: `large 4 / medium 6`, height 251.
  static const String loanSummary = 'loan-summary';

  /// Catalog: `large 8 / medium 6 / small 12`, height 289.
  static const String loanInstallmentsDue = 'loan-installments-due';

  /// Catalog: `large 4 / medium 6`, height 251.
  static const String loanPortfolio = 'loan-portfolio';

  /// Catalog: `large 6 / medium 6`, height 251.
  static const String loanApplicationTracker = 'loan-application-tracker';

  /// The design's "Loan and Finance Summary" table. Catalog: `large 6`.
  static const String loansOverview = 'loans-overview';

  // ── module: term-deposits (continued) ─────────────────────────────────

  /// Catalog: `large 8 / medium 12`, height 224.
  static const String termDepositSummary = 'td-summary';

  // ── module: cash-management (continued) ───────────────────────────────

  /// Catalog: `large 12 / medium 12`.
  static const String cashFlowForecast = 'cash-flow-forecast';

  /// Catalog: `large 12 / medium 12`, height 220.
  static const String cashFlowSnapshot = 'cash-flow-snapshot';

  /// Not in this environment's catalog, but on the corporate dashboard
  /// saved in the widgets capture (`HAR for widgets.har`).
  static const String cashWithdrawalSummary = 'cash-withdrawal-summary';

  /// Neither in the catalog nor in a capture; the name is the app's own,
  /// so the widget is only offered where a host's catalog lists it.
  static const String cashflowSummary = 'cashflow-summary';
}

/// The Corporate dashboard's `componentName` → widget map.
class CorpWidgetRegistry extends DashboardWidgetRegistry {
  const CorpWidgetRegistry();

  @override
  Map<String, Widget Function()> get builders => {
        CorpComponentNames.financialSummary: () =>
            const CorpFinancialSummaryWidget(),
        CorpComponentNames.quickLinks: () => const CorpQuickLinksCard(),
        CorpComponentNames.currencyExposure: () =>
            const CorpCurrencyExposureWidget(),
        CorpComponentNames.pickupPointCollections: () =>
            const CorpPickupPointsWidget(),
        CorpComponentNames.accountSummary: () => const CorpAccountSummaryCard(),

        // Loans, on live data: `loan/v1/loan` and each loan's detail call,
        // shared by the four account widgets, and `processManagement` for
        // the tracker (see `corp_widget_data_providers.dart`).
        CorpComponentNames.loanSummary: () => const CorpLiveLoanSummaryWidget(),
        CorpComponentNames.loanApplicationTracker: () =>
            const CorpLiveLoanApplicationTrackerWidget(),
        CorpComponentNames.loanInstallmentsDue: () =>
            const CorpLiveLoanInstallmentsWidget(),
        CorpComponentNames.loanPortfolio: () =>
            const CorpLiveLoanPortfolioWidget(),
        CorpComponentNames.loansOverview: () =>
            const CorpLiveLoansOverviewWidget(),

        // Term deposits, live: `td/v1/deposit`.
        CorpComponentNames.termDepositOverview: () =>
            const CorpLiveTdAccountsOverviewWidget(),
        CorpComponentNames.termDepositSummary: () =>
            const CorpLiveTdSummaryWidget(),

        // Cash management. The withdrawal summary is live
        // (`collections/CW`); the widgets capture shows no call behind the
        // other three, so they keep their sample figures and "Sample data"
        // tag.
        CorpComponentNames.cashWithdrawalSummary: () =>
            const CorpLiveCashWithdrawalSummaryWidget(),
        CorpComponentNames.cashFlowForecast: () =>
            const CorpCashFlowForecastWidget(),
        CorpComponentNames.cashFlowSnapshot: () =>
            const CorpCashFlowSnapshotWidget(),
        CorpComponentNames.cashflowSummary: () =>
            const CorpCashflowSummaryWidget(),
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
  ///
  /// Every Loans / TD / Cash Flow widget is responsive below its span —
  /// under 460px it switches to its mobile arrangement — so half width on a
  /// desktop and full width on a phone both render as designed.
  @override
  Map<String, DashboardWidgetSpec> get specs => const {
        CorpComponentNames.financialSummary: _half,
        CorpComponentNames.quickLinks: _half,
        CorpComponentNames.currencyExposure: _half,
        CorpComponentNames.pickupPointCollections: _half,
        CorpComponentNames.accountSummary: DashboardWidgetSpec(large: 12),
        CorpComponentNames.loanSummary: _half,
        CorpComponentNames.loanApplicationTracker: _half,
        CorpComponentNames.loanInstallmentsDue: _half,
        CorpComponentNames.loanPortfolio: _half,
        // An eight-column table, like Account Summary.
        CorpComponentNames.loansOverview: DashboardWidgetSpec(large: 12),
        CorpComponentNames.termDepositOverview: _half,
        // A chart beside a table.
        CorpComponentNames.termDepositSummary: DashboardWidgetSpec(large: 12),
        // A year of bars wants the whole width.
        CorpComponentNames.cashFlowForecast: DashboardWidgetSpec(large: 12),
        CorpComponentNames.cashFlowSnapshot: _half,
        CorpComponentNames.cashflowSummary: _half,
        CorpComponentNames.cashWithdrawalSummary: _half,
      };

  static const _half = DashboardWidgetSpec(large: 6, medium: 12);

  /// The accounts card, which always leads the Corporate dashboard and is
  /// not a catalog widget. It counts toward the widget limit.
  @override
  int get fixedTileCount => 1;
}
