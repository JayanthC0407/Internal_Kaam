import 'dart:math' as math;

import 'package:ubci_bank/src/core/models/corp/corp_loan_application.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_record.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';

/// The loans behind the four Loans widgets, and the figures each shows.
///
/// Figures are for [currency] only — the currency most of the loans are
/// in — because amounts in different currencies cannot be added up; loans
/// in any other currency are left out of the totals.
class CorpLoanBook {
  CorpLoanBook({required List<CorpLoanRecord> records, required this.today})
      : currency = _mainCurrency(records),
        _all = records;

  final List<CorpLoanRecord> _all;
  final DateTime today;
  final String? currency;

  List<CorpLoanRecord> get records => [
        for (final r in _all)
          if (currency == null || r.account.currencyCode == currency) r,
      ];

  bool get isEmpty => records.isEmpty;

  static String? _mainCurrency(List<CorpLoanRecord> records) {
    final counts = <String, int>{};
    for (final r in records) {
      final code = r.account.currencyCode.trim();
      if (code.isNotEmpty) counts.update(code, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  double get _outstanding => records.fold(0, (s, r) => s + r.outstanding);

  /// Sum of each loan's next instalment.
  double get _nextEmi => records.fold(
        0,
        (s, r) => s + (r.details?.nextInstallmentAmount?.amount ?? 0),
      );

  /// Outstanding-weighted rate over the loans that report one.
  double? get _rate {
    var weight = 0.0;
    var total = 0.0;
    for (final r in records) {
      final rate = r.details?.interestRate;
      if (rate == null) continue;
      // A loan with nothing outstanding still counts, a little.
      final w = math.max(r.outstanding, 1.0);
      weight += w;
      total += w * rate;
    }
    return weight == 0 ? null : total / weight;
  }

  CorpLoanSummaryData summary() {
    DateTime? last;
    for (final r in records) {
      final m = r.details?.maturityDate;
      if (m != null && (last == null || m.isAfter(last))) last = m;
    }
    return CorpLoanSummaryData(
      asOf: today,
      totalLoan: records.fold(0, (s, r) => s + r.financed),
      outstanding: _outstanding,
      nextEmi: _nextEmi,
      interestRate: _rate,
      remainingTenureMonths: last == null ? null : _monthsBetween(today, last),
    );
  }

  CorpLoanPortfolioData portfolio() {
    final byProduct = <String, double>{};
    for (final r in records) {
      final product = r.account.productName?.trim();
      byProduct.update(
        (product == null || product.isEmpty) ? 'Other' : product,
        (v) => v + r.outstanding,
        ifAbsent: () => r.outstanding,
      );
    }
    final total = _outstanding;
    final ranked = byProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Three slices and the rest, as the design's legend has room for.
    final shown = ranked.take(3).toList();
    final rest = ranked.skip(3).fold<double>(0, (s, e) => s + e.value);
    CorpLoanMixEntry entry(String label, double value) => CorpLoanMixEntry(
          label: label,
          shortLabel: label.split(' ').first,
          share: total <= 0 ? 0 : value / total * 100,
        );
    return CorpLoanPortfolioData(
      asOf: today,
      totalOutstanding: total,
      activeLoans: records.length,
      monthlyEmi: _nextEmi,
      weightedRate: _rate,
      nextReview: null,
      mix: [
        for (final e in shown) entry(e.key, e.value),
        if (rest > 0) entry('Other', rest),
      ],
    );
  }

  /// Instalments overdue, or due within [windowDays] of [today].
  List<CorpLoanInstallment> installments({
    int windowDays = CorpLoanSampleData.upcomingWindowDays,
    int dueSoonDays = 3,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    return [
      for (final r in records)
        if (r.details?.nextDueDate case final due?)
          if (r.details?.nextInstallmentAmount case final amount?)
            if (DateTime(due.year, due.month, due.day).difference(day).inDays
                case final days when days <= windowDays)
              CorpLoanInstallment(
                loanName: r.account.title,
                dueOn: due,
                amount: amount.amount,
                status: days < 0
                    ? CorpInstallmentStatus.overdue
                    : days <= dueSoonDays
                        ? CorpInstallmentStatus.dueSoon
                        : CorpInstallmentStatus.upcoming,
              ),
    ];
  }

  List<CorpLoanAccountRow> accountRows() => [
        for (final r in records)
          CorpLoanAccountRow(
            name: r.account.title,
            product: r.account.productName ?? 'Loan',
            party: r.account.holderName ?? '—',
            amountFinanced: r.financed,
            outstanding: r.outstanding,
            maturity: r.details?.maturityDate,
            rate: r.details?.interestRate,
            status: _statusLabel(r.account.status),
          ),
      ];

  static String _statusLabel(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return 'Active';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return math.max(0, to.day < from.day ? months - 1 : months);
  }
}

/// The steps the tracker draws, and how an application's status maps onto
/// them. The host's stage names are not known yet (see
/// [CorpLoanApplication]), so this matches on words; an unrecognised status
/// shows as the first step with the status written out.
class CorpLoanApplicationMapping {
  const CorpLoanApplicationMapping._();

  static const steps = [
    'Application submitted',
    'Documents verified',
    'Credit assessment',
    'Approval',
    'Disbursement',
  ];

  static int stepFor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('disburs')) return 4;
    if (s.contains('approv') || s.contains('sanction')) return 3;
    if (s.contains('assess') ||
        s.contains('credit') ||
        s.contains('underwrit') ||
        s.contains('review')) {
      return 2;
    }
    if (s.contains('document') || s.contains('verif')) return 1;
    return 0;
  }

  /// The most recent application, as the tracker shows one.
  static CorpLoanApplication? latest(List<CorpLoanApplication> apps) {
    if (apps.isEmpty) return null;
    return apps.reduce((a, b) {
      final x = a.submittedOn;
      final y = b.submittedOn;
      if (x == null) return b;
      if (y == null) return a;
      return y.isAfter(x) ? b : a;
    });
  }

  static CorpLoanApplicationData toData(CorpLoanApplication app) {
    final status = app.status ?? 'In progress';
    final step = stepFor(app.status);
    return CorpLoanApplicationData(
      applicationId: app.id,
      product: app.product ?? 'Loan application',
      requestedAmount: app.amount?.amount,
      status: status,
      shortStatus: status.split(' ').first,
      submittedOn: app.submittedOn,
      steps: steps,
      currentStep: step,
      nextAction: '${steps[step]} in progress',
      nextActionDetail: 'Current stage: $status',
    );
  }
}
