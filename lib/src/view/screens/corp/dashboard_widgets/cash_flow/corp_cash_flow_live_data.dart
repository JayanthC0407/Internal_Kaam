import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';

/// The current and savings accounts' transactions for a period, as the
/// Cash Flow Snapshot and Summary need them: money in is the credits, money
/// out the debits.
///
/// Figures are for one currency — the one most accounts are in — since
/// amounts in different currencies cannot be added.
class CorpCashFlowLedger {
  CorpCashFlowLedger({
    required List<CorpAccountActivity> accounts,
    required this.today,
  })  : currency = _mainCurrency(accounts),
        _all = accounts;

  final List<CorpAccountActivity> _all;
  final DateTime today;
  final String? currency;

  List<CorpAccountActivity> get accounts => [
        for (final a in _all)
          if (currency == null || a.account.currencyCode == currency) a,
      ];

  /// No current or savings account to read — as opposed to accounts with
  /// no activity, which is a real "nothing moved today".
  bool get isEmpty => accounts.isEmpty;

  static String? _mainCurrency(List<CorpAccountActivity> accounts) {
    final counts = <String, int>{};
    for (final a in accounts) {
      final code = a.account.currencyCode.trim();
      if (code.isNotEmpty) counts.update(code, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  ({double inflow, double outflow, int credits, int debits}) _totals() {
    var inflow = 0.0;
    var outflow = 0.0;
    var credits = 0;
    var debits = 0;
    for (final a in accounts) {
      for (final t in a.result.transactions) {
        final amount = t.amount.amount.abs();
        if (t.isCredit) {
          inflow += amount;
          credits++;
        } else {
          outflow += amount;
          debits++;
        }
      }
    }
    return (inflow: inflow, outflow: outflow, credits: credits, debits: debits);
  }

  CorpCashFlowDay day() {
    final t = _totals();
    return CorpCashFlowDay(
      date: today,
      inflow: t.inflow,
      outflow: t.outflow,
      inflowCount: t.credits,
      outflowCount: t.debits,
    );
  }

  /// The month so far. The opening balance is the host's when it sends
  /// one; otherwise it is worked back from the closing balance (the
  /// host's, else the account's own) less the month's movement.
  CorpCashFlowMonth month() {
    final t = _totals();
    var opening = 0.0;
    for (final a in accounts) {
      final net = a.result.transactions.fold<double>(
        0,
        (s, x) =>
            s + (x.isCredit ? x.amount.amount.abs() : -x.amount.amount.abs()),
      );
      final closing = a.result.closingBalance?.amount ??
          a.account.displayBalance?.amount ??
          0;
      opening += a.result.openingBalance?.amount ?? closing - net;
    }
    return CorpCashFlowMonth(
      month: DateTime(today.year, today.month),
      openingBalance: opening,
      inflow: t.inflow,
      outflow: t.outflow,
      inflowCount: t.credits,
      outflowCount: t.debits,
    );
  }
}
