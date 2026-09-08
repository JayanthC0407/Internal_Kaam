import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/account_category.dart';
import 'package:ubci_bank/src/view/providers/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_tile.dart';
import 'package:ubci_bank/src/view/screens/transactions/widgets/transaction_tile.dart';
import '../home_colors.dart';

/// "Recent Transactions" dashboard widget. Lets the user switch between
/// account types (Current & Savings, Loans, Term Deposits, Recurring
/// Deposits, Credit Cards) and a specific account within that type,
/// showing its last few transactions. Fully self-contained: it manages
/// its own account lists via [recentTransactionsWidgetProvider] rather
/// than depending on props from the dashboard screen.
class RecentTransactionsCard extends ConsumerStatefulWidget {
  const RecentTransactionsCard({super.key});

  @override
  ConsumerState<RecentTransactionsCard> createState() =>
      _RecentTransactionsCardState();
}

class _RecentTransactionsCardState
    extends ConsumerState<RecentTransactionsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recentTransactionsWidgetProvider.notifier).ensureLoaded();
      }
    });
  }

  void _openViewAll(BuildContext context, RecentTransactionsWidgetState state) {
    // Term/Recurring Deposits/Credit Cards have no working integration
    // yet — every other supported category gets a "View All" screen.
    if (!state.category.isSupported) return;
    final accountId = state.selectedAccountId;
    if (accountId == null) return;

    if (state.category == AccountCategory.currentAndSavings) {
      Navigator.of(context).pushNamed(
        RoutesConst.casaAccountDetailsScreen,
        arguments: CasaAccountDetailsArgs(accountId: accountId),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      RoutesConst.loanTransactionsScreen,
      arguments: LoanTransactionsArgs(
        accounts: state.accounts,
        initialAccountId: accountId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(recentTransactionsWidgetProvider);
    final notifier = ref.read(recentTransactionsWidgetProvider.notifier);
    final canViewAll =
        state.category.isSupported && state.selectedAccountId != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: HomeColors.brand(context).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
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
                  ),
                ),
              ),
              TextButton(
                onPressed: canViewAll ? () => _openViewAll(context, state) : null,
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.brand(context),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.viewAll,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryField(
                  l10n: l10n,
                  selected: state.category,
                  onSelected: (category) {
                    HapticFeedback.selectionClick();
                    notifier.selectCategory(category);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AccountNumberField(
                  accounts: state.accounts,
                  selectedAccountId: state.selectedAccountId,
                  isLoading: state.isLoadingAccounts,
                  onSelected: (id) {
                    HapticFeedback.selectionClick();
                    notifier.selectAccount(id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBody(context, l10n, state, notifier),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    RecentTransactionsWidgetState state,
    RecentTransactionsWidgetNotifier notifier,
  ) {
    if (!state.category.isSupported) {
      return _EmptyState(message: l10n.accountCategoryComingSoon);
    }

    if (state.isLoadingAccounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.accountsErrorMessage != null) {
      return _EmptyState(
        message: state.accountsErrorMessage!,
        actionLabel: l10n.accountsRetry,
        onAction: () => notifier.retryAccounts(),
      );
    }

    if (state.accounts.isEmpty) {
      return _EmptyState(message: l10n.accountsEmpty);
    }

    if (state.isLoadingTransactions && state.transactionsAreEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.transactionsErrorMessage != null && state.transactionsAreEmpty) {
      return _EmptyState(
        message: state.transactionsErrorMessage!,
        actionLabel: l10n.accountsRetry,
        onAction: () {
          final id = state.selectedAccountId;
          if (id != null) notifier.selectAccount(id);
        },
      );
    }

    if (state.transactionsAreEmpty) {
      return _EmptyState(message: l10n.casaTransactionsEmpty);
    }

    if (state.category == AccountCategory.currentAndSavings) {
      final transactions = state.casaTransactions;
      return Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0) Divider(height: 1, color: HomeColors.divider(context)),
            CasaTransactionTile(transaction: transactions[i], compact: true),
          ],
        ],
      );
    }

    final transactions = state.loanTransactions;
    return Column(
      children: [
        for (var i = 0; i < transactions.length; i++) ...[
          if (i > 0) Divider(height: 1, color: HomeColors.divider(context)),
          TransactionTile(transaction: transactions[i]),
        ],
      ],
    );
  }
}

/// "Account Type" dropdown — a plain tappable field that opens a bottom
/// sheet listing all 5 [AccountCategory] values, matching the reference
/// design's select-box look.
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.l10n,
    required this.selected,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final AccountCategory selected;
  final ValueChanged<AccountCategory> onSelected;

  String _label(AccountCategory category) {
    switch (category) {
      case AccountCategory.currentAndSavings:
        return l10n.accountCategoryCurrentSavings;
      case AccountCategory.loans:
        return l10n.accountCategoryLoans;
      case AccountCategory.termDeposits:
        return l10n.accountCategoryTermDeposits;
      case AccountCategory.recurringDeposits:
        return l10n.accountCategoryRecurringDeposits;
      case AccountCategory.creditCards:
        return l10n.accountCategoryCreditCards;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HomeColors.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeColors.divider(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: HomeColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in AccountCategory.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _label(category),
                      style: TextStyle(
                        fontWeight: category == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: HomeColors.textPrimary(sheetContext),
                      ),
                    ),
                    trailing: category == selected
                        ? Icon(
                            Icons.check_circle,
                            size: 18,
                            color: HomeColors.brand(sheetContext),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (category != selected) onSelected(category);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Account Number" dropdown — same interaction as [_CategoryField], but
/// for whichever [SelectableAccount]s the current category has.
class _AccountNumberField extends StatelessWidget {
  const _AccountNumberField({
    required this.accounts,
    required this.selectedAccountId,
    required this.isLoading,
    required this.onSelected,
  });

  final List<SelectableAccount> accounts;
  final String? selectedAccountId;
  final bool isLoading;
  final ValueChanged<String> onSelected;

  SelectableAccount? get _selected {
    if (selectedAccountId == null) return null;
    for (final a in accounts) {
      if (a.id == selectedAccountId) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final canPick = accounts.length > 1;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canPick ? () => _openPicker(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HomeColors.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeColors.divider(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isLoading
                    ? '…'
                    : (selected == null ? '—' : selected.subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
            if (canPick) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: HomeColors.textSecondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: HomeColors.divider(sheetContext),
                    ),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final selected = account.id == selectedAccountId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          account.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: HomeColors.textPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          account.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                size: 18,
                                color: HomeColors.brand(context),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onSelected(account.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HomeColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
