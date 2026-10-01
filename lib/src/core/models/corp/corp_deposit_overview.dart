import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';

/// Everything the `TD Accounts Overview` widget shows, derived from the
/// deposit list returned by `GET /digx-common/td/v1/deposit`.
///
/// The host has no roll-up endpoint for this — `account/v1/accounts`
/// carries a `summary.items[]` total for the Deposits group but nothing
/// per-deposit, and the widget needs maturity dates and rates. So the
/// figures are computed here from the same account objects the Deposits tab
/// already loads, rather than fetched a second time.
///
/// Every field is nullable or empty when the underlying data is absent:
/// a host that does not send `interestRate` gets no average rate, not a
/// zero, so the widget can show "—" instead of a wrong number.
class CorpTermDepositOverview {
  const CorpTermDepositOverview({
    required this.deposits,
    required this.activeCount,
    required this.upcomingMaturities,
    this.totalBalance,
    this.averageRate,
    this.totalMaturityValue,
  });

  static const empty = CorpTermDepositOverview(
    deposits: <CorpAccount>[],
    activeCount: 0,
    upcomingMaturities: <CorpAccount>[],
  );

  /// Every deposit considered, newest host order preserved.
  final List<CorpAccount> deposits;

  /// "Active deposits" — the count of deposits in ACTIVE status. Falls back
  /// to the full count when the host sends no status at all.
  final int activeCount;

  /// The next few deposits to mature, earliest first. Only deposits with a
  /// maturity date in the future are included.
  final List<CorpAccount> upcomingMaturities;

  /// "Total TD balance" — the principal held, summed across deposits. Null
  /// when the deposits span more than one currency, because a mixed-currency
  /// sum would be meaningless; the widget then falls back to the host's own
  /// converted group total.
  final MoneyAmount? totalBalance;

  /// "Average rate" — weighted by principal, so a large deposit at 3% does
  /// not read the same as a small one. Null when no deposit carries a rate.
  final double? averageRate;

  /// "Total maturity value" across [upcomingMaturities].
  final MoneyAmount? totalMaturityValue;

  bool get isEmpty => deposits.isEmpty;

  /// The soonest maturity date, or null when none is known.
  DateTime? get nextMaturityDate =>
      upcomingMaturities.isEmpty ? null : upcomingMaturities.first.maturityDateTime;

  /// Builds the overview from a deposit list.
  ///
  /// [now] is injectable so "upcoming" is testable; it defaults to the
  /// current date, truncated to midnight so a deposit maturing today still
  /// counts as upcoming.
  factory CorpTermDepositOverview.fromAccounts(
    List<CorpAccount> accounts, {
    DateTime? now,
    int maxUpcoming = 4,
  }) {
    if (accounts.isEmpty) return empty;

    final today = _startOfDay(now ?? DateTime.now());

    var hasStatus = false;
    var activeCount = 0;
    for (final account in accounts) {
      if (account.status.trim().isNotEmpty) hasStatus = true;
      if (account.isActive) activeCount++;
    }

    // `displayBalance` as the fallback, not `currentBalance` directly, so a
    // host that reports a deposit's holding under `availableBalance` gives
    // this widget the same figure the Accounts grid already shows for it.
    final balance = _sumInSingleCurrency(
      accounts.map((account) => account.principalAmount ?? account.displayBalance),
    );

    final upcoming = accounts
        .where((account) {
          final maturity = account.maturityDateTime;
          return maturity != null && !maturity.isBefore(today);
        })
        .toList()
      ..sort((a, b) => a.maturityDateTime!.compareTo(b.maturityDateTime!));

    final limited = upcoming.take(maxUpcoming).toList(growable: false);

    return CorpTermDepositOverview(
      deposits: accounts,
      activeCount: hasStatus ? activeCount : accounts.length,
      upcomingMaturities: limited,
      totalBalance: balance,
      averageRate: _weightedAverageRate(accounts),
      totalMaturityValue: _sumInSingleCurrency(
        limited.map((account) => account.maturityAmount),
      ),
    );
  }

  /// Principal-weighted mean rate. Deposits with no rate are excluded
  /// entirely rather than counted as 0%. A deposit with a rate but no
  /// principal is weighted 1, so a single rate still averages to itself.
  static double? _weightedAverageRate(List<CorpAccount> accounts) {
    var weightedSum = 0.0;
    var weightTotal = 0.0;

    for (final account in accounts) {
      final rate = account.interestRate;
      if (rate == null) continue;
      final principal =
          account.principalAmount?.amount ?? account.displayBalance?.amount;
      final weight = (principal == null || principal <= 0) ? 1.0 : principal;
      weightedSum += rate * weight;
      weightTotal += weight;
    }

    if (weightTotal == 0) return null;
    return weightedSum / weightTotal;
  }

  /// Sums amounts only when they all share one currency. Returns null on a
  /// mixed set — see [totalBalance].
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
