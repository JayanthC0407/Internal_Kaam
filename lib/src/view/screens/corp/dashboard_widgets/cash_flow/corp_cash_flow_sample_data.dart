import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The figures the Cash Flow widget designs show, as data.
///
/// No endpoint backs these widgets yet, so they draw from here and wear a
/// "Sample data" tag. Live data replaces these objects; the widgets stay.
@immutable
class CorpCashFlowSampleData {
  const CorpCashFlowSampleData._();

  static const currencySymbol = '£';

  /// The design's "Mar 2026 – Feb 2027 • GBP" forecast.
  static final forecast = CorpCashFlowSeries.fromMonthlyTotals(
    start: DateTime(2026, 3),
    openingBalance: 620e6,
    // Read off the design's bars, scaled to its £8.42B / £6.73B totals.
    monthlyInflow: const [
      0.62e9, 0.40e9, 0.71e9, 0.47e9, 0.66e9, 0.56e9, //
      0.87e9, 0.36e9, 0.62e9, 1.90e9, 0.67e9, 0.58e9,
    ],
    monthlyOutflow: const [
      0.606e9, 0.448e9, 0.630e9, 0.727e9, 0.509e9, 0.606e9, //
      0.751e9, 0.521e9, 0.666e9, 0.130e9, 0.606e9, 0.530e9,
    ],
    // The year before, for "vs previous period": the design's +8.4% on
    // inflow and +12.1% on net, which make outflow +7.5%.
    previousInflowFactor: 1 / 1.084,
    previousOutflowFactor: 1 / 1.075,
  );

  static final today = CorpCashFlowDay(
    date: DateTime(2026, 9, 24),
    inflow: 128400,
    outflow: 86700,
    inflowCount: 28,
    outflowCount: 19,
    pendingCount: 3,
  );

  static final month = CorpCashFlowMonth(
    month: DateTime(2026, 9),
    openingBalance: 380000,
    inflow: 1240000,
    outflow: 980000,
    inflowCount: 186,
    outflowCount: 142,
    pendingCount: 3,
  );

  static final withdrawals = CorpCashWithdrawals(
    month: DateTime(2026, 9),
    transactions: 32,
    largest: 42500,
    availableLimit: 754200,
    byChannel: const [
      CorpWithdrawalChannel(label: 'ATM', amount: 96400),
      CorpWithdrawalChannel(label: 'Branch', amount: 149600),
      // Net of a reversal, as in the design.
      CorpWithdrawalChannel(label: 'Other', amount: -200),
    ],
  );
}

/// How the forecast groups its days.
enum CorpCashFlowGrouping { quarterly, monthly, weekly, daily }

/// A daily inflow / outflow forecast over [start]–[end], plus the same
/// span a year earlier for comparisons.
///
/// Held by day so that every grouping and range the Cash Flow Forecast
/// offers is an aggregation of one series, and the figures always agree.
@immutable
class CorpCashFlowSeries {
  const CorpCashFlowSeries._({
    required this.start,
    required this.end,
    required this.openingBalance,
    required List<double> inflow,
    required List<double> outflow,
    required List<double> previousInflow,
    required List<double> previousOutflow,
  })  : _inflow = inflow,
        _outflow = outflow,
        _previousInflow = previousInflow,
        _previousOutflow = previousOutflow;

  /// Spreads each month's total over its days — unevenly, so days and
  /// weeks differ as real ones would, but always summing to the month.
  factory CorpCashFlowSeries.fromMonthlyTotals({
    required DateTime start,
    required double openingBalance,
    required List<double> monthlyInflow,
    required List<double> monthlyOutflow,
    required double previousInflowFactor,
    required double previousOutflowFactor,
  }) {
    final inflow = <double>[];
    final outflow = <double>[];
    for (var m = 0; m < monthlyInflow.length; m++) {
      final first = DateTime(start.year, start.month + m);
      final days = DateTime(first.year, first.month + 1, 0).day;
      inflow.addAll(_spread(monthlyInflow[m], days, m));
      outflow.addAll(_spread(monthlyOutflow[m], days, m + 7));
    }
    final end = DateTime(start.year, start.month + monthlyInflow.length, 0);
    return CorpCashFlowSeries._(
      start: start,
      end: end,
      openingBalance: openingBalance,
      inflow: inflow,
      outflow: outflow,
      previousInflow: [for (final v in inflow) v * previousInflowFactor],
      previousOutflow: [for (final v in outflow) v * previousOutflowFactor],
    );
  }

  static List<double> _spread(double total, int days, int seed) {
    final weights = [
      for (var d = 0; d < days; d++)
        1 +
            0.45 * math.sin(d * 1.7 + seed) +
            0.3 * math.cos(d * 0.9 + seed * 2),
    ];
    final sum = weights.fold<double>(0, (s, w) => s + w);
    return [for (final w in weights) total * w / sum];
  }

  final DateTime start;
  final DateTime end;
  final double openingBalance;
  final List<double> _inflow;
  final List<double> _outflow;
  final List<double> _previousInflow;
  final List<double> _previousOutflow;

  int _index(DateTime day) => DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;

  /// [from]–[to] (inclusive) clamped to the forecast.
  (int, int) _span(DateTime from, DateTime to) {
    final a = _index(from).clamp(0, _inflow.length - 1).toInt();
    final b = _index(to).clamp(0, _inflow.length - 1).toInt();
    return (a, math.max(a, b));
  }

  static double _sum(List<double> values, int a, int b) {
    var total = 0.0;
    for (var i = a; i <= b; i++) {
      total += values[i];
    }
    return total;
  }

  CorpCashFlowTotals totals(DateTime from, DateTime to) {
    final (a, b) = _span(from, to);
    // The same days a year earlier.
    return CorpCashFlowTotals(
      inflow: _sum(_inflow, a, b),
      outflow: _sum(_outflow, a, b),
      previousInflow: _sum(_previousInflow, a, b),
      previousOutflow: _sum(_previousOutflow, a, b),
    );
  }

  /// The lowest end-of-day balance over [from]–[to], and when.
  (double, DateTime) lowestBalance(DateTime from, DateTime to) {
    final (a, b) = _span(from, to);
    var balance =
        openingBalance + _sum(_inflow, 0, a - 1) - _sum(_outflow, 0, a - 1);
    var lowest = double.infinity;
    var when = from;
    for (var i = a; i <= b; i++) {
      balance += _inflow[i] - _outflow[i];
      if (balance < lowest) {
        lowest = balance;
        when = DateTime(start.year, start.month, start.day + i);
      }
    }
    return (lowest, when);
  }

  /// [from]–[to] grouped by [grouping]: calendar quarters of three months
  /// and calendar months from [from]; weeks of seven days from [from].
  List<CorpCashFlowBucket> buckets(
    DateTime from,
    DateTime to,
    CorpCashFlowGrouping grouping,
  ) {
    final (a, b) = _span(from, to);
    final first = DateTime(start.year, start.month, start.day + a);
    final result = <CorpCashFlowBucket>[];
    var i = a;
    var n = 0;
    while (i <= b) {
      final day = DateTime(start.year, start.month, start.day + i);
      final DateTime next = switch (grouping) {
        CorpCashFlowGrouping.daily =>
          DateTime(day.year, day.month, day.day + 1),
        CorpCashFlowGrouping.weekly =>
          DateTime(day.year, day.month, day.day + 7),
        CorpCashFlowGrouping.monthly => DateTime(day.year, day.month + 1),
        CorpCashFlowGrouping.quarterly =>
          DateTime(first.year, first.month + 3 * (n + 1)),
      };
      final last = math.min(b, _index(next) - 1);
      result.add(
        CorpCashFlowBucket(
          start: day,
          end: DateTime(start.year, start.month, start.day + last),
          grouping: grouping,
          inflow: _sum(_inflow, i, last),
          outflow: _sum(_outflow, i, last),
        ),
      );
      i = last + 1;
      n++;
    }
    return result;
  }
}

@immutable
class CorpCashFlowTotals {
  const CorpCashFlowTotals({
    required this.inflow,
    required this.outflow,
    required this.previousInflow,
    required this.previousOutflow,
  });

  final double inflow;
  final double outflow;
  final double previousInflow;
  final double previousOutflow;

  double get net => inflow - outflow;
  double get previousNet => previousInflow - previousOutflow;

  /// Percent change on the previous period; null with nothing to compare.
  static double? change(double now, double before) =>
      before == 0 ? null : (now - before) / before.abs() * 100;
}

@immutable
class CorpCashFlowBucket {
  const CorpCashFlowBucket({
    required this.start,
    required this.end,
    required this.grouping,
    required this.inflow,
    required this.outflow,
  });

  final DateTime start;
  final DateTime end;
  final CorpCashFlowGrouping grouping;
  final double inflow;
  final double outflow;

  double get net => inflow - outflow;
}

@immutable
class CorpCashFlowDay {
  const CorpCashFlowDay({
    required this.date,
    required this.inflow,
    required this.outflow,
    required this.inflowCount,
    required this.outflowCount,
    required this.pendingCount,
  });

  final DateTime date;
  final double inflow;
  final double outflow;
  final int inflowCount;
  final int outflowCount;
  final int pendingCount;

  double get net => inflow - outflow;
}

@immutable
class CorpCashFlowMonth {
  const CorpCashFlowMonth({
    required this.month,
    required this.openingBalance,
    required this.inflow,
    required this.outflow,
    required this.inflowCount,
    required this.outflowCount,
    required this.pendingCount,
  });

  final DateTime month;
  final double openingBalance;
  final double inflow;
  final double outflow;
  final int inflowCount;
  final int outflowCount;
  final int pendingCount;

  double get net => inflow - outflow;
  double get closingBalance => openingBalance + net;
}

@immutable
class CorpCashWithdrawals {
  const CorpCashWithdrawals({
    required this.month,
    required this.transactions,
    required this.largest,
    required this.availableLimit,
    required this.byChannel,
  });

  final DateTime month;

  /// Null where the host reports amounts but not how many.
  final int? transactions;
  final double? largest;

  /// Null where the host does not report a limit.
  final double? availableLimit;
  final List<CorpWithdrawalChannel> byChannel;

  double get total => byChannel.fold<double>(0, (s, c) => s + c.amount);
}

@immutable
class CorpWithdrawalChannel {
  const CorpWithdrawalChannel({required this.label, required this.amount});

  final String label;
  final double amount;
}
