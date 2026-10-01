import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_sample_data.dart';

/// Term deposits from `td/v1/deposit`, as the TD widgets need them.
///
/// Like the Loans widgets, the figures are for one currency — the one most
/// deposits are in — since amounts in different currencies cannot be added.
class CorpTdBook {
  CorpTdBook(List<CorpAccount> accounts)
      : currency = _mainCurrency(accounts),
        deposits = _deposits(accounts, _mainCurrency(accounts));

  final String? currency;
  final List<CorpTermDeposit> deposits;

  bool get isEmpty => deposits.isEmpty;

  static String? _mainCurrency(List<CorpAccount> accounts) {
    final counts = <String, int>{};
    for (final a in accounts) {
      final code = a.currencyCode.trim();
      if (code.isNotEmpty) counts.update(code, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static List<CorpTermDeposit> _deposits(
    List<CorpAccount> accounts,
    String? currency,
  ) =>
      [
        for (final a in accounts)
          if (!a.isClosed && (currency == null || a.currencyCode == currency))
            fromAccount(a),
      ];

  static CorpTermDeposit fromAccount(CorpAccount a) {
    final principal = (a.principalAmount ?? a.displayBalance)?.amount ?? 0;
    return CorpTermDeposit(
      id: a.displayNumber.isEmpty ? a.title : a.displayNumber,
      principal: principal,
      rate: a.interestRate,
      maturesOn: a.maturityDate,
      // Without a maturity value, the principal — the least it pays.
      maturityValue: a.maturityAmount?.amount ?? principal,
      status: _statusLabel(a.status),
    );
  }

  static String _statusLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Active';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
