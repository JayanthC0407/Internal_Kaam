import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_transactions_screen_provider.dart';
import 'package:ubci_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_filter_sheet.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_row.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transactions_table.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/statement_download.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/transactions_phone_header.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/account_picker_field.dart';
import 'package:ubci_bank/src/view/widgets/paginated_list_controls.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Rows per step — OBDX loads 10 at a time (`fetchSize: 10`).
const int _pageSize = 10;

/// Route arguments for [LoanTransactionsScreen].
class LoanTransactionsArgs {
  const LoanTransactionsArgs({
    required this.accounts,
    required this.initialAccountId,
  });

  final List<SelectableAccount> accounts;
  final String initialAccountId;
}

/// OBDX Loans "Transactions" (`loan-transactions`, type LON): the same
/// component as CASA — View Options, Transactions, Amount and Reference
/// Number filters plus Download — without Opening / Closing Balance,
/// which OBDX shows for CASA only.
class LoanTransactionsScreen extends ConsumerStatefulWidget {
  const LoanTransactionsScreen({super.key, required this.args});

  final LoanTransactionsArgs args;

  @override
  ConsumerState<LoanTransactionsScreen> createState() =>
      _LoanTransactionsScreenState();
}

class _LoanTransactionsScreenState
    extends ConsumerState<LoanTransactionsScreen> {
  final _pager = ListPager<CasaTransaction>(pageSize: _pageSize);
  final _amountController = TextEditingController();
  String? _pagedForAccountId;
  int _visibleCount = _pageSize;
  bool _downloading = false;

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
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  CasaTransactionQuery get _query =>
      ref.read(loanTransactionsScreenProvider).query;

  void _apply(CasaTransactionQuery query) {
    setState(() {
      _visibleCount = _pageSize;
      _pager.reset();
      _amountController.text = query.fromAmount ?? '';
    });
    ref.read(loanTransactionsScreenProvider.notifier).applyQuery(query);
  }

  /// OBDX's single Amount filter: `fromAmount = toAmount`, empty clears.
  void _applyAmount(String raw) {
    final amount = raw.trim();
    _apply(
      amount.isEmpty
          ? _query.copyWith(clearFromAmount: true, clearToAmount: true)
          : _query.copyWith(fromAmount: amount, toAmount: amount),
    );
  }

  Future<void> _openFilter() async {
    final state = ref.read(loanTransactionsScreenProvider);
    final result = await showCasaTransactionFilter(
      context: context,
      accounts: const <CasaAccount>[],
      selectedAccountId: state.selectedAccountId ?? '',
      query: state.query,
    );
    if (!mounted || result == null) return;
    _apply(result.query);
  }

  Future<void> _download() async {
    final accountId = ref.read(loanTransactionsScreenProvider).selectedAccountId;
    if (_downloading || accountId == null) return;
    await downloadTransactionStatement(
      context: context,
      ref: ref,
      accountId: accountId,
      query: _query,
      transactionsPath: ApiConst.loanTransactionsApi(accountId),
      onBusy: (busy) {
        if (mounted) setState(() => _downloading = busy);
      },
    );
  }

  void _selectAccount(String id) {
    setState(() => _visibleCount = _pageSize);
    ref.read(loanTransactionsScreenProvider.notifier).selectAccount(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final state = ref.watch(loanTransactionsScreenProvider);
    final transactions = [
      for (final t in state.transactions) CasaTransaction.fromAccountTransaction(t),
    ];
    if (_pagedForAccountId != state.selectedAccountId) {
      _pagedForAccountId = state.selectedAccountId;
      _pager.reset();
    }

    final picker = widget.args.accounts.length > 1
        ? Align(
            alignment: Alignment.centerLeft,
            child: AccountPickerField(
              accounts: widget.args.accounts,
              selectedAccountId: state.selectedAccountId,
              onSelected: _selectAccount,
            ),
          )
        : null;

    final Widget content;
    if (state.isLoading && state.transactions.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.errorMessage != null && state.transactions.isEmpty) {
      content = _LoanError(
        message: state.errorMessage!,
        onRetry: ref.read(loanTransactionsScreenProvider.notifier).refresh,
      );
    } else if (wide) {
      content = transactions.isEmpty
          ? _ListCard(transactions: const [], hasMore: false, onLoadMore: () {})
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CasaTransactionsTable(transactions: _pager.slice(transactions)),
                PaginatedListControls(
                  currentPage: _pager.clamp(transactions.length),
                  pageCount: _pager.pageCount(transactions.length),
                  totalItems: transactions.length,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _pager.goTo(page)),
                ),
              ],
            );
    } else {
      content = _ListCard(
        transactions: transactions.take(_visibleCount).toList(),
        hasMore: transactions.length > _visibleCount,
        onLoadMore: () => setState(() => _visibleCount += _pageSize),
      );
    }

    final selected = _selectedAccount(state.selectedAccountId);
    final filterSummary = casaFilterSummary(l10n, state.query);

    if (wide) {
      return SecureScreen(
        child: Scaffold(
          backgroundColor: HomeColors.bg(context),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: ref.read(loanTransactionsScreenProvider.notifier).refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                children: [
                  CasaScreenHeader(
                    title: l10n.casaTransactionsTitleWeb,
                    wide: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CasaIconButton(
                          tooltip: l10n.filter,
                          onPressed: _openFilter,
                          icon: Icons.filter_alt_outlined,
                        ),
                        const SizedBox(width: 8),
                        _downloading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : CasaIconButton(
                                tooltip: l10n.casaDownloadStatement,
                                onPressed: _download,
                                icon: Icons.download_rounded,
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (picker != null) ...[picker, const SizedBox(height: 8)],
                  Text(
                    filterSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hasMore = !wide && transactions.length > _visibleCount;
    return SecureScreen(
      child: Scaffold(
        backgroundColor: HomeColors.bg(context),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TransactionsPhoneHeader(
              title: l10n.casaTransactionsTitle,
              accountLine: [
                if (selected != null && selected.title.isNotEmpty) selected.title,
                if (selected != null) _mask(selected.subtitle),
              ].where((part) => part.isNotEmpty).join('  |  '),
              filterSummary: filterSummary,
              filtered: !state.query.isDefault,
              amountController: _amountController,
              onAmountSubmitted: _applyAmount,
              onFilter: _openFilter,
              onDownload: _download,
              downloading: _downloading,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.read(loanTransactionsScreenProvider.notifier).refresh,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (hasMore && notification.metrics.extentAfter < 200) {
                      setState(() => _visibleCount += _pageSize);
                    }
                    return false;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      if (picker != null) ...[picker, const SizedBox(height: 12)],
                      content,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SelectableAccount? _selectedAccount(String? id) {
    for (final account in widget.args.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  static String _mask(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return number;
    return '•••• ${digits.substring(digits.length - 4)}';
  }
}

/// White "Recent Transactions" card with the shared month-grouped rows.
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.transactions,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<CasaTransaction> transactions;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.casaRecentTransactions,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                l10n.casaTransactionsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            )
          else
            CasaTransactionGroupList(transactions: transactions),
          if (hasMore)
            TextButton(onPressed: onLoadMore, child: Text(l10n.casaLoadMore)),
        ],
      ),
    );
  }
}

class _LoanError extends StatelessWidget {
  const _LoanError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 36, color: colors.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}
