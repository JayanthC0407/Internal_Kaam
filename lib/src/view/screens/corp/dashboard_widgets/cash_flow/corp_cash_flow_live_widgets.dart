import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_snapshot_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cashflow_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_live_widget.dart';

/// The Cash Flow Snapshot and Summary on live data — what the Corporate
/// registry builds. Both read [corpCashFlowActivityProvider], for today and
/// for this month respectively.

AsyncValue<CorpCashFlowLedger> _ledger(
  WidgetRef ref,
  CorpCashFlowPeriod period,
) =>
    ref.watch(corpCashFlowActivityProvider(period)).whenData(
          (v) => CorpCashFlowLedger(accounts: v.accounts, today: v.today),
        );

const _noAccounts = 'You have no current or savings accounts.';

/// OBDX `cash-flow-snapshot`, live: today's money in and out.
class CorpLiveCashFlowSnapshotWidget extends ConsumerWidget {
  const CorpLiveCashFlowSnapshotWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const period = CorpCashFlowPeriod.today;
    return CorpLiveWidget<CorpCashFlowLedger>(
      title: 'Today Cashflow Snapshot',
      value: _ledger(ref, period),
      onRetry: () => ref.invalidate(corpCashFlowActivityProvider(period)),
      isEmpty: (ledger) => ledger.isEmpty,
      emptyMessage: _noAccounts,
      emptyIcon: Icons.account_balance_outlined,
      currencyOf: (ledger) => ledger.currency,
      builder: (ledger) => CorpCashFlowSnapshotWidget(data: ledger.day()),
    );
  }
}

/// The month's cash position, live (registered as `cashflow-summary`).
class CorpLiveCashflowSummaryWidget extends ConsumerWidget {
  const CorpLiveCashflowSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const period = CorpCashFlowPeriod.thisMonth;
    return CorpLiveWidget<CorpCashFlowLedger>(
      title: 'Cashflow Summary',
      value: _ledger(ref, period),
      onRetry: () => ref.invalidate(corpCashFlowActivityProvider(period)),
      isEmpty: (ledger) => ledger.isEmpty,
      emptyMessage: _noAccounts,
      emptyIcon: Icons.account_balance_outlined,
      currencyOf: (ledger) => ledger.currency,
      builder: (ledger) => CorpCashflowSummaryWidget(data: ledger.month()),
    );
  }
}
