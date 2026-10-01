import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_live_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_accounts_overview_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_summary_widget.dart';

/// The Term Deposit widgets on live data — what the Corporate registry
/// builds. Both read one [corpDepositsProvider].

AsyncValue<CorpTdBook> _book(WidgetRef ref) =>
    ref.watch(corpDepositsProvider).whenData(CorpTdBook.new);

/// "Today" for which maturities are upcoming: the bank's business date,
/// or the device's while that is still loading.
DateTime _today(WidgetRef ref) =>
    ref.watch(corpBusinessDateProvider).valueOrNull ?? DateTime.now();

const _noDeposits = 'You have no term deposits.';

/// OBDX `td-accounts-overview`, live.
class CorpLiveTdAccountsOverviewWidget extends ConsumerWidget {
  const CorpLiveTdAccountsOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _today(ref);
    return CorpLiveWidget<CorpTdBook>(
      title: 'TD Accounts Overview',
      value: _book(ref),
      onRetry: () => ref.invalidate(corpDepositsProvider),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noDeposits,
      emptyIcon: Icons.savings_outlined,
      currencyOf: (book) => book.currency,
      builder: (book) => CorpTdAccountsOverviewWidget(
        deposits: book.deposits,
        asOf: today,
      ),
    );
  }
}

/// OBDX `td-summary`, live.
class CorpLiveTdSummaryWidget extends ConsumerWidget {
  const CorpLiveTdSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _today(ref);
    return CorpLiveWidget<CorpTdBook>(
      title: 'TD Summary',
      value: _book(ref),
      onRetry: () => ref.invalidate(corpDepositsProvider),
      isEmpty: (book) => book.isEmpty,
      emptyMessage: _noDeposits,
      emptyIcon: Icons.savings_outlined,
      currencyOf: (book) => book.currency,
      builder: (book) =>
          CorpTdSummaryWidget(deposits: book.deposits, asOf: today),
    );
  }
}
