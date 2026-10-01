import 'package:flutter/foundation.dart';

/// The term deposits the TD widget designs show, as data.
///
/// No endpoint backs these widgets yet, so they draw from here and wear a
/// "Sample data" tag. Both TD widgets read the same list, and every figure
/// they show — balance, average rate, next maturity — is worked out from
/// it, so the two always agree. (The designs' own figures did not: 8
/// deposits worth £680K on one, 3 worth £395K on the other.)
///
/// Live data replaces [deposits]; the widgets stay as they are.
@immutable
class CorpTdSampleData {
  const CorpTdSampleData._();

  static const currencySymbol = '£';

  static final asOf = DateTime(2026, 9, 24);

  /// Interest credited so far this year — not derivable from the deposits'
  /// maturity values, which are what they will pay out at the end.
  static const interestEarned = 90000.0;

  static final deposits = [
    CorpTermDeposit(
      id: 'TD-1001',
      principal: 120000,
      rate: 6.75,
      maturesOn: DateTime(2026, 10, 15),
      maturityValue: 128100,
    ),
    CorpTermDeposit(
      id: 'TD-1002',
      principal: 85000,
      rate: 6.85,
      maturesOn: DateTime(2026, 11, 3),
      maturityValue: 90200,
    ),
    CorpTermDeposit(
      id: 'TD-1003',
      principal: 190000,
      rate: 6.90,
      maturesOn: DateTime(2026, 11, 21),
      maturityValue: 203100,
    ),
    CorpTermDeposit(
      id: 'TD-1004',
      principal: 75000,
      rate: 6.80,
      maturesOn: DateTime(2026, 12, 10),
      maturityValue: 77400,
    ),
    CorpTermDeposit(
      id: 'TD-1005',
      principal: 60000,
      rate: 6.95,
      maturesOn: DateTime(2027, 1, 18),
      maturityValue: 61400,
    ),
    CorpTermDeposit(
      id: 'TD-1006',
      principal: 50000,
      rate: 7.00,
      maturesOn: DateTime(2027, 2, 22),
      maturityValue: 51400,
    ),
    CorpTermDeposit(
      id: 'TD-1007',
      principal: 55000,
      rate: 6.90,
      maturesOn: DateTime(2027, 4, 15),
      maturityValue: 55900,
    ),
    CorpTermDeposit(
      id: 'TD-1008',
      principal: 45000,
      rate: 6.70,
      maturesOn: DateTime(2027, 6, 30),
      maturityValue: 45500,
    ),
  ];
}

@immutable
class CorpTermDeposit {
  const CorpTermDeposit({
    required this.id,
    required this.principal,
    required this.rate,
    required this.maturesOn,
    required this.maturityValue,
    this.status = 'Active',
  });

  final String id;
  final double principal;

  /// Annual rate, percent; null when the host does not give one.
  final double? rate;

  /// Null for a deposit with no fixed maturity on record.
  final DateTime? maturesOn;

  /// Principal plus interest, paid at maturity.
  final double maturityValue;
  final String status;

  double get interest => maturityValue - principal;
}

/// Figures across a set of deposits — what both TD widgets headline.
@immutable
class CorpTdTotals {
  const CorpTdTotals._({
    required this.balance,
    required this.maturityValue,
    required this.averageRate,
    required this.count,
    required this.nextMaturity,
  });

  factory CorpTdTotals.of(List<CorpTermDeposit> deposits) {
    final balance = deposits.fold<double>(0, (s, d) => s + d.principal);
    // Only deposits with a rate count towards the average.
    var rated = 0.0;
    var weighted = 0.0;
    DateTime? next;
    for (final d in deposits) {
      if (d.rate != null) {
        rated += d.principal;
        weighted += d.principal * d.rate!;
      }
      final on = d.maturesOn;
      if (on != null && (next == null || on.isBefore(next))) next = on;
    }
    return CorpTdTotals._(
      balance: balance,
      maturityValue: deposits.fold<double>(0, (s, d) => s + d.maturityValue),
      // Weighted by principal: a large deposit's rate counts for more.
      averageRate: rated <= 0 ? null : weighted / rated,
      count: deposits.length,
      nextMaturity: next,
    );
  }

  final double balance;
  final double maturityValue;

  /// Null when no deposit carries a rate.
  final double? averageRate;
  final int count;
  final DateTime? nextMaturity;
}
