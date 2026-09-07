import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/loan_currency_tabs.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// "Loans & Finances" — lists every loan/finance account from
/// `GET /digx-common/loan/v1/loan`. Tapping a tile opens
/// [LoanAccountDetailsScreen] for that loan's overview / schedule /
/// disbursement details.
///
/// Redesigned to match the "All Loans" UX/UI spec: a brand summary banner
/// (Total Outstanding Balance, maskable) beside a Total Loan Amount card,
/// a searchable/filterable account list, and a table-style layout on
/// tablet/desktop widths.
class LoanAccountsListScreen extends ConsumerStatefulWidget {
  const LoanAccountsListScreen({super.key});

  @override
  ConsumerState<LoanAccountsListScreen> createState() =>
      _LoanAccountsListScreenState();
}

enum _LoanStatusFilter { all, active, closed }

class _LoanAccountsListScreenState
    extends ConsumerState<LoanAccountsListScreen> {
  bool _balanceHidden = true;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _LoanStatusFilter _statusFilter = _LoanStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountsProvider.notifier).ensureLoaded();
    });
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoanAccount> _applyFilters(List<LoanAccount> loans) {
    var result = loans;
    if (_statusFilter != _LoanStatusFilter.all) {
      result = result.where((loan) {
        final status = (loan.status ?? '').trim().toLowerCase();
        final isActive = status.isEmpty ||
            status == 'active' ||
            status == 'open' ||
            status == 'a';
        return _statusFilter == _LoanStatusFilter.active
            ? isActive
            : !isActive;
      }).toList();
    }
    if (_query.isNotEmpty) {
      result = result
          .where((loan) =>
              loan.title.toLowerCase().contains(_query) ||
              loan.displayNumber.toLowerCase().contains(_query))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final wide = responsive.useWideLayout;
    final state = ref.watch(loanAccountsProvider);
    final summary = state.summary;

    // When the customer holds loans in more than one currency, everything
    // below (totals + list) is scoped to whichever currency tab is active —
    // amounts are never summed across currencies.
    final currencies = summary?.currencies ?? const <String>[];
    final rawSelection = ref.watch(selectedLoanCurrencyProvider);
    final currency = (rawSelection != null && currencies.contains(rawSelection))
        ? rawSelection
        : (currencies.isNotEmpty ? currencies.first : summary?.primaryCurrency);

    final allLoans = summary?.loansFor(currency) ?? const <LoanAccount>[];
    final loans = _applyFilters(allLoans);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                wide ? 12 : 12,
                wide ? 28 : 16,
                8,
              ),
              child: CasaScreenHeader(
                title: l10n.menuLoansFinances,
                wide: wide,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(loanAccountsProvider.notifier).refresh(),
                child: _buildBody(
                  context,
                  l10n,
                  state,
                  allLoans,
                  loans,
                  wide,
                  currencies: currencies,
                  currency: currency,
                  onCurrencyChanged: (c) =>
                      ref.read(selectedLoanCurrencyProvider.notifier).state = c,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    LoanAccountsState state,
    List<LoanAccount> allLoans,
    List<LoanAccount> loans,
    bool wide, {
    required List<String> currencies,
    required String? currency,
    required ValueChanged<String> onCurrencyChanged,
  }) {
    if (state.isLoading && allLoans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state.errorMessage != null && allLoans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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

    final summary = state.summary;

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 8, wide ? 28 : 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'All Loans',
          style: TextStyle(
            fontSize: wide ? 22 : 18,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View and manage all your loans.',
          style: TextStyle(
            fontSize: 13,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        if (summary != null && summary.isMultiCurrency) ...[
          LoanCurrencyTabs(
            currencies: currencies,
            selected: currency ?? currencies.first,
            onChanged: onCurrencyChanged,
          ),
          const SizedBox(height: 12),
        ],
        if (summary != null)
          _SummaryCards(
            summary: summary,
            wide: wide,
            currency: currency,
          ),
        const SizedBox(height: 20),
        _AccountsHeader(
          count: allLoans.length,
          wide: wide,
          searchOpen: _searchOpen,
          searchController: _searchController,
          statusFilter: _statusFilter,
          onToggleSearch: () => setState(() => _searchOpen = !_searchOpen),
          onStatusFilterChanged: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 12),
        if (allLoans.isEmpty)
          _EmptyState(message: l10n.loansEmpty)
        else if (loans.isEmpty)
          _EmptyState(message: 'No loans match your search.')
        else if (wide)
          _LoanTable(loans: loans)
        else
          Column(
            children: [
              for (var i = 0; i < loans.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _LoanCard(loan: loans[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _SummaryCards extends StatefulWidget {
  const _SummaryCards({
    required this.summary,
    required this.wide,
    required this.currency,
  });

  final LoanAccountsSummary summary;
  final bool wide;

  /// Currency the totals below should be scoped to (from the currency tabs
  /// when the customer holds loans in more than one). Falls back to the
  /// summary's own primary currency when there's only one.
  final String? currency;

  @override
  State<_SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<_SummaryCards> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = widget.currency ?? widget.summary.primaryCurrency ?? '';
    final loanCount = widget.summary.loansFor(currency).length;

    final outstanding = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.loanTotalOutstanding,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _hidden = !_hidden),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          MoneyFormat.format(
            widget.summary.totalOutstandingFor(currency),
            currencyCode: currency,
            hidden: _hidden,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$loanCount Loan${loanCount == 1 ? '' : 's'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        ],
      ),
    );

    final totalLoan = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: HomeColors.brand(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 17,
                  color: HomeColors.brand(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.loanTotalBorrowing,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _hidden = !_hidden),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            MoneyFormat.format(
              widget.summary.totalBorrowingFor(currency),
              currencyCode: currency,
              hidden: _hidden,
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Approved',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HomeColors.brand(context),
            ),
          ),
        ],
      ),
    );

    if (widget.wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: outstanding),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: totalLoan),
          ],
        ),
      );
    }

    return Column(
      children: [
        outstanding,
        const SizedBox(height: 12),
        totalLoan,
      ],
    );
  }
}

class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({
    required this.count,
    required this.wide,
    required this.searchOpen,
    required this.searchController,
    required this.statusFilter,
    required this.onToggleSearch,
    required this.onStatusFilterChanged,
  });

  final int count;
  final bool wide;
  final bool searchOpen;
  final TextEditingController searchController;
  final _LoanStatusFilter statusFilter;
  final VoidCallback onToggleSearch;
  final ValueChanged<_LoanStatusFilter> onStatusFilterChanged;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Your Accounts ($count)',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: HomeColors.textPrimary(context),
      ),
    );

    final filterMenu = PopupMenuButton<_LoanStatusFilter>(
      tooltip: 'Filter',
      initialValue: statusFilter,
      onSelected: onStatusFilterChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _LoanStatusFilter.all, child: Text('All loans')),
        PopupMenuItem(
            value: _LoanStatusFilter.active, child: Text('Active only')),
        PopupMenuItem(
            value: _LoanStatusFilter.closed, child: Text('Closed only')),
      ],
      child: wide
          ? Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: HomeColors.card(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomeColors.divider(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: statusFilter == _LoanStatusFilter.all
                        ? HomeColors.textSecondary(context)
                        : HomeColors.brand(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusFilter == _LoanStatusFilter.all
                          ? HomeColors.textSecondary(context)
                          : HomeColors.brand(context),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HomeColors.card(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomeColors.divider(context)),
              ),
              child: Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: statusFilter == _LoanStatusFilter.all
                    ? HomeColors.textSecondary(context)
                    : HomeColors.brand(context),
              ),
            ),
    );

    final searchField = wide
        ? SizedBox(
            width: 260,
            child: _SearchField(controller: searchController),
          )
        : (searchOpen
            ? _SearchField(controller: searchController)
            : const SizedBox.shrink());

    final searchToggle = Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggleSearch,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Icon(
            searchOpen ? Icons.close_rounded : Icons.search_rounded,
            size: 18,
            color: HomeColors.textSecondary(context),
          ),
        ),
      ),
    );

    if (wide) {
      return Row(
        children: [
          title,
          const Spacer(),
          searchField,
          const SizedBox(width: 10),
          filterMenu,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: title),
            searchToggle,
            const SizedBox(width: 8),
            filterMenu,
          ],
        ),
        if (searchOpen) ...[
          const SizedBox(height: 10),
          searchField,
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search Account',
        hintStyle: TextStyle(
          fontSize: 13,
          color: HomeColors.textSecondary(context),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: HomeColors.textSecondary(context),
        ),
        filled: true,
        fillColor: HomeColors.card(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.brand(context), width: 1.2),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.request_quote_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

/// Desktop/tablet table-style presentation of the loan list, matching the
/// "Your Accounts" table region in the wide UX spec.
class _LoanTable extends StatelessWidget {
  const _LoanTable({required this.loans});

  final List<LoanAccount> loans;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: _th(context, 'Loan')),
                Expanded(flex: 2, child: _th(context, 'Account Number')),
                Expanded(flex: 2, child: _th(context, 'Loan Holder')),
                Expanded(flex: 2, child: _th(context, 'Status')),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _th(context, 'Loan Amount'),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ),
          Divider(height: 1, color: HomeColors.divider(context)),
          for (var i = 0; i < loans.length; i++) ...[
            if (i > 0) Divider(height: 1, color: HomeColors.divider(context)),
            _LoanRow(loan: loans[i]),
          ],
        ],
      ),
    );
  }

  Widget _th(BuildContext context, String label) => Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: HomeColors.textSecondary(context),
        ),
      );
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({required this.loan});

  final LoanAccount loan;

  @override
  Widget build(BuildContext context) {
    final outstanding = loan.outstandingAmount;
    final currency = outstanding?.currency ?? loan.currencyCode;
    final amountText = outstanding == null
        ? '—'
        : MoneyFormat.format(outstanding.amount, currencyCode: currency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(context, loan),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: HomeColors.brand(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.request_quote_outlined,
                        color: HomeColors.brand(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: HomeColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  loan.displayNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  loan.holderName?.trim().isNotEmpty == true
                      ? loan.holderName!
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
              Expanded(flex: 2, child: _StatusBadge(status: loan.status)),
              Expanded(
                flex: 2,
                child: Text(
                  amountText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 20,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: HomeColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openDetails(BuildContext context, LoanAccount loan) {
  HapticFeedback.selectionClick();
  Navigator.of(context).pushNamed(
    RoutesConst.loanAccountDetailsScreen,
    arguments: LoanAccountDetailsArgs(loan: loan),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({this.status});

  final String? status;

  bool get _isActive {
    final s = (status ?? '').trim().toLowerCase();
    return s.isEmpty || s == 'active' || s == 'open' || s == 'a';
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final color = active ? HomeColors.success(context) : HomeColors.warning(context);
    final label = (status == null || status!.trim().isEmpty)
        ? (active ? 'Active' : 'Closed')
        : status!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Mobile card presentation of a single loan tile.
class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});

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
        onTap: () => _openDetails(context, loan),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: HomeColors.brand(context).withValues(alpha: 0.12),
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
                        _StatusBadge(status: loan.status),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: HomeColors.textSecondary(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: HomeColors.divider(context)),
              const SizedBox(height: 12),
              Text(
                l10n.loanOutstandingAmountLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: HomeColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Account Number',
                style: TextStyle(
                  fontSize: 11,
                  color: HomeColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loan.displayNumber,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              if (loan.holderName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Loan Holder',
                  style: TextStyle(
                    fontSize: 11,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loan.holderName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}