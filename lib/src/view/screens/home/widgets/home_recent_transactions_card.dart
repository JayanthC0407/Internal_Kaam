import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_tile.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Live recent transactions for Home Overview (primary CASA account).
class HomeRecentTransactionsCard extends ConsumerStatefulWidget {
  const HomeRecentTransactionsCard({
    super.key,
    this.hideBalance = false,
  });

  final bool hideBalance;

  @override
  ConsumerState<HomeRecentTransactionsCard> createState() =>
      _HomeRecentTransactionsCardState();
}

class _HomeRecentTransactionsCardState
    extends ConsumerState<HomeRecentTransactionsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeRecentTransactionsProvider.notifier).ensureLoaded();
    });
  }

  void _openAll() {
    final accountId = ref.read(homeRecentTransactionsProvider).accountId;
    if (accountId == null || accountId.isEmpty) return;
    Navigator.of(context).pushNamed(
      RoutesConst.casaTransactionsScreen,
      arguments: CasaTransactionsArgs(accountId: accountId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeRecentTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.recentTransactions,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                  height: 1.2,
                ),
              ),
            ),
            if (state.accountId != null && state.accountId!.isNotEmpty)
              InkWell(
                onTap: _openAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.viewAll,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.brand(context),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: HomeColors.brand(context),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: _body(context, l10n, state),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    HomeRecentTransactionsState state,
  ) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && state.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: HomeColors.textSecondary(context),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(homeRecentTransactionsProvider.notifier).refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ],
        ),
      );
    }

    if (state.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.casaTransactionsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: HomeColors.textSecondary(context),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < state.transactions.length; i++) ...[
          if (i > 0) Divider(height: 1, color: HomeColors.divider(context)),
          CasaTransactionTile(
            transaction: state.transactions[i],
            compact: true,
            hideBalance: widget.hideBalance,
          ),
        ],
      ],
    );
  }
}
