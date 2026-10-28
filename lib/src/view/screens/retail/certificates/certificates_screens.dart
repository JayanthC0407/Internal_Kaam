import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/repositories/retail/certificates_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/retail/certificates_providers.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// OBDX Accounts → Certificates (`retail.json:197-211`): Interest, Balance
/// and TDS Certificates, in the designer's layout (UI designs 2,
/// 2026-10-27): the choices in a card with Apply (and Reset for Interest,
/// as OBDX and the mock — user decision), then a teal band with Download
/// (PDF, OBDX's only format) and the table. Evidence and the app's fixes
/// of OBDX defects: docs/obdx/features/certificates.md.

/// The module page with the three certificates.
class CertificatesHubScreen extends StatelessWidget {
  const CertificatesHubScreen({
    super.key,
    required this.onInterestTap,
    required this.onBalanceTap,
    required this.onTdsTap,
  });

  final VoidCallback onInterestTap;
  final VoidCallback onBalanceTap;
  final VoidCallback onTdsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleHubPage(
      title: l10n.certMenuTitle,
      subtitle: l10n.certHubSubtitle,
      tiles: [
        PayOptionTile(
          icon: Icons.percent_rounded,
          title: l10n.certInterestTitle,
          subtitle: l10n.certInterestDesc,
          onTap: onInterestTap,
        ),
        PayOptionTile(
          icon: Icons.account_balance_outlined,
          title: l10n.certBalanceTitle,
          subtitle: l10n.certBalanceDesc,
          onTap: onBalanceTap,
        ),
        PayOptionTile(
          icon: Icons.receipt_long_rounded,
          title: l10n.certTdsTitle,
          subtitle: l10n.certTdsDesc,
          onTap: onTdsTap,
        ),
      ],
      comingSoon: const [],
    );
  }
}

String _money(MoneyAmount? m) => m == null ? '' : MoneyFormat.format(m.amount, currencyCode: m.currency ?? '');

Widget _loading() => const PayCard(
      child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
    );

Widget _failed(AppLocalizations l10n, Object error, VoidCallback retry) => PayErrorRetry(
      message: error is CertificatesLoadError && error.message != null ? error.message! : l10n.certLoadFailed,
      onRetry: retry,
    );

/// Saves a certificate PDF (shared statement decoder and saver).
Future<void> _download(
  BuildContext context,
  Future<ResponseHandler<StatementFile>> Function() fetch,
  ValueChanged<bool> busy,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  busy(true);
  final result = await fetch();
  busy(false);
  if (result is Success<StatementFile> && result.data != null) {
    try {
      await StatementFileSaver.saveStatement(
        bytes: result.data!.bytes,
        fileName: result.data!.fileName,
        mimeType: result.data!.mimeType,
      );
      snack(l10n.casaStatementDownloadSuccess);
    } catch (_) {
      snack(l10n.casaStatementDownloadFailed);
    }
  } else if (!SessionExpiryCoordinator.instance.isHandling) {
    snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.casaStatementDownloadFailed));
  }
}

/// The design's teal band: what the certificate is for, and Download.
class _ResultBand extends StatelessWidget {
  const _ResultBand({required this.parts, required this.onDownload, required this.downloading});

  final List<String> parts;
  final VoidCallback? onDownload;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 4,
              children: [
                for (final (i, p) in parts.indexed)
                  Text(
                    p,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == 0 ? brand : HomeColors.textPrimary(context),
                    ),
                  ),
              ],
            ),
          ),
          if (onDownload != null)
            downloading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(l10n.certDownload),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: HomeColors.card(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
        ],
      ),
    );
  }
}

/// A table on web (grey header row), label/value cards on a phone.
class _CertificateTable extends StatelessWidget {
  const _CertificateTable({required this.wide, required this.columns, required this.rows});

  final bool wide;

  /// (label, flex, right-aligned).
  final List<(String, int, bool)> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final primary = HomeColors.textPrimary(context);
    final brand = HomeColors.brand(context);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            PayCard(
              padding: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (c, (label, _, _)) in columns.indexed)
                    if (row[c].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(label, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                row[c],
                                textAlign: TextAlign.end,
                                style: TextStyle(fontWeight: FontWeight.w600, color: c == 0 ? brand : primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return PayCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PayTableHeader(cells: [for (final (label, flex, _) in columns) (label, flex)]),
          for (final (i, row) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
              ),
              child: Row(
                children: [
                  for (final (c, (_, flex, end)) in columns.indexed)
                    Expanded(
                      flex: flex,
                      child: Text(
                        row[c],
                        textAlign: end ? TextAlign.end : TextAlign.start,
                        style: TextStyle(fontWeight: FontWeight.w600, color: c == 0 ? brand : primary),
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

/// Apply (and Reset) under the choices.
Widget _actions(AppLocalizations l10n, {required VoidCallback onApply, VoidCallback? onReset}) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 12,
        children: [
          if (onReset != null) SizedBox(width: 130, child: PaySecondaryButton(label: l10n.certReset, onPressed: onReset)),
          SizedBox(width: 130, child: PayPrimaryButton(label: l10n.certApply, onPressed: onApply)),
        ],
      ),
    );

/// Two choices side by side from 560 px.
Widget _pair(Widget a, Widget? b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: a), const SizedBox(width: 20), Expanded(child: b ?? const SizedBox.shrink())],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [a, if (b != null) ...[const SizedBox(height: 14), b]],
            ),
    );

Widget _radioRow<T>(BuildContext context, String title, List<(T, String)> options, T selected, ValueChanged<T> onChanged) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context))),
        const SizedBox(height: 8),
        PaySegmented<T>(options: options, selected: selected, onChanged: onChanged),
      ],
    );

// ── Interest Certificates ────────────────────────────────────────────────

/// OBDX `interest-certificate-all`. [roles] are the login profile's
/// `userProfile.roles`; they decide the Account Category options.
class InterestCertificatesScreen extends ConsumerStatefulWidget {
  const InterestCertificatesScreen({super.key, required this.roles, this.embedded = false, this.onBack});

  final List<String> roles;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<InterestCertificatesScreen> createState() => _InterestCertificatesScreenState();
}

class _InterestCertificatesScreenState extends ConsumerState<InterestCertificatesScreen> {
  CertificateCategory? _category;
  bool _all = false;
  CertificateAccount? _account;
  bool _duration = false;
  FinancialYear? _year;
  DateTime? _from;
  DateTime? _to;
  bool _showErrors = false;
  InterestQuery? _query;
  bool _downloading = false;

  String _categoryLabel(AppLocalizations l10n, CertificateCategory c) => switch (c) {
        CertificateCategory.casa => l10n.certCategoryCasa,
        CertificateCategory.deposits => l10n.certCategoryDeposits,
        CertificateCategory.loans => l10n.certCategoryLoans,
      };

  List<CertificateCategory> _categories(AppLocalizations l10n) => CertificateCategory.fromRoles(widget.roles)
    ..sort((a, b) => _categoryLabel(l10n, a).compareTo(_categoryLabel(l10n, b)));

  /// OBDX Reset (hooks.js:390-406): the first category, Specific Account,
  /// Financial year, nothing chosen, no result.
  void _reset() => setState(() {
        _category = null;
        _all = false;
        _account = null;
        _duration = false;
        _year = null;
        _from = null;
        _to = null;
        _showErrors = false;
        _query = null;
      });

  void _apply(CertificateCategory category, DateTime branchDate) {
    final account = _all ? null : _account;
    final complete = (_all || account != null) && (_duration ? _from != null && _to != null : _year != null);
    if (!complete) {
      setState(() => _showErrors = true);
      return;
    }
    final (from, to) = _duration ? (certificateDate(_from!), certificateDate(_to!)) : _year!.range(branchDate);
    setState(() {
      _showErrors = false;
      _query = InterestQuery(category: category, account: account, fromDate: from, toDate: to);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _categories(l10n);
    return PayMenuPage(
      title: l10n.certInterestTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        if (categories.isEmpty) return PayCard(child: PayMuted(l10n.certNoneAvailable));
        final category = _category ?? categories.first;
        return ref.watch(certificateBranchDateProvider).when(
              loading: _loading,
              error: (e, _) => _failed(l10n, e, () => ref.invalidate(certificateBranchDateProvider)),
              data: (branchDate) => _body(l10n, wide, categories, category, branchDate),
            );
      },
    );
  }

  Widget _body(
    AppLocalizations l10n,
    bool wide,
    List<CertificateCategory> categories,
    CertificateCategory category,
    DateTime branchDate,
  ) {
    final accounts = ref.watch(certificateAccountsProvider(category));
    final list = accounts.valueOrNull;
    // OBDX's account-input starts on the default account, else the first.
    final account = _account != null && (list?.any((a) => a.id == _account!.id) ?? false)
        ? _account
        : (list == null ? null : CertificateAccount.initial(list));
    final years = FinancialYear.list(branchDate);
    final earliest = certificateEarliestDate(branchDate);

    final categoryField = PayBoxedPicker(
      label: l10n.certAccountCategory,
      value: _categoryLabel(l10n, category),
      onTap: categories.length < 2
          ? null
          : () async {
              final picked = await showPayPicker<CertificateCategory>(
                context,
                title: l10n.certAccountCategory,
                selected: category,
                options: [for (final c in categories) PayOption(value: c, title: _categoryLabel(l10n, c))],
              );
              if (picked != null && picked != category && mounted) {
                setState(() {
                  _category = picked;
                  _account = null;
                });
              }
            },
    );
    final accountField = accounts.hasError
        ? _failed(l10n, accounts.error!, () => ref.invalidate(certificateAccountsProvider(category)))
        : PayBoxedPicker(
            label: l10n.certAccountNumber,
            required: true,
            loading: list == null,
            value: account?.display,
            placeholder: l10n.addBillerSelect,
            error: _showErrors && account == null ? l10n.addBillerFieldRequired(l10n.certAccountNumber) : null,
            onTap: list == null || list.isEmpty
                ? null
                : () async {
                    final picked = await showPayPicker<String>(
                      context,
                      title: l10n.certAccountNumber,
                      selected: account?.id,
                      options: [for (final a in list) PayOption(value: a.id, title: a.display)],
                    );
                    if (picked != null && mounted) setState(() => _account = list.firstWhere((a) => a.id == picked));
                  },
          );
    Future<DateTime?> pickDate(DateTime? current, DateTime first, DateTime last) => showDatePicker(
          context: context,
          initialDate: current ?? last,
          firstDate: first,
          lastDate: last,
        );
    final periodFields = _duration
        ? _pair(
            PayBoxedPicker(
              label: l10n.certFromDate,
              required: true,
              value: _from == null ? null : payDate(_from),
              placeholder: l10n.certFromDate,
              error: _showErrors && _from == null ? l10n.certDatesRequired : null,
              onTap: () async {
                final d = await pickDate(_from, earliest, _to ?? branchDate);
                if (d != null && mounted) setState(() => _from = d);
              },
            ),
            PayBoxedPicker(
              label: l10n.certToDate,
              required: true,
              value: _to == null ? null : payDate(_to),
              placeholder: l10n.certToDate,
              error: _showErrors && _to == null ? l10n.certDatesRequired : null,
              onTap: () async {
                final d = await pickDate(_to, _from ?? earliest, branchDate);
                if (d != null && mounted) setState(() => _to = d);
              },
            ),
          )
        : PayBoxedPicker(
            label: l10n.certFy,
            required: true,
            value: _year?.label,
            placeholder: l10n.addBillerSelect,
            error: _showErrors && _year == null ? l10n.addBillerFieldRequired(l10n.certFy) : null,
            onTap: () async {
              final picked = await showPayPicker<int>(
                context,
                title: l10n.certFy,
                selected: _year?.startYear,
                options: [for (final y in years) PayOption(value: y.startYear, title: y.label)],
              );
              if (picked != null && mounted) setState(() => _year = FinancialYear(picked));
            },
          );

    // Keep the account picked by default for Apply.
    if (_account == null && account != null) _account = account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pair(
                categoryField,
                _radioRow<bool>(
                  context,
                  l10n.certInterestFor,
                  [(false, l10n.certSpecificAccount), (true, l10n.certAllAccounts)],
                  _all,
                  (v) => setState(() => _all = v),
                ),
              ),
              const SizedBox(height: 16),
              _pair(
                _radioRow<bool>(
                  context,
                  l10n.certSelectPeriod,
                  [(false, l10n.certFinancialYearOption), (true, l10n.certDuration)],
                  _duration,
                  // OBDX clears the dates and the year on a change (hooks.js:126-138).
                  (v) => setState(() {
                    _duration = v;
                    _year = null;
                    _from = null;
                    _to = null;
                  }),
                ),
                _all ? null : accountField,
              ),
              const SizedBox(height: 16),
              periodFields,
              const SizedBox(height: 18),
              _actions(l10n, onApply: () => _apply(category, branchDate), onReset: _reset),
            ],
          ),
        ),
        if (_query != null) ...[const SizedBox(height: 18), _result(l10n, wide, _query!)],
      ],
    );
  }

  Widget _result(AppLocalizations l10n, bool wide, InterestQuery q) {
    final rows = ref.watch(interestCertificateProvider(q));
    return rows.when(
      loading: _loading,
      error: (e, _) => _failed(l10n, e, () => ref.invalidate(interestCertificateProvider(q))),
      data: (list) {
        final period = '${payDate(DateTime.tryParse(q.fromDate))} – ${payDate(DateTime.tryParse(q.toDate))}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultBand(
              parts: [_categoryLabel(l10n, q.category), q.account?.display ?? l10n.certAllAccounts, period],
              downloading: _downloading,
              // OBDX shows Download only with rows.
              onDownload: list.isEmpty
                  ? null
                  : () => _download(
                        context,
                        () => ref.read(certificatesRepositoryProvider).downloadInterest(q),
                        (b) => mounted ? setState(() => _downloading = b) : null,
                      ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              PayCard(child: PayMuted(l10n.certNoData))
            else
              _CertificateTable(
                wide: wide,
                columns: [
                  (l10n.certAccountNumber, 3, false),
                  (l10n.certProductType, 3, false),
                  (l10n.certDate, 2, false),
                  // Loans: "Interest Debited" (hooks.js:593-617).
                  (q.category == CertificateCategory.loans ? l10n.certInterestDebited : l10n.certInterestCredited, 2, true),
                ],
                rows: [
                  for (final r in list)
                    [r.account, r.productName ?? '', r.date == null ? '' : payDate(r.date), _money(r.amount)],
                ],
              ),
          ],
        );
      },
    );
  }
}

// ── Balance Certificates ─────────────────────────────────────────────────

/// OBDX `balance-certificate`: a month, then the Current and Savings and
/// Term Deposits balances.
class BalanceCertificatesScreen extends ConsumerStatefulWidget {
  const BalanceCertificatesScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<BalanceCertificatesScreen> createState() => _BalanceCertificatesScreenState();
}

class _BalanceCertificatesScreenState extends ConsumerState<BalanceCertificatesScreen> {
  DateTime? _month;
  DateTime? _applied;
  bool _downloading = false;

  String _label(DateTime m) => MaterialLocalizations.of(context).formatMonthYear(m);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PayMenuPage(
      title: l10n.certBalanceTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => ref.watch(certificateBranchDateProvider).when(
            loading: _loading,
            error: (e, _) => _failed(l10n, e, () => ref.invalidate(certificateBranchDateProvider)),
            data: (branchDate) {
              final months = balanceCertificateMonths(branchDate);
              // OBDX starts on the current month (hooks.js:258-260).
              final month = _month ?? months.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pair(
                          PayBoxedPicker(
                            label: l10n.certSelectMonth,
                            value: _label(month),
                            onTap: () async {
                              final picked = await showPayPicker<DateTime>(
                                context,
                                title: l10n.certSelectMonth,
                                selected: month,
                                options: [for (final m in months) PayOption(value: m, title: _label(m))],
                              );
                              if (picked != null && mounted) setState(() => _month = picked);
                            },
                          ),
                          null,
                        ),
                        const SizedBox(height: 18),
                        _actions(l10n, onApply: () => setState(() => _applied = month)),
                      ],
                    ),
                  ),
                  if (_applied != null) ...[const SizedBox(height: 18), _result(l10n, wide, _applied!)],
                ],
              );
            },
          ),
    );
  }

  Widget _result(AppLocalizations l10n, bool wide, DateTime month) {
    return ref.watch(balanceCertificateProvider(month)).when(
          loading: _loading,
          error: (e, _) => _failed(l10n, e, () => ref.invalidate(balanceCertificateProvider(month))),
          data: (cert) {
            // The design's Product Type, only when the response has one.
            bool withProduct(List<BalanceRow> rows) => rows.any((r) => r.productName != null);
            Widget section(String title, List<BalanceRow> rows, {required bool deposits}) {
              final product = withProduct(rows);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                    ),
                  ),
                  if (rows.isEmpty)
                    PayCard(child: PayMuted(l10n.certNoDataToDisplay))
                  else
                    _CertificateTable(
                      wide: wide,
                      columns: [
                        (l10n.certAccountNumber, 3, false),
                        if (product) (l10n.certProductType, 3, false),
                        if (deposits) (l10n.certDepositNo, 2, false),
                        (l10n.certBalance, 2, true),
                      ],
                      rows: [
                        for (final r in rows)
                          [
                            r.account,
                            if (product) r.productName ?? '',
                            if (deposits) r.depositNumber ?? '',
                            _money(r.balance),
                          ],
                      ],
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResultBand(
                  parts: [l10n.certBalanceTitle, _label(month)],
                  downloading: _downloading,
                  onDownload: cert.casa.isEmpty && cert.deposits.isEmpty
                      ? null
                      : () => _download(
                            context,
                            () => ref.read(certificatesRepositoryProvider).downloadBalance(month),
                            (b) => mounted ? setState(() => _downloading = b) : null,
                          ),
                ),
                const SizedBox(height: 14),
                section(l10n.certCasaAccounts, cert.casa, deposits: false),
                const SizedBox(height: 18),
                section(l10n.certTermDeposits, cert.deposits, deposits: true),
              ],
            );
          },
        );
  }
}

// ── TDS Certificates ─────────────────────────────────────────────────────

/// OBDX `tax-deduction-at-source`: a financial year, then the tax deducted
/// per deposit.
class TdsCertificatesScreen extends ConsumerStatefulWidget {
  const TdsCertificatesScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<TdsCertificatesScreen> createState() => _TdsCertificatesScreenState();
}

class _TdsCertificatesScreenState extends ConsumerState<TdsCertificatesScreen> {
  FinancialYear? _year;
  FinancialYear? _applied;
  bool _showErrors = false;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PayMenuPage(
      title: l10n.certTdsTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => ref.watch(certificateBranchDateProvider).when(
            loading: _loading,
            error: (e, _) => _failed(l10n, e, () => ref.invalidate(certificateBranchDateProvider)),
            data: (branchDate) {
              final years = FinancialYear.list(branchDate);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pair(
                          PayBoxedPicker(
                            label: l10n.certSelectFinancialYear,
                            required: true,
                            value: _year?.label,
                            placeholder: l10n.addBillerSelect,
                            error: _showErrors && _year == null
                                ? l10n.addBillerFieldRequired(l10n.certSelectFinancialYear)
                                : null,
                            onTap: () async {
                              final picked = await showPayPicker<int>(
                                context,
                                title: l10n.certSelectFinancialYear,
                                selected: _year?.startYear,
                                options: [for (final y in years) PayOption(value: y.startYear, title: y.label)],
                              );
                              if (picked != null && mounted) setState(() => _year = FinancialYear(picked));
                            },
                          ),
                          null,
                        ),
                        const SizedBox(height: 18),
                        _actions(
                          l10n,
                          onApply: () => setState(() {
                            _showErrors = _year == null;
                            if (_year != null) _applied = _year;
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (_applied != null) ...[const SizedBox(height: 18), _result(l10n, wide, _applied!, branchDate)],
                ],
              );
            },
          ),
    );
  }

  Widget _result(AppLocalizations l10n, bool wide, FinancialYear year, DateTime branchDate) {
    final key = (year, branchDate);
    return ref.watch(tdsCertificateProvider(key)).when(
          loading: _loading,
          error: (e, _) => _failed(l10n, e, () => ref.invalidate(tdsCertificateProvider(key))),
          data: (rows) {
            final totals = TdsRow.taxByCurrency(rows)
                .entries
                .map((e) => MoneyFormat.format(e.value, currencyCode: e.key))
                .join(' + ');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResultBand(
                  parts: [
                    if (rows.isEmpty) l10n.certTdsTitle else l10n.certTdsHeading(year.label, totals),
                    if (rows.isEmpty) year.label,
                  ],
                  downloading: _downloading,
                  // OBDX shows Download only with rows.
                  onDownload: rows.isEmpty
                      ? null
                      : () => _download(
                            context,
                            () => ref.read(certificatesRepositoryProvider).downloadTds(year, branchDate),
                            (b) => mounted ? setState(() => _downloading = b) : null,
                          ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  PayCard(child: PayMuted(l10n.certNoData))
                else
                  _CertificateTable(
                    wide: wide,
                    columns: [
                      (l10n.certDepositAccount, 3, false),
                      (l10n.certInterestEarned, 2, true),
                      (l10n.certTaxDeducted, 2, true),
                      (l10n.certTdsWaiver, 2, true),
                    ],
                    rows: [
                      for (final r in rows) [r.account, _money(r.interest), _money(r.tax), r.waiverLabel],
                    ],
                  ),
              ],
            );
          },
        );
  }
}
