import 'package:ubci_bank/src/core/models/corp/corp_cash_collection.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';

/// Cash withdrawals from `cashmanagement/collections/CW`, as the Cash
/// Withdrawal Summary needs them.
///
/// Only what the entries say is shown: the total, a transaction count when
/// the host reports counts, and a channel split when it names channels.
/// The largest single withdrawal and the remaining limit are not in these
/// entries, so they show as not available rather than being guessed.
class CorpWithdrawalBook {
  CorpWithdrawalBook({
    required List<CorpCashCollectionEntry> entries,
    required this.month,
  })  : currency = _mainCurrency(entries),
        _entries = entries;

  final List<CorpCashCollectionEntry> _entries;
  final DateTime month;
  final String? currency;

  List<CorpCashCollectionEntry> get entries => [
        for (final e in _entries)
          if (currency == null || e.currency == null || e.currency == currency)
            e,
      ];

  bool get isEmpty => entries.every((e) => e.amount == 0);

  static String? _mainCurrency(List<CorpCashCollectionEntry> entries) {
    for (final e in entries) {
      if (e.currency != null) return e.currency;
    }
    return null;
  }

  CorpCashWithdrawals toData() {
    final list = entries;
    final counts = [
      for (final e in list)
        if (e.count != null) e.count!,
    ];
    final byChannel = <String, double>{};
    for (final e in list) {
      byChannel.update(
        e.channel ?? 'Withdrawals',
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    return CorpCashWithdrawals(
      month: month,
      transactions:
          counts.isEmpty ? null : counts.fold<int>(0, (s, c) => s + c),
      largest: null,
      availableLimit: null,
      byChannel: [
        for (final e in byChannel.entries)
          CorpWithdrawalChannel(label: e.key, amount: e.value),
      ],
    );
  }
}
