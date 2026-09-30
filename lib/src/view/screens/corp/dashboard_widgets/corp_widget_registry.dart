import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_currency_exposure_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_financial_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_installments_due_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_loan_portfolio_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_loan_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_pickup_points_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_term_deposit_overview_widget.dart';
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

  // ── Designed, not yet built — the endpoints behind these are not in
  // the app. Named here so the next pass has the catalog names to hand,
  // and so nothing guesses them a second time.
  //
  //   loan-application-tracker    loans            large 6  h 220
  //   cash-flow-forecast-widget   cash-management  large 12 h 220
  //   cash-flow-snapshot          cash-management  large 12 h 220
  //   cash-flow-summary           cash-management  large 12 h 220
  //   cash-withdrawal-summary     cash-management  large 4  h 220
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
        CorpComponentNames.termDepositOverview: () =>
            const CorpTermDepositOverviewWidget(),
        CorpComponentNames.loanSummary: () => const CorpLoanSummaryWidget(),
        CorpComponentNames.loanInstallmentsDue: () =>
            const CorpInstallmentsDueWidget(),
        CorpComponentNames.loanPortfolio: () => const CorpLoanPortfolioWidget(),
      };

  /// Sizes — half the row, the two-column arrangement both dashboards use
  /// (see [DashboardGridLayout.twoColumns]); saving 6 gives the web client
  /// two columns too.
  ///
  /// Account Summary is the exception: a multi-column table, too cramped
  /// at half width, so it spans both columns. Pickup Points has no catalog
  /// entry at all, so the app's sizes are authoritative here.
  ///
  /// The four Term Deposit / Loan widgets take the host catalog's own
  /// widths and heights instead, so a layout saved from this app opens at
  /// the same size in the web client: Installments Due is `large 8` there,
  /// the other three `large 4`. Their bodies (a maturity strip, a gauge, a
  /// donut) need the catalog height as a floor, which is why they are the
  /// only specs here carrying a `minHeight`.
  ///
  /// Each widget is responsive below its span — under roughly 520px it
  /// switches to the mobile arrangement — so `large 4` on a wide desktop
  /// and full width on a phone both render correctly.
  @override
  Map<String, DashboardWidgetSpec> get specs => const {
        CorpComponentNames.financialSummary: _half,
        CorpComponentNames.quickLinks: _half,
        CorpComponentNames.currencyExposure: _half,
        CorpComponentNames.pickupPointCollections: _half,
        CorpComponentNames.accountSummary: DashboardWidgetSpec(large: 12),
        CorpComponentNames.termDepositOverview:
            DashboardWidgetSpec(large: 4, medium: 12, minHeight: 320),
        CorpComponentNames.loanSummary:
            DashboardWidgetSpec(large: 4, medium: 6, minHeight: 251),
        CorpComponentNames.loanInstallmentsDue:
            DashboardWidgetSpec(large: 8, medium: 6, minHeight: 289),
        CorpComponentNames.loanPortfolio:
            DashboardWidgetSpec(large: 4, medium: 6, minHeight: 251),
      };

  static const _half = DashboardWidgetSpec(large: 6, medium: 12);
}
