import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_account_detail.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_primary_button.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

class CasaAccountDetailsArgs {
  const CasaAccountDetailsArgs({required this.accountId});

  final String accountId;
}

class CasaAccountDetailsScreen extends ConsumerStatefulWidget {
  const CasaAccountDetailsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<CasaAccountDetailsScreen> createState() =>
      _CasaAccountDetailsScreenState();
}

class _CasaAccountDetailsScreenState
    extends ConsumerState<CasaAccountDetailsScreen> {
  late String _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.accountId.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
      _loadSelected();
    });
  }

  void _loadSelected() {
    final id = _selectedAccountId.trim();
    if (id.isEmpty) return;
    ref.read(casaAccountDetailProvider(id).notifier).load();
  }

  void _onAccountChanged(String? id) {
    final next = id?.trim();
    if (next == null || next.isEmpty || next == _selectedAccountId) return;
    setState(() => _selectedAccountId = next);
    // New family instance — load after frame so watch rebuilds first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountDetailProvider(next).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final detailState = ref.watch(casaAccountDetailProvider(_selectedAccountId));
    final listState = ref.watch(casaAccountsProvider);
    final accounts = listState.summary?.accounts ?? const <CasaAccount>[];

    // Keep dropdown selection aligned once the CASA list arrives.
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
    });

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
                      ? l10n.casaAccountDetailsTitleWeb
                      : l10n.casaAccountDetailsTitle,
                  wide: wide,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadSelected(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      8,
                      wide ? 28 : 16,
                      28,
                    ),
                    children: [
                      Text(
                        l10n.casaAccountNumberLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CasaAccountDropdown(
                        accounts: accounts,
                        selectedId: _selectedAccountId,
                        onChanged: _onAccountChanged,
                      ),
                      const SizedBox(height: 16),
                      if (detailState.isLoading && detailState.detail == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (detailState.errorMessage != null &&
                          detailState.detail == null)
                        _ErrorCard(
                          message: detailState.errorMessage!,
                          onRetry: _loadSelected,
                        )
                      else if (detailState.detail != null)
                        _DetailBody(
                          key: ValueKey(_selectedAccountId),
                          detail: detailState.detail!,
                          wide: wide,
                          onViewTransactions: () {
                            Navigator.of(context).pushNamed(
                              RoutesConst.casaTransactionsScreen,
                              arguments: CasaTransactionsArgs(
                                accountId: _selectedAccountId,
                              ),
                            );
                          },
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
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    super.key,
    required this.detail,
    required this.wide,
    required this.onViewTransactions,
  });

  final CasaAccountDetail detail;
  final bool wide;
  final VoidCallback onViewTransactions;

  String _money(MoneyAmount? amount, String currencyFallback) {
    if (amount == null) {
      return MoneyFormat.format(0, currencyCode: currencyFallback);
    }
    return MoneyFormat.format(
      amount.amount,
      currencyCode: amount.currency ?? currencyFallback,
    );
  }

  String _textOr(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  String _nomineeValue(CasaAccountDetail detail, AppLocalizations l10n) {
    final named = detail.nominee?.trim();
    if (named != null && named.isNotEmpty) return named;
    if (detail.nomineeRegistered == false) return l10n.casaNotRegistered;
    if (detail.nomineeRegistered == true) return l10n.casaNotAssigned;
    return l10n.casaNotRegistered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = detail.currencyCode;
    final nickname = detail.nicknameOrDefault.isEmpty
        ? l10n.casaNotAssigned
        : detail.nicknameOrDefault;
    final product = _textOr(detail.productName, '—');
    final opening = _money(
      detail.todaysOpeningBalance ??
          detail.displayBalance ??
          detail.currentBalance,
      currency,
    );
    final current = _money(
      detail.displayBalance ?? detail.currentBalance,
      currency,
    );

    final Widget banner;
    if (wide) {
      banner = CasaBrandBanner(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BannerMeta(
                  label: l10n.casaOpeningBalance,
                  value: opening,
                  valueSize: 18,
                ),
              ),
              Expanded(
                child: _BannerMeta(
                  label: l10n.casaProductName,
                  value: product,
                  valueSize: 16,
                ),
              ),
              Expanded(
                child: _BannerMeta(
                  label: l10n.casaNickName,
                  value: nickname,
                  valueSize: 16,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      banner = CasaBrandBanner(
        children: [
          _BannerMeta(
            label: l10n.casaCurrentBalance,
            value: current,
            valueSize: 20,
          ),
          const SizedBox(height: 12),
          _BannerMeta(label: l10n.casaProductName, value: product),
          const SizedBox(height: 8),
          _BannerMeta(label: l10n.casaNickName, value: nickname),
        ],
      );
    }

    final balanceCard = CasaSectionCard(
      title: l10n.casaBalanceDetails,
      child: _TwoColGrid(
        children: [
          CasaDetailField(
            label: l10n.casaTodaysOpeningBalance,
            value: _money(detail.todaysOpeningBalance, currency),
          ),
          CasaDetailField(
            label: l10n.casaAvailableBalance,
            value: _money(detail.availableBalance, currency),
          ),
          CasaDetailField(
            label: l10n.casaAmountOnHold,
            value: _money(detail.amountOnHold, currency),
          ),
          CasaDetailField(
            label: l10n.casaUnderFunds,
            value: _money(detail.underClearingFunds, currency),
          ),
          CasaDetailField(
            label: l10n.casaAdvanceAgainstUnclearFunds,
            value: _money(detail.advanceAgainstUnclearFunds, currency),
          ),
          CasaDetailField(
            label: l10n.casaOverdraftLimit,
            value: _money(detail.overdraftLimit, currency),
          ),
          CasaDetailField(
            label: l10n.casaSweepInAmount,
            value: _money(detail.sweepInAmount, currency),
          ),
        ],
      ),
    );

    final generalCard = CasaSectionCard(
      title: l10n.casaGeneralDetails,
      child: _TwoColGrid(
        children: [
          CasaDetailField(
            label: l10n.casaHoldingPattern,
            value: _textOr(detail.holdingPattern, '—'),
          ),
          CasaDetailField(
            label: l10n.casaPrimaryAccountHolder,
            value: _textOr(detail.primaryAccountHolder, '—'),
          ),
          CasaDetailField(
            label: l10n.casaNominee,
            value: _nomineeValue(detail, l10n),
          ),
          CasaDetailField(
            label: l10n.casaBranch,
            value: _textOr(detail.branch, '—'),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner,
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: balanceCard),
              const SizedBox(width: 16),
              Expanded(child: generalCard),
            ],
          )
        else ...[
          balanceCard,
          const SizedBox(height: 12),
          generalCard,
        ],
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: l10n.casaViewTransactions,
          onPressed: onViewTransactions,
        ),
      ],
    );
  }
}

class _BannerMeta extends StatelessWidget {
  const _BannerMeta({
    required this.label,
    required this.value,
    this.valueSize = 14,
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: valueSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _TwoColGrid extends StatelessWidget {
  const _TwoColGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Design: two-column label/value pairs on all sizes.
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}
