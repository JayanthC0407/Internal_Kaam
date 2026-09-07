import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_filter_sheet.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transaction_tile.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_transactions_table.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Statements offered when the host's `dda/v1/enumerations/mediatype`
/// (API-04) call is unavailable — mirrors the confirmed capture (csv, pdf,
/// qif, ofx) so the picker still works if that lookup ever fails.
const List<StatementFormat> _fallbackStatementFormats = [
  StatementFormat(code: 'csv', mimeType: 'text/csv', ordinal: 1),
  StatementFormat(code: 'pdf', mimeType: 'application/pdf', ordinal: 2),
  StatementFormat(code: 'qif', mimeType: 'application/qif', ordinal: 3),
  StatementFormat(code: 'ofx', mimeType: 'application/x-ofx', ordinal: 4),
];

class CasaAccountDetailsArgs {
  const CasaAccountDetailsArgs({required this.accountId});

  final String accountId;
}

/// CASA account details — "Accounts ▸ CASA ▸ [account]".
///
/// Flow (see CASA_API_Flow_Document): selecting an account from
/// [CasaAccountsListScreen] passes `accounts[].id.value` here, which then
/// drives:
///  - API-02 `GET demandDeposit/{accountId}` — account details.
///  - API-03 `GET demandDeposit?...&status=CLOSED` — background refresh of
///    the closed-inclusive account list (transaction-history flow).
///  - API-04 `GET enumerations/mediatype` — statement formats (lazily, when
///    "Download statement" is tapped).
///  - API-06 `GET demandDeposit/{accountId}/transactions` — recent
///    transactions shown inline below the balance.
class CasaAccountDetailsScreen extends ConsumerStatefulWidget {
  const CasaAccountDetailsScreen({
    super.key,
    required this.accountId,
    this.embedded = false,
    this.onBack,
  });

  final String accountId;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<CasaAccountDetailsScreen> createState() =>
      _CasaAccountDetailsScreenState();
}

class _CasaAccountDetailsScreenState
    extends ConsumerState<CasaAccountDetailsScreen> {
  late final String _accountId;
  bool _revealed = false;
  bool _downloadingStatement = false;
  CasaTransactionQuery _query = const CasaTransactionQuery();

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
      // API-03 — background refresh so the closed-inclusive account
      // universe stays warm for this transaction-history flow, per the doc.
      ref.read(casaAccountsProvider.notifier).refreshIncludingClosed();
      _loadSelected();
    });
  }

  void _loadSelected() {
    if (_accountId.isEmpty) return;
    // API-02
    ref.read(casaAccountDetailProvider(_accountId).notifier).load();
    // API-06
    ref.read(casaTransactionsProvider(_accountId).notifier).load(query: _query);
  }

  Future<void> _openFilter() async {
    final accounts =
        ref.read(casaAccountsProvider).summary?.accounts ?? const <CasaAccount>[];
    final result = await showCasaTransactionFilter(
      context: context,
      accounts: accounts,
      selectedAccountId: _accountId,
      query: _query,
    );
    if (!mounted || result == null) return;

    // This screen is opened for a single, fixed [_accountId] (it's a
    // `late final`); if the filter sheet's account dropdown is used to
    // switch accounts, route to that account's own details screen instead
    // of trying to mutate this one.
    if (result.accountId != _accountId) {
      setState(() => _query = result.query);
      Navigator.of(context).pushReplacementNamed(
        RoutesConst.casaAccountDetailsScreen,
        arguments: CasaAccountDetailsArgs(accountId: result.accountId),
      );
      return;
    }

    setState(() => _query = result.query);
    _loadSelected();
  }

  Future<void> _downloadStatement() async {
    if (_downloadingStatement) return;
    final l10n = AppLocalizations.of(context);

    // API-04 — ask the host which formats it actually supports before
    // offering a choice; fall back to the confirmed capture if unavailable.
    final formatsResult =
        await ref.read(accountsRepositoryProvider).fetchStatementFormats();
    if (!mounted) return;
    final formats = (formatsResult is Success<List<StatementFormat>> &&
            (formatsResult.data?.isNotEmpty ?? false))
        ? formatsResult.data!
        : _fallbackStatementFormats;

    final chosenFormat = await AppBottomSheet.pick<StatementFormat>(
      context: context,
      title: l10n.casaStatementFormatTitle,
      options: [for (final format in formats) (value: format, label: format.label)],
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
          _accountId,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    if (mounted) setState(() => _downloadingStatement = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final detailState = ref.watch(casaAccountDetailProvider(_accountId));
    final txState = ref.watch(casaTransactionsProvider(_accountId));
    final listState = ref.watch(casaAccountsProvider);
    final listAccount = _findAccount(
      listState.summary?.accounts ?? const <CasaAccount>[],
      _accountId,
    );
    final detail = detailState.detail;

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
                  title: l10n.accounts,
                  wide: wide,
                  onBack: widget.onBack,
                  trailing: wide
                      ? _downloadStatementButton(l10n)
                      : CasaIconButton(
                          tooltip: l10n.casaDownloadStatement,
                          onPressed:
                              _downloadingStatement ? null : _downloadStatement,
                          icon: Icons.download_rounded,
                        ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref
                          .read(casaAccountDetailProvider(_accountId).notifier)
                          .load(),
                      ref
                          .read(casaTransactionsProvider(_accountId).notifier)
                          .load(query: _query),
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
                      if (detailState.isLoading && detail == null)
                      _AccountDetailContainer(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (detailState.errorMessage != null && detail == null)
                      _AccountDetailContainer(
                        child: _ErrorContent(
                          message: detailState.errorMessage!,
                          onRetry: _loadSelected,
                        ),
                      )
                    else
                      _AccountHeaderCard(
                        detail: detail,
                        listAccount: listAccount,
                        fallbackId: _accountId,
                        revealed: _revealed,
                        onToggleReveal: () =>
                            setState(() => _revealed = !_revealed),
                        downloadingStatement: _downloadingStatement,
                        onDownloadStatement: _downloadStatement,
                        wide: wide,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            l10n.casaRecentTransactions,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.textPrimary(context),
                            ),
                          ),
                          const Spacer(),
                          CasaIconButton(
                            tooltip: l10n.filter,
                            onPressed: _openFilter,
                            icon: Icons.filter_alt_outlined,
                          ),
                        ],
                      ),
                      if (!_query.isDefault) ...[
                        const SizedBox(height: 6),
                        Text(
                          casaFilterSummary(l10n, _query),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (txState.isLoading && txState.result == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (txState.errorMessage != null &&
                        txState.result == null)
                      _RecentTransactionsError(
                        message: txState.errorMessage!,
                        onRetry: _loadSelected,
                      )
                      else
                        _TransactionsCard(
                          transactions: txState.result?.transactions ??
                              const <CasaTransaction>[],
                          wide: wide,
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

  Widget _downloadStatementButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: _downloadingStatement ? null : _downloadStatement,
      icon: _downloadingStatement
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 16),
      label: Text(l10n.casaDownloadStatement),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  CasaAccount? _findAccount(List<CasaAccount> accounts, String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }
}

class _AccountHeaderCard extends StatelessWidget {
  const _AccountHeaderCard({
    required this.detail,
    required this.listAccount,
    required this.fallbackId,
    required this.revealed,
    required this.onToggleReveal,
    required this.onDownloadStatement,
    required this.downloadingStatement,
    required this.wide,
  });

  final CasaAccountDetail? detail;
  final CasaAccount? listAccount;
  final String fallbackId;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onDownloadStatement;
  final bool downloadingStatement;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    final account = detail?.account ?? listAccount;

    final isDefault = account?.isDefault ?? false;

    final title = account?.title ?? l10n.savings;

    final currency =
        detail?.currencyCode ?? account?.currencyCode ?? '';

    final balance =
        detail?.displayBalance ?? account?.displayBalance;

    final balanceText = balance == null
        ? '—'
        : MoneyFormat.format(
            balance.amount,
            currencyCode: currency,
            hidden: !revealed,
          );

    final numberText = revealed
        ? (detail?.displayNumber ??
            account?.displayNumber ??
            fallbackId)
        : (account?.maskedNumber ?? _mask(fallbackId));

    final holder = detail?.primaryAccountHolder?.trim();

    final statusLabel = (account?.isDormant ?? false)
        ? l10n.accountStatusDormant
        : l10n.accountStatusActive;

    final isDormant = account?.isDormant ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 18 : 14),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9DD8E5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // TOP SECTION
          // ============================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: wide ? 52 : 42,
                height: wide ? 52 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  (account?.isSaving ?? true)
                      ? Icons.savings_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF007F9B),
                  size: wide ? 26 : 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: wide ? 16 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (isDefault) ...[
                          const SizedBox(width: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRIMARY',
                              style: TextStyle(
                                color: Color(0xFF007F9B),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          l10n.availableBalanceLabel,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(width: 6),

                        InkWell(
                          onTap: onToggleReveal,
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            revealed
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 14,
                            color: const Color(0xFF007F9B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      balanceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: wide ? 24 : 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              if (wide)
                _downloadButton(context),
            ],
          ),

          if (!wide) ...[
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: _downloadButton(context),
            ),
          ],

          const SizedBox(height: 14),

          Divider(
            height: 1,
            color: colors.divider,
          ),

          const SizedBox(height: 14),

          // ============================================================
          // ACCOUNT INFORMATION
          // ============================================================
          wide
              ? Row(
                  children: [
                    Expanded(
                      child: _AccountMeta(
                        label: l10n.casaAccountNumberLabel,
                        value: numberText,
                        copyValue: detail?.displayNumber ??
                            account?.displayNumber ??
                            fallbackId,
                      ),
                    ),

                    _verticalDivider(colors),

                    Expanded(
                      child: _AccountMeta(
                        label: l10n.casaPrimaryAccountHolder,
                        value: holder != null && holder.isNotEmpty
                            ? holder
                            : '—',
                      ),
                    ),

                    _verticalDivider(colors),

                    Expanded(
                      child: _AccountMeta(
                        label: l10n.tableStatus,
                        value: statusLabel,
                        valueColor: isDormant
                            ? AppColors.warningColor
                            : AppColors.successColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountMeta(
                      label: l10n.casaAccountNumberLabel,
                      value: numberText,
                      copyValue: detail?.displayNumber ??
                          account?.displayNumber ??
                          fallbackId,
                    ),

                    const SizedBox(height: 12),

                    _AccountMeta(
                      label: l10n.casaPrimaryAccountHolder,
                      value: holder != null && holder.isNotEmpty
                          ? holder
                          : '—',
                    ),

                    const SizedBox(height: 12),

                    _AccountMeta(
                      label: l10n.tableStatus,
                      value: statusLabel,
                      valueColor: isDormant
                          ? AppColors.warningColor
                          : AppColors.successColor,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _downloadButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OutlinedButton.icon(
      onPressed:
          downloadingStatement ? null : onDownloadStatement,
      icon: const Icon(
        Icons.download_rounded,
        size: 16,
      ),
      label: Text(l10n.casaDownloadStatement),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF007F9B),
        side: const BorderSide(
          color: Color(0xFF007F9B),
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
  }

  Widget _verticalDivider(AppColors colors) {
    return Container(
      width: 1,
      height: 48,
      color: colors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  static String _mask(String id) {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length <= 4) return id;

    return '${'*' * (digits.length - 4)}'
        '${digits.substring(digits.length - 4)}';
  }
}

class _AccountMeta extends StatelessWidget {
  const _AccountMeta({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyValue,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? copyValue;

  Future<void> _copy(BuildContext context) async {
    final text = copyValue ?? value;

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 5),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (copyValue != null) ...[
              const SizedBox(width: 6),

              InkWell(
                onTap: () => _copy(context),
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: const Color(0xFF007F9B),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyValue,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// When set, shows a copy-to-clipboard icon next to the value (copies
  /// this value rather than the masked/displayed [value]).
  final String? copyValue;

  Future<void> _copy(BuildContext context) async {
    final text = copyValue ?? value;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (copyValue != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _copy(context),
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Full filtered transaction list — table on wide layouts, tiles on mobile.
/// Replaces the old "recent + View All" pattern now that this screen
/// hosts the filter in place instead of pushing a separate screen.
class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({
    required this.transactions,
    required this.wide,
  });

  final List<CasaTransaction> transactions;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
        ),
        child: Text(
          l10n.casaTransactionsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      );
    }

    if (wide) {
      return CasaTransactionsTable(transactions: transactions);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.divider),
            CasaTransactionTile(transaction: transactions[i]),
          ],
        ],
      ),
    );
  }
}

class _AccountDetailContainer extends StatelessWidget {
  const _AccountDetailContainer({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 190,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9DD8E5),
        ),
      ),
      child: child,
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 28,
          color: Color(0xFF666666),
        ),

        const SizedBox(height: 10),

        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: 10),

        TextButton(
          onPressed: onRetry,
          child: Text(
            l10n.accountsRetry,
            style: const TextStyle(
              color: Color(0xFF007F9B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTransactionsError extends StatelessWidget {
  const _RecentTransactionsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.divider,
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(
              l10n.accountsRetry,
              style: const TextStyle(
                color: Color(0xFF007F9B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}
