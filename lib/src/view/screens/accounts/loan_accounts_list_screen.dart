import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// "Loans & Finances" — lists every loan/finance account from
/// `GET /digx-common/loan/v1/loan`. Tapping a tile opens
/// [LoanAccountDetailsScreen] for that loan's overview / schedule /
/// disbursement details.
class LoanAccountsListScreen extends ConsumerStatefulWidget {
  const LoanAccountsListScreen({super.key});

  @override
  ConsumerState<LoanAccountsListScreen> createState() =>
      _LoanAccountsListScreenState();
}

class _LoanAccountsListScreenState
    extends ConsumerState<LoanAccountsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountsProvider);
    final loans = state.summary?.loans ?? const <LoanAccount>[];

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: Text(l10n.menuLoansFinances),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(loanAccountsProvider.notifier).refresh(),
        child: _buildBody(context, l10n, state, loans),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    LoanAccountsState state,
    List<LoanAccount> loans,
  ) {
    if (state.isLoading && loans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && loans.isEmpty) {
      return ListView(
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
                  ref.read(loanAccountsProvider.notifier).refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ),
        ],
      );
    }

    if (loans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.request_quote_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.loansEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _LoanTile(loan: loans[index]),
    );
  }
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan});

  final LoanAccount loan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outstanding = loan.outstandingAmount;
    final currency = outstanding?.currency ?? loan.currencyCode;
    final amountText = outstanding == null
        ? '—'
        : MoneyFormat.format(outstanding.amount, currencyCode: currency);

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pushNamed(
            RoutesConst.loanAccountDetailsScreen,
            arguments: LoanAccountDetailsArgs(loan: loan),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.request_quote_outlined,
                  color: HomeColors.brand(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loan.displayNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.loanOutstandingAmountLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: HomeColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
