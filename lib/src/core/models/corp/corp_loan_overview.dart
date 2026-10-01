import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';

/// Where an installment sits relative to today.
enum CorpInstallmentStatus {
  /// Past its due date and still outstanding.
  overdue,

  /// Due within [CorpLoanOverview.dueSoonDays].
  dueSoon,

  /// Due later.
  upcoming;

  bool get isOverdue => this == CorpInstallmentStatus.overdue;
}

/// One row of the `Installments Due` widget.
class CorpInstallmentDue {
  const CorpInstallmentDue({
    required this.account,
    required this.dueDate,
    required this.status,
    this.amount,
  });

  final CorpAccount account;
  final DateTime dueDate;
  final CorpInstallmentStatus status;
  final MoneyAmount? amount;

  /// Loan name as the design labels the row ("Home Finance Loan").
  String get label => account.accountTypeLabel;
}

/// One slice of the `Loan Portfolio` donut.
class CorpLoanMixSlice {
  const CorpLoanMixSlice({
    required this.label,
    required this.amount,
    required this.share,
    required this.count,
  });

  /// Product description the loans were grouped by.
  final String label;

  /// Outstanding across the loans in this slice.
  final double amount;

  /// Share of the portfolio, 0..1.
  final double share;

  final int count;
}

/// Everything the three loan widgets show, derived from the loan list
/// returned by `GET /digx-common/loan/v1/loan`.
///
/// One model rather than three because all three widgets read the same
/// list and would otherwise each re-derive the same totals: Loan Summary
/// takes the headline figures and the repayment gauge, Installments Due
/// takes [installments], Loan Portfolio takes [mix].
///
/// As with the deposit overview, a figure the host did not send stays null
/// rather than becoming zero — the widgets render "—" for it.
class CorpLoanOverview {
  const CorpLoanOverview({
    required this.loans,
    required this.activeCount,
    required this.installments,
    required this.mix,
    this.totalOutstanding,
    this.totalFinanced,
    this.totalRepaid,
    this.monthlyInstallment,
    this.weightedRate,
    this.nextInstallment,
    this.remainingInstallments,
  });

  static const empty = CorpLoanOverview(
    loans: <CorpAccount>[],
    activeCount: 0,
    installments: <CorpInstallmentDue>[],
    mix: <CorpLoanMixSlice>[],
  );

  /// An installment falling due within this many days reads as "Due soon"
  /// rather than "Upcoming" — the design's amber-vs-green distinction.
  static const int dueSoonDays = 7;

  final List<CorpAccount> loans;
  final int activeCount;

  /// Installments across all loans, overdue first then soonest, from each
  /// loan's `nextInstallmentDate`. One row per loan: the list endpoint
  /// carries only the *next* installment, so a full schedule would need a
  /// per-loan `loan/{id}/schedule` call the dashboard does not make.
  final List<CorpInstallmentDue> installments;

  /// Portfolio split by product, largest share first.
  final List<CorpLoanMixSlice> mix;

  /// "Total outstanding" / "Outstanding".
  final MoneyAmount? totalOutstanding;

  /// Originally sanctioned across all loans — the gauge's denominator.
  final MoneyAmount? totalFinanced;

  /// [totalFinanced] less [totalOutstanding], floored at zero.
  final MoneyAmount? totalRepaid;

  /// "Monthly EMI" — the scheduled repayments summed.
  final MoneyAmount? monthlyInstallment;

  /// Outstanding-weighted mean interest rate.
  final double? weightedRate;

  /// The most pressing installment: the oldest overdue one if any loan has
  /// missed a payment, otherwise the soonest upcoming one. This is what the
  /// widgets lead with — see [nextUpcomingInstallment] for the strictly
  /// forward-looking one.
  final CorpInstallmentDue? nextInstallment;

  /// Remaining tenure summed across loans, when the host reports it.
  final int? remainingInstallments;

  bool get isEmpty => loans.isEmpty;

  /// Installments not yet past due.
  List<CorpInstallmentDue> get upcomingInstallments => installments
      .where((installment) => !installment.status.isOverdue)
      .toList(growable: false);

  List<CorpInstallmentDue> get overdueInstallments => installments
      .where((installment) => installment.status.isOverdue)
      .toList(growable: false);

  /// The next installment still ahead of today.
  ///
  /// Distinct from [nextInstallment], which leads with an overdue payment
  /// when there is one: "Next EMI" on Loan Summary means the next amount
  /// that will be taken, so a missed payment must not answer it.
  CorpInstallmentDue? get nextUpcomingInstallment {
    final upcoming = upcomingInstallments;
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Share of the portfolio repaid, 0..1 — the Loan Summary gauge. Null
  /// unless the host sent the sanctioned amounts.
  double? get repaidFraction {
    final financed = totalFinanced?.amount;
    final repaid = totalRepaid?.amount;
    if (financed == null || repaid == null || financed <= 0) return null;
    return (repaid / financed).clamp(0.0, 1.0);
  }

  /// Total of [list]'s amounts, for the "Total due" tile.
  static MoneyAmount? totalOf(List<CorpInstallmentDue> list) =>
      _sumInSingleCurrency(list.map((installment) => installment.amount));

  factory CorpLoanOverview.fromAccounts(
    List<CorpAccount> accounts, {
    DateTime? now,
  }) {
    if (accounts.isEmpty) return empty;

    final today = _startOfDay(now ?? DateTime.now());

    var hasStatus = false;
    var activeCount = 0;
    for (final account in accounts) {
      if (account.status.trim().isNotEmpty) hasStatus = true;
      if (account.isActive) activeCount++;
    }

    final outstanding = _sumInSingleCurrency(
      accounts.map((account) => account.outstandingBalance),
    );
    final financed = _sumInSingleCurrency(
      accounts.map((account) => account.amountFinanced),
    );

    MoneyAmount? repaid;
    if (financed != null && outstanding != null) {
      final value = financed.amount - outstanding.amount;
      repaid = MoneyAmount(
        amount: value < 0 ? 0 : value,
        currency: financed.currency ?? outstanding.currency,
      );
    }

    final installments = _installmentsFrom(accounts, today);

    var remaining = 0;
    var hasRemaining = false;
    for (final account in accounts) {
      final value = account.remainingInstallments;
      if (value == null) continue;
      hasRemaining = true;
      remaining += value;
    }

    return CorpLoanOverview(
      loans: accounts,
      activeCount: hasStatus ? activeCount : accounts.length,
      installments: installments,
      mix: _mixFrom(accounts),
      totalOutstanding: outstanding,
      totalFinanced: financed,
      totalRepaid: repaid,
      monthlyInstallment: _sumInSingleCurrency(
        accounts.map((account) => account.installmentAmount),
      ),
      weightedRate: _weightedRate(accounts),
      nextInstallment: installments.isEmpty ? null : installments.first,
      remainingInstallments: hasRemaining ? remaining : null,
    );
  }

  /// One row per loan that reports a next-installment date, ordered overdue
  /// first (oldest overdue at the top) then by soonest due date.
  static List<CorpInstallmentDue> _installmentsFrom(
    List<CorpAccount> accounts,
    DateTime today,
  ) {
    final dueSoonCutoff = today.add(const Duration(days: dueSoonDays));
    final rows = <CorpInstallmentDue>[];

    for (final account in accounts) {
      final dueDate = account.nextInstallmentDateTime;
      if (dueDate == null) continue;

      final status = dueDate.isBefore(today)
          ? CorpInstallmentStatus.overdue
          : dueDate.isAfter(dueSoonCutoff)
              ? CorpInstallmentStatus.upcoming
              : CorpInstallmentStatus.dueSoon;

      rows.add(
        CorpInstallmentDue(
          account: account,
          dueDate: dueDate,
          status: status,
          amount: account.installmentAmount,
        ),
      );
    }

    rows.sort((a, b) {
      final aOverdue = a.status.isOverdue;
      if (aOverdue != b.status.isOverdue) return aOverdue ? -1 : 1;
      return a.dueDate.compareTo(b.dueDate);
    });

    return List.unmodifiable(rows);
  }

  /// Groups loans by product description and turns each group into a slice.
  /// Loans with no outstanding balance are skipped — a zero slice would
  /// draw nothing but would still take a legend row.
  static List<CorpLoanMixSlice> _mixFrom(List<CorpAccount> accounts) {
    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final account in accounts) {
      final amount = account.outstandingBalance?.amount ?? 0;
      if (amount <= 0) continue;
      final label = account.accountTypeLabel;
      final key = (label.isEmpty || label == '—') ? 'Other' : label;
      totals[key] = (totals[key] ?? 0) + amount;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final grandTotal = totals.values.fold<double>(0, (sum, value) => sum + value);
    if (grandTotal <= 0) return const <CorpLoanMixSlice>[];

    final slices = totals.entries
        .map(
          (entry) => CorpLoanMixSlice(
            label: entry.key,
            amount: entry.value,
            share: entry.value / grandTotal,
            count: counts[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return List.unmodifiable(slices);
  }

  /// Outstanding-weighted mean rate — see the deposit overview's equivalent.
  static double? _weightedRate(List<CorpAccount> accounts) {
    var weightedSum = 0.0;
    var weightTotal = 0.0;

    for (final account in accounts) {
      final rate = account.interestRate;
      if (rate == null) continue;
      final outstanding = account.outstandingBalance?.amount;
      final weight = (outstanding == null || outstanding <= 0) ? 1.0 : outstanding;
      weightedSum += rate * weight;
      weightTotal += weight;
    }

    if (weightTotal == 0) return null;
    return weightedSum / weightTotal;
  }

  static MoneyAmount? _sumInSingleCurrency(Iterable<MoneyAmount?> amounts) {
    String? currency;
    var total = 0.0;
    var seen = false;

    for (final amount in amounts) {
      if (amount == null) continue;
      final code = amount.currency?.trim().toUpperCase();
      if (code != null && code.isNotEmpty) {
        if (currency == null) {
          currency = code;
        } else if (currency != code) {
          return null;
        }
      }
      total += amount.amount;
      seen = true;
    }

    if (!seen) return null;
    return MoneyAmount(amount: total, currency: currency);
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
