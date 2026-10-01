import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_withdrawal_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_withdrawal_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_live_widget.dart';

/// OBDX `cash-withdrawal-summary` on live data — this month's cash
/// withdrawals, what the Corporate registry builds.
class CorpLiveCashWithdrawalSummaryWidget extends ConsumerWidget {
  const CorpLiveCashWithdrawalSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CorpLiveWidget<CorpWithdrawalBook>(
      title: 'Cash Withdrawal Summary',
      value: ref.watch(corpWithdrawalsProvider).whenData(
          (v) => CorpWithdrawalBook(entries: v.entries, month: v.month)),
      onRetry: () => ref.invalidate(corpWithdrawalsProvider),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: 'No cash withdrawals this month.',
      emptyIcon: Icons.payments_outlined,
      currencyOf: (book) => book.currency,
      builder: (book) => CorpCashWithdrawalSummaryWidget(data: book.toData()),
    );
  }
}
