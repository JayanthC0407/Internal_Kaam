import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_live_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_application_tracker_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_installments_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_portfolio_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loans_overview_widget.dart';

/// The Loans widgets on live data — what the Corporate registry builds.
///
/// The four account widgets read one [corpLoanRecordsProvider] between
/// them, so a dashboard showing all four makes one set of loan calls.

AsyncValue<CorpLoanBook> _book(WidgetRef ref) => ref
    .watch(corpLoanRecordsProvider)
    .whenData((v) => CorpLoanBook(records: v.records, today: v.today));

void _retryLoans(WidgetRef ref) => ref.invalidate(corpLoanRecordsProvider);

const _noLoans = 'You have no loan or finance accounts.';

/// OBDX `loan-summary`, live.
class CorpLiveLoanSummaryWidget extends ConsumerWidget {
  const CorpLiveLoanSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget<CorpLoanBook>(
      title: 'Loan Summary',
      value: _book(ref),
      onRetry: () => _retryLoans(ref),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noLoans,
      currencyOf: (book) => book.currency,
      builder: (book) => CorpLoanSummaryWidget(data: book.summary()),
    );
  }
}

/// OBDX `loan-portfolio`, live.
class CorpLiveLoanPortfolioWidget extends ConsumerWidget {
  const CorpLiveLoanPortfolioWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget<CorpLoanBook>(
      title: 'Loan Portfolio',
      value: _book(ref),
      onRetry: () => _retryLoans(ref),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noLoans,
      currencyOf: (book) => book.currency,
      builder: (book) => CorpLoanPortfolioWidget(data: book.portfolio()),
    );
  }
}

/// OBDX `loan-installments-due`, live. Loans with nothing due soon still
/// show the widget, with its own "nothing due" message.
class CorpLiveLoanInstallmentsWidget extends ConsumerWidget {
  const CorpLiveLoanInstallmentsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget<CorpLoanBook>(
      title: 'Installments Due',
      value: _book(ref),
      onRetry: () => _retryLoans(ref),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noLoans,
      currencyOf: (book) => book.currency,
      builder: (book) =>
          CorpLoanInstallmentsWidget(installments: book.installments()),
    );
  }
}

/// OBDX `loans-overview` (the design's Loan and Finance Summary), live.
class CorpLiveLoansOverviewWidget extends ConsumerWidget {
  const CorpLiveLoansOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget<CorpLoanBook>(
      title: 'Loan and Finance Summary',
      value: _book(ref),
      onRetry: () => _retryLoans(ref),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noLoans,
      currencyOf: (book) => book.currency,
      builder: (book) => CorpLoansOverviewWidget(accounts: book.accountRows()),
    );
  }
}

/// OBDX `loan-application-tracker`, live: the most recent application.
class CorpLiveLoanApplicationTrackerWidget extends ConsumerWidget {
  const CorpLiveLoanApplicationTrackerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget(
      title: 'Loan Application Tracker',
      value: ref.watch(corpLoanApplicationsProvider),
      onRetry: () => ref.invalidate(corpLoanApplicationsProvider),
      isEmpty: (apps) => apps.isEmpty,
      emptyMessage: 'You have no loan applications in progress.',
      emptyIcon: Icons.assignment_outlined,
      currencyOf: (apps) =>
          CorpLoanApplicationMapping.latest(apps)?.amount?.currency,
      builder: (apps) => CorpLoanApplicationTrackerWidget(
        data: CorpLoanApplicationMapping.toData(
          CorpLoanApplicationMapping.latest(apps)!,
        ),
      ),
    );
  }
}
