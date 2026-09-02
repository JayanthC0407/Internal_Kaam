import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/providers/loan_transactions_screen_provider.dart';
import 'package:ubci_bank/src/view/providers/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/account_picker_field.dart';
import 'package:ubci_bank/src/view/screens/transactions/widgets/transaction_tile.dart';

/// Route arguments for [LoanTransactionsScreen].
class LoanTransactionsArgs {
  const LoanTransactionsArgs({
    required this.accounts,
    required this.initialAccountId,
  });

  final List<SelectableAccount> accounts;
  final String initialAccountId;
}

/// "View All" destination for the dashboard's Recent Transactions widget
/// when it's showing a Loan — the full recent transaction list for a
/// user-selectable loan account.
class LoanTransactionsScreen extends ConsumerStatefulWidget {
  const LoanTransactionsScreen({super.key, required this.args});

  final LoanTransactionsArgs args;

  @override
  ConsumerState<LoanTransactionsScreen> createState() =>
      _LoanTransactionsScreenState();
}

class _LoanTransactionsScreenState
    extends ConsumerState<LoanTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(loanTransactionsScreenProvider.notifier)
          .selectAccount(widget.args.initialAccountId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanTransactionsScreenProvider);
    final notifier = ref.read(loanTransactionsScreenProvider.notifier);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: Text(l10n.recentTransactions),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.args.accounts.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AccountPickerField(
                  accounts: widget.args.accounts,
                  selectedAccountId: state.selectedAccountId,
                  onSelected: notifier.selectAccount,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: _buildBody(context, l10n, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    LoanTransactionsScreenState state,
  ) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.transactions.isEmpty) {
      return ListView(
        // ListView (not Column) so RefreshIndicator's pull gesture works
        // even when the error message alone doesn't fill the screen.
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () =>
                  ref.read(loanTransactionsScreenProvider.notifier).refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ),
        ],
      );
    }

    if (state.transactions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.casaTransactionsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.transactions.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: HomeColors.divider(context)),
      itemBuilder: (context, index) =>
          TransactionTile(transaction: state.transactions[index]),
    );
  }
}
