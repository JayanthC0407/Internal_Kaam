import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Bill Payment History — OBDX `payment-history`: the user's bill payments
/// for a period (Current Period by default), newest first, with OBDX's
/// Filter (Select Period / Date From / Date To). Download and attachments
/// are not built yet. Evidence: docs/obdx/features/bill-payments.md §5.
class BillPaymentHistoryScreen extends ConsumerStatefulWidget {
  const BillPaymentHistoryScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<BillPaymentHistoryScreen> createState() => _BillPaymentHistoryScreenState();
}

class _BillPaymentHistoryScreenState extends ConsumerState<BillPaymentHistoryScreen> {
  BillHistoryQuery _query = const BillHistoryQuery();

  Future<void> _openFilter(bool wide) async {
    final panel = _FilterPanel(initial: _query);
    // Web: a dialog; phone: a bottom sheet.
    final Future<BillHistoryQuery?> picked;
    if (wide) {
      picked = showDialog<BillHistoryQuery>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: panel),
        ),
      );
    } else {
      picked = showModalBottomSheet<BillHistoryQuery>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => panel,
      );
    }
    final next = await picked;
    if (next != null && mounted) setState(() => _query = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payments = ref.watch(billPaymentHistoryProvider(_query));
    final loc = MaterialLocalizations.of(context);

    return PayMenuPage(
      title: l10n.billHistoryTitle,
      subtitle: l10n.billHistorySubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _periodSummary(l10n, loc, _query),
                  style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                ),
              ),
              PaySecondaryButton(
                label: l10n.billHistoryFilter,
                icon: Icons.tune_rounded,
                onPressed: () => _openFilter(wide),
              ),
            ],
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
                : PaySection(
                    child: Column(
                      children: [
                        if (wide) const _HeaderRow(),
                        for (final (i, p) in list.indexed)
                          _PaymentRow(payment: p, wide: wide, last: i == list.length - 1),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _periodLabel(AppLocalizations l10n, BillHistoryPeriod period) => switch (period) {
      BillHistoryPeriod.currentPeriod => l10n.billHistoryCurrentPeriod,
      BillHistoryPeriod.previousMonth => l10n.billHistoryPreviousMonth,
      BillHistoryPeriod.previousQuarter => l10n.billHistoryPreviousQuarter,
      BillHistoryPeriod.dateRange => l10n.billHistoryDateRange,
    };

String _periodSummary(AppLocalizations l10n, MaterialLocalizations loc, BillHistoryQuery q) {
  final label = _periodLabel(l10n, q.period);
  if (q.period != BillHistoryPeriod.dateRange || q.from == null || q.to == null) return label;
  return '$label: ${loc.formatMediumDate(q.from!)} – ${loc.formatMediumDate(q.to!)}';
}

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
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context));
    Widget cell(String t, int flex, {TextAlign align = TextAlign.start}) =>
        Expanded(flex: flex, child: Text(t, style: style, textAlign: align));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        cell(l10n.billHistoryDate, 2),
        cell(l10n.billHistoryBiller, 3),
        cell(l10n.addBillerCategory, 3),
        cell(l10n.billerBillAmount, 2, align: TextAlign.end),
        const SizedBox(width: 16),
        cell(l10n.billHistoryReferenceNo, 3),
        cell(l10n.billHistoryStatus, 2),
      ]),
    );
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
              Expanded(flex: 2, child: Text(amount, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: primary))),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: Text(p.referenceNo, style: TextStyle(color: secondary))),
              Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: status)),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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

/// OBDX's Filter panel (bill-payment-history-panel): Select Period, and
/// Date From / Date To for Date Range. To ≤ today, From ≤ To.
class _FilterPanel extends StatefulWidget {
  const _FilterPanel({required this.initial});

  final BillHistoryQuery initial;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late BillHistoryPeriod _period = widget.initial.period;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  bool _showError = false;

  void _apply() {
    final query = BillHistoryQuery(
      period: _period,
      from: _period == BillHistoryPeriod.dateRange ? _from : null,
      to: _period == BillHistoryPeriod.dateRange ? _to : null,
    );
    if (!query.isComplete) return setState(() => _showError = true);
    Navigator.of(context).pop(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final earliest = DateTime(today.year - 10);
    final range = _period == BillHistoryPeriod.dateRange;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.billHistoryFilter, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            PayFieldLabel(l10n.billHistorySelectPeriod, required: true),
            PayChoiceChips<BillHistoryPeriod>(
              options: [for (final p in BillHistoryPeriod.values) (p, _periodLabel(l10n, p))],
              selected: _period,
              onChanged: (p) => setState(() {
                _period = p;
                _showError = false;
              }),
            ),
            if (range) ...[
              const SizedBox(height: 16),
              PayFieldLabel(l10n.billHistoryDateFrom, required: true),
              PayDateField(
                value: _from,
                first: earliest,
                last: _to ?? today,
                onChanged: (d) => setState(() => _from = d),
                error: _showError && _from == null ? l10n.billHistoryDatesRequired : null,
              ),
              const SizedBox(height: 12),
              PayFieldLabel(l10n.billHistoryDateTo, required: true),
              PayDateField(
                value: _to,
                first: _from ?? earliest,
                last: today,
                onChanged: (d) => setState(() => _to = d),
                error: _showError && _to == null ? l10n.billHistoryDatesRequired : null,
              ),
            ],
            const SizedBox(height: 20),
            PayPrimaryButton(label: l10n.billHistoryApply, onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
