import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_filter_sheet.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_row.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transactions_table.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/statement_download.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/transactions_phone_header.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/paginated_list_controls.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// How many transactions the "View All" screen shows per page.
const int _pageSize = 10;

class CasaTransactionsArgs {
  const CasaTransactionsArgs({required this.accountId});

  final String accountId;
}

class CasaTransactionsScreen extends ConsumerStatefulWidget {
  const CasaTransactionsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<CasaTransactionsScreen> createState() =>
      _CasaTransactionsScreenState();
}

class _CasaTransactionsScreenState
    extends ConsumerState<CasaTransactionsScreen> {
  late String _selectedAccountId;
  CasaTransactionQuery _query = const CasaTransactionQuery();
  bool _downloadingStatement = false;
  final _pager = ListPager<CasaTransaction>(pageSize: _pageSize);
  String? _pagedForAccountId;

  /// Phone "Search for amount" box = OBDX's Amount filter.
  final _amountController = TextEditingController();

  /// Phone list grows 10 rows at a time as you scroll, like OBDX's
  /// `loadMoreOnScroll` (fetchSize 10).
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.accountId.trim();
    _amountController.text = _query.fromAmount ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
      _loadSelected();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadSelected() {
    final id = _selectedAccountId.trim();
    if (id.isEmpty) return;
    _pager.reset();
    _visibleCount = _pageSize;
    ref.read(casaAccountDetailProvider(id).notifier).load();
    ref.read(casaTransactionsProvider(id).notifier).load(query: _query);
  }

  Future<void> _openFilter() async {
    final accounts =
        ref.read(casaAccountsProvider).summary?.accounts ?? const <CasaAccount>[];
    final result = await showCasaTransactionFilter(
      context: context,
      accounts: accounts,
      selectedAccountId: _selectedAccountId,
      query: _query,
    );
    if (!mounted || result == null) return;

    final accountChanged = result.accountId != _selectedAccountId;
    setState(() {
      _selectedAccountId = result.accountId;
      _query = result.query;
      _amountController.text = _query.fromAmount ?? '';
    });
    if (accountChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadSelected();
      });
      return;
    }
    _loadSelected();
  }

  /// OBDX sends its single Amount filter as `fromAmount = toAmount`; an
  /// empty box clears it. Reloads from the server like Apply does.
  void _applyAmount(String raw) {
    final amount = raw.trim();
    final next = amount.isEmpty
        ? _query.copyWith(clearFromAmount: true, clearToAmount: true)
        : _query.copyWith(fromAmount: amount, toAmount: amount);
    if (next == _query) return;
    setState(() => _query = next);
    _loadSelected();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref
          .read(casaTransactionsProvider(_selectedAccountId).notifier)
          .load(query: _query),
      ref.read(casaAccountDetailProvider(_selectedAccountId).notifier).load(),
    ]);
  }

  Future<void> _downloadStatement() async {
    if (_downloadingStatement) return;
    await downloadTransactionStatement(
      context: context,
      ref: ref,
      accountId: _selectedAccountId,
      query: _query,
      onBusy: (busy) {
        if (mounted) setState(() => _downloadingStatement = busy);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final txState = ref.watch(casaTransactionsProvider(_selectedAccountId));
    final detailState = ref.watch(casaAccountDetailProvider(_selectedAccountId));
    final listState = ref.watch(casaAccountsProvider);
    final accounts = listState.summary?.accounts ?? const <CasaAccount>[];
    final detail = detailState.detail;
    final result = txState.result;
    final selectedAccount = _findAccount(accounts, _selectedAccountId);

    ref.listen<CasaAccountsState>(casaAccountsProvider, (previous, next) {
      final list = next.summary?.accounts ?? const <CasaAccount>[];
      if (list.isEmpty) return;
      final hasSelected = list.any((a) => a.id == _selectedAccountId);
      if (hasSelected) return;
      final fallback = list.firstWhere(
        (a) => a.id.isNotEmpty,
        orElse: () => list.first,
      );
      if (fallback.id.isEmpty || fallback.id == _selectedAccountId) return;
      setState(() => _selectedAccountId = fallback.id);
      ref.read(casaAccountDetailProvider(fallback.id).notifier).load();
      ref
          .read(casaTransactionsProvider(fallback.id).notifier)
          .load(query: _query);
    });

    final currency = result?.currencyCode ??
        detail?.currencyCode ??
        selectedAccount?.currencyCode ??
        '';

    final opening = result?.openingBalance ??
        detail?.todaysOpeningBalance ??
        detail?.currentBalance;
    final closing = result?.closingBalance ??
        detail?.availableBalance ??
        detail?.currentBalance;

    if (!wide) {
      return SecureScreen(
        child: _buildPhone(
          l10n: l10n,
          txState: txState,
          account: selectedAccount,
          detail: detail,
          opening: _money(opening, currency),
          closing: _money(closing, currency),
        ),
      );
    }

    return SecureScreen(
      child: Scaffold(
        backgroundColor: HomeColors.bg(context),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 16,
                  wide ? 8 : 12,
                  wide ? 28 : 16,
                  8,
                ),
                child: CasaScreenHeader(
                  title: wide
                      ? l10n.casaTransactionsTitleWeb
                      : l10n.casaTransactionsTitle,
                  wide: wide,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CasaIconButton(
                        tooltip: l10n.filter,
                        onPressed: _openFilter,
                        icon: Icons.filter_alt_outlined,
                      ),
                      const SizedBox(width: 8),
                      _downloadingStatement
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : CasaIconButton(
                              tooltip: l10n.casaDownloadStatement,
                              onPressed: _downloadStatement,
                              icon: Icons.download_rounded,
                            ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      8,
                      wide ? 28 : 16,
                      28,
                    ),
                    children: [
                      _AccountSummary(
                        account: selectedAccount,
                        detail: detail,
                        query: _query,
                        fallbackId: _selectedAccountId,
                      ),
                      const SizedBox(height: 16),
                      CasaBrandBanner(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 24 : 16,
                          wide ? 20 : 14,
                          wide ? 24 : 16,
                          wide ? 20 : 14,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _BannerBalance(
                                  label: l10n.casaOpeningBalance,
                                  value: _money(opening, currency),
                                  valueSize: wide ? 18 : 16,
                                ),
                              ),
                              Expanded(
                                child: _BannerBalance(
                                  label: l10n.casaClosingBalance,
                                  value: _money(closing, currency),
                                  valueSize: wide ? 18 : 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (txState.isLoading && result == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (txState.errorMessage != null && result == null)
                        _ErrorCard(
                          message: txState.errorMessage!,
                          onRetry: _loadSelected,
                        )
                      else if ((result?.transactions ?? const <CasaTransaction>[])
                          .isEmpty)
                        const _TransactionsCard(
                          transactions: <CasaTransaction>[],
                        )
                      else
                        _buildPaginatedTransactions(
                          context,
                          result!.transactions,
                          wide,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Phone layout from the designer mock: brand header (back, title,
  /// download, filter, balances, "Search for amount") over a white
  /// "Recent Transactions" card grouped by month.
  Widget _buildPhone({
    required AppLocalizations l10n,
    required CasaTransactionsState txState,
    required CasaAccount? account,
    required CasaAccountDetail? detail,
    required String opening,
    required String closing,
  }) {
    final result = txState.result;
    final transactions = result?.transactions ?? const <CasaTransaction>[];
    final hasMore = transactions.length > _visibleCount;

    final Widget content;
    if (txState.isLoading && result == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (txState.errorMessage != null && result == null) {
      content = _ErrorCard(
        message: txState.errorMessage!,
        onRetry: _loadSelected,
      );
    } else {
      content = _PhoneTransactionsCard(
        transactions: transactions.take(_visibleCount).toList(),
        hasMore: hasMore,
        onLoadMore: () => setState(() => _visibleCount += _pageSize),
      );
    }

    final number = account?.displayNumber ?? detail?.account.displayNumber ?? '';
    final masked = number.length > 4
        ? '•••• ${number.substring(number.length - 4)}'
        : number;
    final currencyCode = (detail?.currencyCode ?? account?.currencyCode ?? '')
        .trim()
        .toUpperCase();

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionsPhoneHeader(
            title: l10n.casaTransactionsTitle,
            accountLine: [
              if (masked.isNotEmpty) masked,
              if (currencyCode.isNotEmpty) currencyCode,
            ].join('  |  '),
            filterSummary: casaFilterSummary(l10n, _query),
            filtered: !_query.isDefault,
            opening: opening,
            closing: closing,
            amountController: _amountController,
            onAmountSubmitted: _applyAmount,
            onFilter: _openFilter,
            onDownload: _downloadStatement,
            downloading: _downloadingStatement,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
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
                  children: [content],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedTransactions(
    BuildContext context,
    List<CasaTransaction> transactions,
    bool wide,
  ) {
    if (_pagedForAccountId != _selectedAccountId) {
      _pagedForAccountId = _selectedAccountId;
      _pager.reset();
    }
    final currentPage = _pager.clamp(transactions.length);
    final pageItems = _pager.slice(transactions);
    final pageCount = _pager.pageCount(transactions.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wide
            ? CasaTransactionsTable(transactions: pageItems)
            : _TransactionsCard(transactions: pageItems),
        PaginatedListControls(
          currentPage: currentPage,
          pageCount: pageCount,
          totalItems: transactions.length,
          pageSize: _pageSize,
          onPageChanged: (page) => setState(() => _pager.goTo(page)),
        ),
      ],
    );
  }

  CasaAccount? _findAccount(List<CasaAccount> accounts, String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String _money(MoneyAmount? amount, String currencyFallback) {
    if (amount == null) {
      return MoneyFormat.format(0, currencyCode: currencyFallback);
    }
    return MoneyFormat.format(
      amount.amount,
      currencyCode: amount.currency ?? currencyFallback,
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.account,
    required this.detail,
    required this.query,
    required this.fallbackId,
  });

  final CasaAccount? account;
  final CasaAccountDetail? detail;
  final CasaTransactionQuery query;
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final masked = account?.maskedNumber ??
        detail?.account.maskedNumber ??
        _mask(fallbackId);
    final holder = detail?.primaryAccountHolder?.trim();
    final currency = (detail?.currencyCode ?? account?.currencyCode ?? '')
        .trim()
        .toUpperCase();
    final subtitleParts = <String>[
      if (holder != null && holder.isNotEmpty) holder,
      if (currency.isNotEmpty) currency,
    ];
    final filterSummary = casaFilterSummary(l10n, query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.casaAccountNumberLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          masked,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colors.textPrimary,
            height: 1.35,
          ),
        ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitleParts.join('  |  '),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          filterSummary,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  String _mask(String id) {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return id;
    return '${'*' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }
}

class _BannerBalance extends StatelessWidget {
  const _BannerBalance({
    required this.label,
    required this.value,
    this.valueSize = 16,
  });

  final String label;
  final String value;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: valueSize,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});

  final List<CasaTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                l10n.casaTransactionsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            )
          else
            for (var i = 0; i < transactions.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.divider),
              CasaTransactionRow(transaction: transactions[i]),
            ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}

class _PhoneTransactionsCard extends StatelessWidget {
  const _PhoneTransactionsCard({
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
            TextButton(
              onPressed: onLoadMore,
              child: Text(l10n.casaLoadMore),
            ),
        ],
      ),
    );
  }
}
