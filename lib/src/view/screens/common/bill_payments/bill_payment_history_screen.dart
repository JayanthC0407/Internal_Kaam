import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';

/// Bill Payment History — OBDX `payment-history`: the user's bill payments
/// for a period (Current Period by default), newest first, with OBDX's
/// Select Period / Date From / Date To and Download (CSV / PDF, PDF with
/// OBDX's password note). Laid out as the designer's page (UI designs
/// 2026-10-27): the period inline above a table; a choice reloads at once
/// (no Apply, user decision). Attachments are not built yet ("—").
/// Evidence: docs/obdx/features/bill-payments.md §5.
class BillPaymentHistoryScreen extends ConsumerStatefulWidget {
  const BillPaymentHistoryScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<BillPaymentHistoryScreen> createState() => _BillPaymentHistoryScreenState();
}

/// Used when the mediatype lookup fails, so Download still works: OBDX
/// offers only these two for bill payments (hooks.js:409-416).
const _fallbackHistoryFormats = [
  StatementFormat(code: 'csv', mimeType: 'text/csv', ordinal: 1),
  StatementFormat(code: 'pdf', mimeType: 'application/pdf', ordinal: 2),
];

class _BillPaymentHistoryScreenState extends ConsumerState<BillPaymentHistoryScreen> {
  BillHistoryQuery _query = const BillHistoryQuery();
  bool _downloading = false;

  /// The period picked; Date Range waits for both dates before it loads.
  BillHistoryPeriod _period = BillHistoryPeriod.currentPeriod;
  DateTime? _from;
  DateTime? _to;

  /// OBDX's Download (payment-history/hooks.js:422-454): pick CSV or PDF,
  /// see the password note for a PDF, then fetch the current filter as a
  /// file and save it (shared decoder: statement_download.dart).
  Future<void> _download() async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);

    final formatsResult = await repository.fetchHistoryFormats();
    if (!mounted) return;
    final formats = formatsResult is Success<List<StatementFormat>> && (formatsResult.data?.isNotEmpty ?? false)
        ? formatsResult.data!
        : _fallbackHistoryFormats;

    final format = await AppBottomSheet.pick<StatementFormat>(
      context: context,
      title: l10n.casaStatementFormatTitle,
      options: [for (final f in formats) (value: f, label: f.label)],
      selected: formats.first,
    );
    if (format == null || !mounted) return;

    if (format.fileExtension == 'pdf') {
      final proceed = await AppBottomSheet.confirm(
        context,
        title: l10n.billHistoryPasswordTitle,
        message: '${l10n.billHistoryPasswordBody}\n\n${l10n.billHistoryPasswordExample}',
        confirmLabel: l10n.billHistoryDownload,
      );
      if (!proceed || !mounted) return;
    }

    setState(() => _downloading = true);
    final result = await repository.downloadHistory(_query, format);
    if (!mounted) return;
    setState(() => _downloading = false);

    if (result is Success<StatementFile> && result.data != null) {
      try {
        await StatementFileSaver.saveStatement(
          bytes: result.data!.bytes,
          fileName: result.data!.fileName,
          mimeType: result.data!.mimeType,
        );
        _snack(l10n.casaStatementDownloadSuccess);
      } catch (_) {
        _snack(l10n.casaStatementDownloadFailed);
      }
    } else if (!SessionExpiryCoordinator.instance.isHandling) {
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.casaStatementDownloadFailed));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPeriod() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<BillHistoryPeriod>(
      context,
      title: l10n.billHistorySelectPeriod,
      selected: _period,
      options: [for (final p in BillHistoryPeriod.values) PayOption(value: p, title: _periodLabel(l10n, p))],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = picked;
      if (picked != BillHistoryPeriod.dateRange) {
        _from = null;
        _to = null;
        _query = BillHistoryQuery(period: picked);
      }
    });
  }

  /// A Date Range loads once both dates are set (From ≤ To ≤ today).
  void _setRange({DateTime? from, DateTime? to}) {
    setState(() {
      _from = from ?? _from;
      _to = to ?? _to;
      final query = BillHistoryQuery(period: BillHistoryPeriod.dateRange, from: _from, to: _to);
      if (query.isComplete) _query = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payments = ref.watch(billPaymentHistoryProvider(_query));
    final today = DateUtils.dateOnly(DateTime.now());
    final earliest = DateTime(today.year - 10);
    final range = _period == BillHistoryPeriod.dateRange;

    return PayMenuPage(
      title: l10n.billHistoryTitle,
      subtitle: l10n.billHistorySubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final periodField = PayBoxedPicker(
          label: l10n.billHistorySelectPeriod,
          value: _periodLabel(l10n, _period),
          onTap: _pickPeriod,
        );
        // From ≤ To ≤ today, as OBDX's filter panel.
        Widget dateBox(String label, DateTime? value, DateTime first, DateTime last, ValueChanged<DateTime> onPicked) =>
            PayBoxedPicker(
              label: label,
              required: true,
              value: value == null ? null : payDate(value),
              placeholder: l10n.billHistoryDatesRequired,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? last,
                  firstDate: first,
                  lastDate: last,
                );
                if (picked != null) onPicked(picked);
              },
            );
        final dates = [
          dateBox(l10n.billHistoryDateFrom, _from, earliest, _to ?? today, (d) => _setRange(from: d)),
          dateBox(l10n.billHistoryDateTo, _to, _from ?? earliest, today, (d) => _setRange(to: d)),
        ];
        // OBDX shows Download only when there are payments.
        final download = (payments.valueOrNull ?? const []).isEmpty
            ? null
            : _downloading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton.outlined(
                    tooltip: l10n.billHistoryDownload,
                    onPressed: _download,
                    icon: Icon(Icons.download_rounded, color: HomeColors.brand(context)),
                  );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayCard(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: periodField),
                        if (range) ...[
                          const SizedBox(width: 16),
                          SizedBox(width: 240, child: dates[0]),
                          const SizedBox(width: 16),
                          SizedBox(width: 240, child: dates[1]),
                        ],
                        const Spacer(),
                        if (download != null) download,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [Expanded(child: periodField), if (download != null) ...[const SizedBox(width: 8), download]]),
                        if (range) ...[const SizedBox(height: 12), dates[0], const SizedBox(height: 12), dates[1]],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            payments.when(
              loading: () => const PayCard(
                child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              ),
              error: (error, _) => PayErrorRetry(
                message: error is BillPaymentsLoadError && error.message != null
                    ? error.message!
                    : l10n.billHistoryLoadFailed,
                onRetry: () => ref.invalidate(billPaymentHistoryProvider(_query)),
              ),
              data: (list) => list.isEmpty
                  ? PayCard(child: PayMuted(l10n.billHistoryNoData))
                  : PayCard(
                      padding: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide) const _HeaderRow(),
                          for (final (i, p) in list.indexed)
                            _PaymentRow(payment: p, wide: wide, last: i == list.length - 1),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            PayInfoBanner(message: l10n.billHistoryPeriodNote),
          ],
        );
      },
    );
  }
}

String _periodLabel(AppLocalizations l10n, BillHistoryPeriod period) => switch (period) {
      BillHistoryPeriod.currentPeriod => l10n.billHistoryCurrentPeriod,
      BillHistoryPeriod.previousMonth => l10n.billHistoryPreviousMonth,
      BillHistoryPeriod.previousQuarter => l10n.billHistoryPreviousQuarter,
      BillHistoryPeriod.dateRange => l10n.billHistoryDateRange,
    };

String statusLabel(AppLocalizations l10n, BillPayment p) => switch (p.status) {
      BillPaymentStatus.sent => l10n.billHistoryStatusSent,
      BillPaymentStatus.completed => l10n.billHistoryStatusCompleted,
      BillPaymentStatus.pending => l10n.billHistoryStatusPending,
      BillPaymentStatus.timeout => l10n.billHistoryStatusTimeout,
      BillPaymentStatus.error => l10n.billHistoryStatusError,
      BillPaymentStatus.unknown => p.rawStatus ?? '',
    };

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PayTableHeader(cells: [
      (l10n.billHistoryDate, 2),
      (l10n.billHistoryBiller, 3),
      (l10n.addBillerCategory, 3),
      (l10n.billerBillAmount, 2),
      (l10n.billHistoryReferenceNo, 2),
      (l10n.billHistoryStatus, 2),
      (l10n.billHistoryAttachment, 2),
    ]);
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.wide, required this.last});

  final BillPayment payment;
  final bool wide;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final p = payment;
    final date = p.paymentDate == null ? '' : loc.formatMediumDate(p.paymentDate!);
    final amount = p.amount == null ? '' : MoneyFormat.format(p.amount!.amount, currencyCode: p.amount!.currency ?? '');
    final primary = HomeColors.textPrimary(context);
    final secondary = HomeColors.textSecondary(context);
    final status = _StatusChip(payment: p);

    final Widget content = wide
        ? Row(
            children: [
              Expanded(flex: 2, child: Text(date, style: TextStyle(color: primary))),
              Expanded(flex: 3, child: Text(p.billerName ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: primary))),
              Expanded(flex: 3, child: Text(p.category ?? '', style: TextStyle(color: secondary))),
              Expanded(flex: 2, child: Text(amount, style: TextStyle(color: primary))),
              Expanded(flex: 2, child: Text(p.referenceNo, style: TextStyle(color: secondary))),
              Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: status)),
              // Attachments are not built yet.
              Expanded(flex: 2, child: Text('—', style: TextStyle(color: secondary))),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(p.billerName ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: primary)),
                  ),
                  const SizedBox(width: 12),
                  Text(amount, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: primary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [p.category ?? '', date].where((v) => v.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 13, color: secondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.billHistoryReferenceNo}: ${p.referenceNo}',
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ),
                  status,
                ],
              ),
            ],
          );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: wide ? 20 : 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: content,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.payment});

  final BillPayment payment;

  @override
  Widget build(BuildContext context) {
    final label = statusLabel(AppLocalizations.of(context), payment);
    if (label.isEmpty) return const SizedBox.shrink();
    final color = switch (payment.status) {
      BillPaymentStatus.completed => HomeColors.success(context),
      BillPaymentStatus.error || BillPaymentStatus.timeout => HomeColors.error(context),
      BillPaymentStatus.pending || BillPaymentStatus.sent => HomeColors.warning(context),
      BillPaymentStatus.unknown => HomeColors.textSecondary(context),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
