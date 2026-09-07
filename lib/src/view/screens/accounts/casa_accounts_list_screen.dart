import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// CASA landing screen — "Accounts" ▸ "CASA" from the side panel / nav
/// drawer.
///
/// Flow (see CASA_API_Flow_Document): Accounts filter → Current & Saving
/// → API-01 `GET demandDeposit?accountType=CURRENT,SAVING&status=ACTIVE&
/// status=DORMANT` → display list. Tapping an account opens
/// [CasaAccountDetailsScreen] for API-02 + the transaction-history flow.
class CasaAccountsListScreen extends ConsumerStatefulWidget {
  const CasaAccountsListScreen({
    super.key,
    this.embedded = false,
    this.onAccountSelected,
    this.onBack,
  });

  final bool embedded;
  final ValueChanged<CasaAccount>? onAccountSelected;
  final VoidCallback? onBack;

  @override
  ConsumerState<CasaAccountsListScreen> createState() =>
      _CasaAccountsListScreenState();
}

class _CasaAccountsListScreenState
    extends ConsumerState<CasaAccountsListScreen> {
  bool _hideTotalBalance = false;
  final Set<String> _revealedAccountIds = <String>{};
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  void _toggleAccountVisibility(String id) {
    setState(() {
      if (_revealedAccountIds.contains(id)) {
        _revealedAccountIds.remove(id);
      } else {
        _revealedAccountIds.add(id);
      }
    });
  }

 void _openAccount(CasaAccount account) {
  if (account.id.isEmpty) return;

  HapticFeedback.selectionClick();

  if (widget.embedded && widget.onAccountSelected != null) {
    widget.onAccountSelected!(account);
    return;
  }

  Navigator.of(context).pushNamed(
    RoutesConst.casaAccountDetailsScreen,
    arguments: CasaAccountDetailsArgs(accountId: account.id),
  );
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final state = ref.watch(casaAccountsProvider);
    final allAccounts = state.summary?.accounts ?? const <CasaAccount>[];
    final search = _search.trim().toLowerCase();
    final accounts = search.isEmpty
        ? allAccounts
        : allAccounts.where((a) {
            return a.title.toLowerCase().contains(search) ||
                a.displayNumber.toLowerCase().contains(search) ||
                a.maskedNumber.toLowerCase().contains(search);
          }).toList(growable: false);

    final currentAccounts =
        allAccounts.where((a) => a.isCurrent).toList(growable: false);
    final savingAccounts =
        allAccounts.where((a) => a.isSaving).toList(growable: false);

    return Scaffold(
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
                0,
              ),
              child: CasaScreenHeader(title: l10n.accounts, wide: wide, onBack: widget.onBack),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(casaAccountsProvider.notifier).refresh(),
                child: _buildBody(
                  context,
                  l10n,
                  wide: wide,
                  state: state,
                  allAccounts: allAccounts,
                  currentAccounts: currentAccounts,
                  savingAccounts: savingAccounts,
                  accounts: accounts,
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
    AppLocalizations l10n, {
    required bool wide,
    required CasaAccountsState state,
    required List<CasaAccount> allAccounts,
    required List<CasaAccount> currentAccounts,
    required List<CasaAccount> savingAccounts,
    required List<CasaAccount> accounts,
  }) {
    if (state.isLoading && allAccounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && allAccounts.isEmpty) {
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
                  ref.read(casaAccountsProvider.notifier).refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 28),
      children: [
        Text(
          'All Accounts',
          style: TextStyle(
            fontSize: wide ? 20 : 17,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View and manage all your CASA accounts.',
          style: TextStyle(
            fontSize: 12,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.accountCategoryCurrentSavings,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          wide: wide,
          hideBalance: _hideTotalBalance,
          onToggleHide: () =>
              setState(() => _hideTotalBalance = !_hideTotalBalance),
          totalCurrency: state.summary?.primaryCurrency,
          totalAmount: state.summary?.primaryTotal,
          accountCount: allAccounts.length,
          currentAccounts: currentAccounts,
          savingAccounts: savingAccounts,
        ),
        const SizedBox(height: 20),
        if (wide)
          Row(
            children: [
              Text(
                'Your Accounts (${allAccounts.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.searchPlaceholder,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: HomeColors.card(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.divider(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.divider(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.brand(context),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Accounts (${allAccounts.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.searchPlaceholder,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: HomeColors.card(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.divider(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.divider(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeColors.brand(context),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                l10n.accountsEmpty,
                style: TextStyle(color: HomeColors.textSecondary(context)),
              ),
            ),
          )
        else
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _AccountListTile(
              account: accounts[i],
              revealed: _revealedAccountIds.contains(accounts[i].id),
              onToggleVisibility: () =>
                  _toggleAccountVisibility(accounts[i].id),
              onTap: () => _openAccount(accounts[i]),
              wide: wide,
            ),
          ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.wide,
    required this.hideBalance,
    required this.onToggleHide,
    required this.totalCurrency,
    required this.totalAmount,
    required this.accountCount,
    required this.currentAccounts,
    required this.savingAccounts,
  });

  final bool wide;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final String? totalCurrency;
  final double? totalAmount;
  final int accountCount;
  final List<CasaAccount> currentAccounts;
  final List<CasaAccount> savingAccounts;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      Expanded(
        flex: wide ? 3 : 0,
        child: _TotalBalanceTile(
          hideBalance: hideBalance,
          onToggleHide: onToggleHide,
          currency: totalCurrency,
          amount: totalAmount,
          accountCount: accountCount,
        ),
      ),
      SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 12),
      Expanded(
        child: _CategoryTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Current Account',
          accounts: currentAccounts,
          hideBalance: hideBalance,
        ),
      ),
      SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 12),
      Expanded(
        child: _CategoryTile(
          icon: Icons.savings_outlined,
          label: 'Savings Account',
          accounts: savingAccounts,
          hideBalance: hideBalance,
        ),
      ),
    ];

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalBalanceTile(
            hideBalance: hideBalance,
            onToggleHide: onToggleHide,
            currency: totalCurrency,
            amount: totalAmount,
            accountCount: accountCount,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Current Account',
                  accounts: currentAccounts,
                  hideBalance: hideBalance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CategoryTile(
                  icon: Icons.savings_outlined,
                  label: 'Savings Account',
                  accounts: savingAccounts,
                  hideBalance: hideBalance,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return IntrinsicHeight(child: Row(children: tiles));
  }
}

class _TotalBalanceTile extends StatelessWidget {
  const _TotalBalanceTile({
    required this.hideBalance,
    required this.onToggleHide,
    required this.currency,
    required this.amount,
    required this.accountCount,
  });

  final bool hideBalance;
  final VoidCallback onToggleHide;
  final String? currency;
  final double? amount;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = (currency == null || amount == null)
        ? '—'
        : MoneyFormat.format(amount!, currencyCode: currency!, hidden: hideBalance);

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087C91),
            Color(0xFF176A9A),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // ─────────────────────────────────────
          // DECORATIVE CURVED CIRCLES
          // ─────────────────────────────────────

          Positioned(
            left: -80,
            top: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            top: -120,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          ),

          Positioned(
            right: -100,
            bottom: -150,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
          ),

          // ─────────────────────────────────────
          // CARD CONTENT
          // ─────────────────────────────────────

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.totalBalance,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const Spacer(),

                    InkWell(
                      onTap: onToggleHide,
                      borderRadius: BorderRadius.circular(14),
                      child: Icon(
                        hideBalance
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                Text(
                  '$accountCount ${accountCount == 1 ? 'Account' : 'Accounts'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.accounts,
    required this.hideBalance,
  });

  final IconData icon;
  final String label;
  final List<CasaAccount> accounts;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final currency = accounts.isNotEmpty
        ? (accounts.first.displayBalance?.currency ?? accounts.first.currencyCode)
        : null;
    final total = accounts.fold<double>(
      0,
      (sum, a) => sum + (a.displayBalance?.amount ?? 0),
    );
    final text = accounts.isEmpty
        ? '—'
        : MoneyFormat.format(total, currencyCode: currency ?? '', hidden: hideBalance);

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.teal50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: HomeColors.brand(context)),
          ),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: HomeColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  const _AccountListTile({
    required this.account,
    required this.revealed,
    required this.onToggleVisibility,
    required this.onTap,
    required this.wide,
  });

  final CasaAccount account;
  final bool revealed;
  final VoidCallback onToggleVisibility;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final balance = account.displayBalance;
    final currency = balance?.currency ?? account.currencyCode;

    final amountText = balance == null
        ? '—'
        : MoneyFormat.format(
            balance.amount,
            currencyCode: currency,
            hidden: !revealed,
          );

    final statusLabel = account.isDormant
        ? l10n.accountStatusDormant
        : l10n.accountStatusActive;

    final numberText =
        revealed ? account.displayNumber : account.maskedNumber;

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: HomeColors.divider(context),
            ),
          ),
          child: wide
              ? _buildWideLayout(
                  context,
                  l10n,
                  numberText,
                  amountText,
                  statusLabel,
                )
              : _buildMobileLayout(
                  context,
                  l10n,
                  numberText,
                  amountText,
                  statusLabel,
                ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AppLocalizations l10n,
    String numberText,
    String amountText,
    String statusLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─────────────────────────────────────
        // TITLE + PRIMARY + ARROW
        // ─────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      account.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ),

                  if (account.isDefault) ...[
                    const SizedBox(width: 8),
                    _PrimaryBadge(),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: HomeColors.textPrimary(context),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ─────────────────────────────────────
        // ACCOUNT NUMBER
        // ─────────────────────────────────────
        Text(
          l10n.casaAccountNumberLabel,
          style: TextStyle(
            fontSize: 10,
            color: HomeColors.textSecondary(context),
          ),
        ),

        const SizedBox(height: 3),

        Row(
          children: [
            Flexible(
              child: Text(
                numberText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),

            const SizedBox(width: 5),

            InkWell(
              onTap: onToggleVisibility,
              borderRadius: BorderRadius.circular(4),
              child: Icon(
                revealed
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 15,
                color: HomeColors.textSecondary(context),
              ),
            ),

            const SizedBox(width: 5),

            InkWell(
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: account.displayNumber,
                  ),
                );

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Icon(
                Icons.copy_rounded,
                size: 14,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ─────────────────────────────────────
        // AVAILABLE BALANCE
        // ─────────────────────────────────────
        Text(
          l10n.availableBalanceLabel,
          style: TextStyle(
            fontSize: 10,
            color: HomeColors.textSecondary(context),
          ),
        ),

        const SizedBox(height: 3),

        Text(
          amountText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: HomeColors.textPrimary(context),
          ),
        ),

        const SizedBox(height: 12),

        // ─────────────────────────────────────
        // HOLDER + STATUS
        // ─────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.casaPrimaryAccountHolder,
                    style: TextStyle(
                      fontSize: 10,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tableStatus,
                    style: TextStyle(
                      fontSize: 10,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: account.isDormant
                          ? AppColors.warningColor.withValues(alpha: 0.12)
                          : AppColors.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: account.isDormant
                            ? AppColors.warningColor
                            : AppColors.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    AppLocalizations l10n,
    String numberText,
    String amountText,
    String statusLabel,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      account.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ),
                  if (account.isDefault) ...[
                    const SizedBox(width: 6),
                    _PrimaryBadge(),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              Text(
                l10n.casaAccountNumberLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: HomeColors.textSecondary(context),
                ),
              ),

              const SizedBox(height: 3),

              Row(
                children: [
                  Text(
                    numberText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onToggleVisibility,
                    child: Icon(
                      revealed
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 14,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: account.displayNumber,
                        ),
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: account.isDormant
                      ? AppColors.warningColor
                      : AppColors.successColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 20),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.availableBalanceLabel,
              style: TextStyle(
                fontSize: 10,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amountText,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: HomeColors.textSecondary(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PRIMARY',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: HomeColors.brand(context),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
