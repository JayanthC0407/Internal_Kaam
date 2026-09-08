import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/core/models/statement_format.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/core/utils/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/accounts_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_filter_sheet.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_tile.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transactions_table.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Statements are always offered in this order/set when the host's
/// `dda/v1/enumerations/mediatype` call is unavailable — mirrors the
/// confirmed capture (csv, pdf, qif, ofx) so the picker still works if
/// that lookup ever fails.
const List<StatementFormat> _fallbackStatementFormats = [
  StatementFormat(code: 'csv', mimeType: 'text/csv', ordinal: 1),
  StatementFormat(code: 'pdf', mimeType: 'application/pdf', ordinal: 2),
  StatementFormat(code: 'qif', mimeType: 'application/qif', ordinal: 3),
  StatementFormat(code: 'ofx', mimeType: 'application/x-ofx', ordinal: 4),
];

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

  Future<void> _downloadStatement() async {
    if (_downloadingStatement) return;
    final l10n = AppLocalizations.of(context);

    // Ask the host which formats it actually supports before offering a
    // choice; fall back to the confirmed capture if that lookup fails
    // rather than blocking the whole flow.
    final formatsResult =
        await ref.read(accountsRepositoryProvider).fetchStatementFormats();
    if (!mounted) return;
    final formats =
        (formatsResult is Success<List<StatementFormat>> &&
                (formatsResult.data?.isNotEmpty ?? false))
            ? formatsResult.data!
            : _fallbackStatementFormats;

    final chosenFormat = await AppBottomSheet.pick<StatementFormat>(
      context: context,
      title: l10n.casaStatementFormatTitle,
      options: [
        for (final format in formats)
          (value: format, label: format.label),
      ],
      selected: formats.first,
    );
    if (chosenFormat == null || !mounted) return;

    final proceed = await AppBottomSheet.confirm(
      context,
      title: l10n.casaStatementPasswordTitle,
      message: [
        l10n.casaStatementPasswordBody,
        l10n.casaStatementPasswordExample1,
        l10n.casaStatementPasswordExample2,
      ].join('\n\n'),
      confirmLabel: l10n.casaStatementPasswordContinue,
    );
    if (!proceed || !mounted) return;

    setState(() => _downloadingStatement = true);

    final result = await ref.read(accountsRepositoryProvider).downloadStatement(
          _selectedAccountId,
          format: chosenFormat,
          query: _query,
        );

    if (!mounted) return;

    if (result is Success<StatementFile> && result.data != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        await StatementFileSaver.saveStatement(
          bytes: result.data!.bytes,
          fileName: result.data!.fileName,
          mimeType: result.data!.mimeType,
          sharePositionOrigin: origin,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.casaStatementDownloadSuccess)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.casaStatementDownloadFailed)),
        );
      }
    } else if (!SessionExpiryCoordinator.instance.isHandling) {
      final message = result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.casaStatementDownloadFailed,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (mounted) setState(() => _downloadingStatement = false);
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
                  onRefresh: () async {
                    await Future.wait([
                      ref
                          .read(
                            casaTransactionsProvider(_selectedAccountId)
                                .notifier,
                          )
                          .load(query: _query),
                      ref
                          .read(
                            casaAccountDetailProvider(_selectedAccountId)
                                .notifier,
                          )
                          .load(),
                    ]);
                  },
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
                      else if (wide)
                        CasaTransactionsTable(
                          transactions: result!.transactions,
                        )
                      else
                        _TransactionsCard(
                          transactions: result!.transactions,
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
              CasaTransactionTile(transaction: transactions[i]),
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
