import 'package:flutter/foundation.dart';

/// The figures the Loans widget designs show, as data.
///
/// No endpoint backs these widgets yet, so they draw from here, and each
/// wears a "Sample data" tag. Keeping the figures in one place, typed, is
/// what lets live data replace them later without touching the widgets:
/// a provider that returns these same classes from the OBDX loan APIs is
/// the whole change.
///
/// Amounts are in GBP, the designs' currency; live figures carry their own
/// (see `CorpCurrency`).
@immutable
class CorpLoanSampleData {
  const CorpLoanSampleData._();

  static const currencySymbol = '£';

  static final summary = CorpLoanSummaryData(
    asOf: DateTime(2026, 9, 24),
    totalLoan: 1200000,
    outstanding: 824000,
    nextEmi: 12800,
    interestRate: 7.25,
    remainingTenureMonths: 56,
  );

  static final application = CorpLoanApplicationData(
    applicationId: 'LF-2026-0842',
    product: 'Personal Loan',
    requestedAmount: 50000,
    status: 'Credit assessment',
    shortStatus: 'Assessment',
    submittedOn: DateTime(2026, 9, 18),
    steps: const [
      'Application submitted',
      'Documents verified',
      'Credit assessment',
      'Approval',
      'Disbursement',
    ],
    // Steps 1 and 2 done; 3 in progress.
    currentStep: 2,
    nextAction: 'Credit assessment in progress',
    nextActionDetail: 'Estimated decision within 2 business days',
  );

  static final installments = [
    CorpLoanInstallment(
      loanName: 'Home Finance Loan',
      dueOn: DateTime(2026, 9, 28),
      amount: 12800,
      status: CorpInstallmentStatus.dueSoon,
    ),
    CorpLoanInstallment(
      loanName: 'Personal Loan',
      dueOn: DateTime(2026, 10, 2),
      amount: 9600,
      status: CorpInstallmentStatus.upcoming,
    ),
    CorpLoanInstallment(
      loanName: 'Auto Finance',
      dueOn: DateTime(2026, 10, 4),
      amount: 16000,
      status: CorpInstallmentStatus.upcoming,
    ),
    CorpLoanInstallment(
      loanName: 'Working Capital',
      dueOn: DateTime(2026, 9, 15),
      amount: 7400,
      status: CorpInstallmentStatus.overdue,
    ),
  ];

  /// The window the Upcoming list covers.
  static const upcomingWindowDays = 10;

  static final portfolio = CorpLoanPortfolioData(
    asOf: DateTime(2026, 9, 24),
    totalOutstanding: 1240000,
    activeLoans: 5,
    monthlyEmi: 26400,
    weightedRate: 7.1,
    nextReview: DateTime(2026, 9, 30),
    mix: const [
      CorpLoanMixEntry(label: 'Home finance', shortLabel: 'Home', share: 61),
      CorpLoanMixEntry(
        label: 'Personal finance',
        shortLabel: 'Personal',
        share: 35,
      ),
      CorpLoanMixEntry(label: 'Auto finance', shortLabel: 'Auto', share: 4),
    ],
  );

  static final accounts = [
    CorpLoanAccountRow(
      name: 'Home Finance 01',
      product: 'Home Finance',
      party: 'ACME Ltd',
      amountFinanced: 500000,
      outstanding: 312000,
      maturity: DateTime(2026, 9, 28),
      rate: 7.20,
    ),
    CorpLoanAccountRow(
      name: 'Working Capital',
      product: 'Working Capital',
      party: 'Northstar Co.',
      amountFinanced: 420000,
      outstanding: 284000,
      maturity: DateTime(2026, 11, 14),
      rate: 7.60,
    ),
    CorpLoanAccountRow(
      name: 'Auto Finance',
      product: 'Auto Finance',
      party: 'Riverview LLP',
      amountFinanced: 180000,
      outstanding: 95000,
      maturity: DateTime(2027, 2, 2),
      rate: 8.10,
    ),
    CorpLoanAccountRow(
      name: 'Term Loan',
      product: 'Term Loan',
      party: 'Greenfield Ltd',
      amountFinanced: 520000,
      outstanding: 415000,
      maturity: DateTime(2027, 6, 30),
      rate: 7.35,
    ),
    CorpLoanAccountRow(
      name: 'Equipment Finance',
      product: 'Equipment Finance',
      party: 'ACME Ltd',
      amountFinanced: 200000,
      outstanding: 134000,
      maturity: DateTime(2027, 9, 12),
      rate: 7.90,
    ),
  ];
}

@immutable
class CorpLoanSummaryData {
  const CorpLoanSummaryData({
    required this.asOf,
    required this.totalLoan,
    required this.outstanding,
    required this.nextEmi,
    required this.interestRate,
    required this.remainingTenureMonths,
  });

  final DateTime asOf;
  final double totalLoan;
  final double outstanding;
  final double nextEmi;

  /// Null when the host gives no rate.
  final double? interestRate;

  /// Null when no maturity date is known.
  final int? remainingTenureMonths;

  double get paid => totalLoan - outstanding;

  /// Share of the loan still to repay, 0–1 — what the gauge fills to.
  double get outstandingShare => totalLoan <= 0 ? 0 : outstanding / totalLoan;
}

@immutable
class CorpLoanApplicationData {
  const CorpLoanApplicationData({
    required this.applicationId,
    required this.product,
    required this.requestedAmount,
    required this.status,
    required this.shortStatus,
    required this.submittedOn,
    required this.steps,
    required this.currentStep,
    required this.nextAction,
    required this.nextActionDetail,
  });

  final String applicationId;
  final String product;

  /// Null when the host does not report an amount.
  final double? requestedAmount;
  final String status;

  /// [status] in a word, for the phone layout's narrow tile.
  final String shortStatus;
  final DateTime? submittedOn;
  final List<String> steps;

  /// Index into [steps] of the step in progress; earlier ones are done.
  final int currentStep;
  final String nextAction;
  final String nextActionDetail;
}

enum CorpInstallmentStatus { dueSoon, upcoming, overdue }

@immutable
class CorpLoanInstallment {
  const CorpLoanInstallment({
    required this.loanName,
    required this.dueOn,
    required this.amount,
    required this.status,
  });

  final String loanName;
  final DateTime dueOn;
  final double amount;
  final CorpInstallmentStatus status;

  bool get isOverdue => status == CorpInstallmentStatus.overdue;
}

@immutable
class CorpLoanPortfolioData {
  const CorpLoanPortfolioData({
    required this.asOf,
    required this.totalOutstanding,
    required this.activeLoans,
    required this.monthlyEmi,
    required this.weightedRate,
    required this.nextReview,
    required this.mix,
  });

  final DateTime asOf;
  final double totalOutstanding;
  final int activeLoans;
  final double monthlyEmi;

  /// Null when no loan carries a rate.
  final double? weightedRate;

  /// Null when the host has no review date to give.
  final DateTime? nextReview;
  final List<CorpLoanMixEntry> mix;
}

@immutable
class CorpLoanMixEntry {
  const CorpLoanMixEntry({
    required this.label,
    required this.shortLabel,
    required this.share,
  });

  final String label;
  final String shortLabel;

  /// Percent of the portfolio.
  final double share;
}

@immutable
class CorpLoanAccountRow {
  const CorpLoanAccountRow({
    required this.name,
    required this.product,
    required this.party,
    required this.amountFinanced,
    required this.outstanding,
    required this.maturity,
    required this.rate,
    this.status = 'Active',
  });

  final String name;
  final String product;
  final String party;
  final double amountFinanced;
  final double outstanding;

  /// Null when the loan's details did not load.
  final DateTime? maturity;
  final double? rate;
  final String status;

  /// Share of the amount financed that is repaid, 0–1.
  double get repaidShare =>
      amountFinanced <= 0 ? 0 : 1 - outstanding / amountFinanced;
}
